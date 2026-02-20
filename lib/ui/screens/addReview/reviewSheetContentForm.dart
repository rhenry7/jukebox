import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/Api/api_key.dart';
import 'package:flutter_test_project/providers/reviews_provider.dart';
import 'package:flutter_test_project/services/recommendation_outcome_service.dart';
import 'package:flutter_test_project/services/signal_collection_service.dart';
import 'package:flutter_test_project/ui/screens/Profile/ProfileSignUpWidget.dart';
import 'package:flutter_test_project/utils/reviews/review_helpers.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:flutter_test_project/utils/cached_image.dart';
import 'package:flutter_test_project/utils/spotify_retry.dart';
import 'package:ionicons/ionicons.dart';
import 'package:spotify/spotify.dart' as spotify;

import 'review_text_editor.dart';

class MyReviewSheetContentForm extends ConsumerStatefulWidget {
  final String title;
  final String artist; // Fixed capitalization
  final String albumImageUrl;

  const MyReviewSheetContentForm({
    super.key,
    required this.title,
    required this.artist, // Fixed capitalization
    required this.albumImageUrl,
  });

  @override
  ConsumerState<MyReviewSheetContentForm> createState() =>
      _MyReviewSheetContentFormState();
}

class _MyReviewSheetContentFormState
    extends ConsumerState<MyReviewSheetContentForm> {
  final FirebaseAuth auth = FirebaseAuth.instance;
  late String currentDate;
  bool liked = false;
  double ratingScore = 0;
  final Color background = Colors.white10;
  final TextEditingController reviewController = TextEditingController();
  final TextEditingController searchParams = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();

  // Search state
  List<spotify.Track> _trackResults = [];
  List<dynamic> _albumResults =
      []; // Use dynamic to handle both Album and AlbumSimple
  bool _isSearching = false;
  String _selectedTrackTitle = '';
  String _selectedTrackArtist = '';
  String _selectedTrackImageUrl = '';
  Timer? _searchDebounce;
  String _searchFilter = 'all'; // 'all', 'song', 'album'
  String? _searchError; // User-facing error message for search failures
  bool _showRequiredError = false; // Glow when submit fails validation

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    currentDate = DateFormat.yMMMMd('en_US').format(now);

    // Initialize with widget values if provided
    _selectedTrackTitle = widget.title;
    _selectedTrackArtist = widget.artist;
    _selectedTrackImageUrl = widget.albumImageUrl;

    // Listen to search input changes
    searchParams.addListener(_onSearchChanged);
    // Clear required-error glow when user types in required fields
    void clearRequiredError() {
      if (_showRequiredError && mounted) {
        setState(() => _showRequiredError = false);
      }
    }
    reviewController.addListener(clearRequiredError);
    _tagsController.addListener(clearRequiredError);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    reviewController.dispose();
    searchParams.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  List<String> get _tagsFromController => _tagsController.text
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  void _onSearchChanged() {
    // Cancel previous debounce timer
    _searchDebounce?.cancel();

    final query = searchParams.text.trim();
    debugPrint(
        '⌨️  [INPUT] Search input changed: "$query" (length: ${query.length})');

    if (query.length >= 2) {
      debugPrint(
          '   ✅ Query length sufficient, starting debounce timer (500ms)');
      // Debounce search by 500ms
      _searchDebounce = Timer(const Duration(milliseconds: 500), () {
        debugPrint('   ⏰ Debounce timer completed, executing search');
        // Log search query signal (only final debounced queries)
        SignalCollectionService.logSearchQuery(
          query: query,
          sourceContext: 'search',
        );
        _performSearch(query);
      });
    } else {
      debugPrint('   ⚠️  Query too short, clearing results');
      setState(() {
        _trackResults = [];
        _albumResults = [];
        _isSearching = false;
      });
    }
  }

  Future<void> _performSearch(String query) async {
    if (_isSearching) return;

    debugPrint('🔍 [SEARCH] Starting search...');
    debugPrint('   Query: "$query"');
    debugPrint('   Filter: $_searchFilter');

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      final credentials = spotify.SpotifyApiCredentials(clientId, clientSecret);
      final spotifyApi = spotify.SpotifyApi(credentials);

      // Determine search types based on filter
      List<spotify.SearchType> searchTypes = [];
      if (_searchFilter == 'all') {
        searchTypes = [spotify.SearchType.track, spotify.SearchType.album];
        debugPrint('   Search types: [track, album]');
      } else if (_searchFilter == 'song') {
        searchTypes = [spotify.SearchType.track];
        debugPrint('   Search types: [track]');
      } else if (_searchFilter == 'album') {
        searchTypes = [spotify.SearchType.album];
        debugPrint('   Search types: [album]');
      }

      // Search based on selected filter
      // Increase limit to get more results, especially for albums
      final limit = _searchFilter == 'album' ? 20 : 10;
      debugPrint('   Limit: $limit');
      debugPrint('   Making API request to Spotify...');

      final searchResults = await withSpotifyRetry(
        () => spotifyApi.search.get(query, types: searchTypes).first(limit),
      );

      debugPrint('   ✅ API request successful');
      debugPrint('   Processing results...');

      final List<spotify.Track> tracks = [];
      final List<dynamic> albums =
          []; // Use dynamic to handle both Album and AlbumSimple
      int totalItemsProcessed = 0;

      for (final page in searchResults) {
        if (page.items != null) {
          debugPrint('   📄 Processing page with ${page.items!.length} items');
          for (final item in page.items!) {
            totalItemsProcessed++;
            if (item is spotify.Track) {
              tracks.add(item);
              debugPrint(
                  '   🎵 Track found: "${item.name}" by ${item.artists?.map((a) => a.name).join(', ') ?? 'Unknown'}');
            } else if (item is spotify.Album) {
              albums.add(item);
              debugPrint(
                  '   💿 Album found: "${item.name}" by ${item.artists?.map((a) => a.name).join(', ') ?? 'Unknown'}');
            } else if (item is spotify.AlbumSimple) {
              // Handle AlbumSimple - it has the same properties we need
              albums.add(item);
              final artistNames = item.artists != null
                  ? item.artists!.map((a) => a.name ?? 'Unknown').join(', ')
                  : 'Unknown';
              debugPrint(
                  '   💿 AlbumSimple found: "${item.name}" by $artistNames');
            } else {
              debugPrint('   ⚠️  Unknown item type: ${item.runtimeType}');
            }
          }
        } else {
          debugPrint('   ⚠️  Page has no items');
        }
      }

      debugPrint('   📊 Search Summary:');
      debugPrint('      Total items processed: $totalItemsProcessed');
      debugPrint('      Tracks found: ${tracks.length}');
      debugPrint('      Albums found: ${albums.length}');

      if (tracks.isNotEmpty) {
        debugPrint('   🎵 Tracks:');
        for (final track in tracks.take(5)) {
          debugPrint(
              '      - "${track.name}" by ${track.artists?.map((a) => a.name).join(', ') ?? 'Unknown'}');
        }
        if (tracks.length > 5) {
          debugPrint('      ... and ${tracks.length - 5} more tracks');
        }
      }

      if (albums.isNotEmpty) {
        debugPrint('   💿 Albums:');
        for (final album in albums.take(5)) {
          debugPrint(
              '      - "${album.name}" by ${album.artists?.map((a) => a.name).join(', ') ?? 'Unknown'}');
        }
        if (albums.length > 5) {
          debugPrint('      ... and ${albums.length - 5} more albums');
        }
      }

      if (mounted) {
        setState(() {
          _trackResults = tracks;
          _albumResults = albums;
          _isSearching = false;
        });
        debugPrint('   ✅ State updated successfully');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [SEARCH ERROR]');
      debugPrint('   Query: "$query"');
      debugPrint('   Filter: $_searchFilter');
      debugPrint('   Error: $e');
      debugPrint('   Stack trace: $stackTrace');
      if (mounted) {
        final errorStr = e.toString().toLowerCase();
        String userMessage;
        if (e is TimeoutException || errorStr.contains('timeout')) {
          userMessage = 'Search timed out. Please try again.';
        } else if (errorStr.contains('socket') ||
            errorStr.contains('network') ||
            errorStr.contains('connection')) {
          userMessage =
              'No internet connection. Check your network and try again.';
        } else if (errorStr.contains('401') ||
            errorStr.contains('403') ||
            errorStr.contains('api key')) {
          userMessage = 'Search service unavailable. Please try again later.';
        } else {
          userMessage = 'Search failed. Please try again.';
        }
        setState(() {
          _trackResults = [];
          _albumResults = [];
          _isSearching = false;
          _searchError = userMessage;
        });
        debugPrint('   ✅ Error state handled, search cleared');
      }
    }
  }

  void _selectTrack(spotify.Track track) {
    debugPrint('🎵 [SELECT] Track selected:');
    debugPrint('   Title: "${track.name}"');
    debugPrint(
        '   Artist: ${track.artists?.map((a) => a.name).join(', ') ?? 'Unknown'}');
    debugPrint('   Album: ${track.album?.name ?? 'Unknown'}');
    debugPrint(
        '   Image URL: ${track.album?.images?.isNotEmpty == true ? track.album!.images!.first.url ?? 'None' : 'None'}');

    setState(() {
      _selectedTrackTitle = track.name ?? '';
      _selectedTrackArtist = track.artists?.map((a) => a.name).join(', ') ?? '';
      _selectedTrackImageUrl = track.album?.images?.isNotEmpty == true
          ? track.album!.images!.first.url ?? ''
          : '';
      _trackResults = [];
      _albumResults = [];
      searchParams.clear();
    });
    debugPrint('   ✅ Track selection complete');
  }

  /// Accepts both [spotify.Album] and [spotify.AlbumSimple] from search results.
  void _selectAlbum(dynamic album) {
    String name = '';
    String artistStr = '';
    String imageUrl = '';

    if (album is spotify.Album) {
      name = album.name ?? '';
      artistStr = album.artists?.map((a) => a.name).join(', ') ?? '';
      imageUrl =
          album.images?.isNotEmpty == true ? album.images!.first.url ?? '' : '';
      debugPrint('💿 [SELECT] Album selected: ${album.name}');
    } else if (album is spotify.AlbumSimple) {
      name = album.name ?? '';
      artistStr =
          album.artists?.map((a) => a.name ?? 'Unknown').join(', ') ?? '';
      imageUrl =
          album.images?.isNotEmpty == true ? album.images!.first.url ?? '' : '';
      debugPrint('💿 [SELECT] AlbumSimple selected: ${album.name}');
    } else {
      debugPrint('   ⚠️ Unknown album type: ${album.runtimeType}');
      return;
    }

    debugPrint('   Title: "$name"');
    debugPrint('   Artist: $artistStr');
    debugPrint('   Image URL: ${imageUrl.isEmpty ? "None" : imageUrl}');

    setState(() {
      _selectedTrackTitle = name;
      _selectedTrackArtist = artistStr;
      _selectedTrackImageUrl = imageUrl;
      _trackResults = [];
      _albumResults = [];
      searchParams.clear();
    });
    debugPrint('   ✅ Album selection complete');
  }

  Widget _buildFilterPill(String filter, String label, IconData icon) {
    final isSelected = _searchFilter == filter;
    return GestureDetector(
      onTap: () {
        debugPrint(
            '🏷️  [FILTER] Changed filter from "$_searchFilter" to "$filter"');
        setState(() {
          _searchFilter = filter;
          // Trigger new search if there's a query
          if (searchParams.text.trim().length >= 2) {
            debugPrint('   Triggering new search with filter "$filter"');
            _performSearch(searchParams.text.trim());
          } else {
            debugPrint(
                '   No active query, filter changed but no search triggered');
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.red[600] : Colors.white10,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.red[400]! : Colors.white24,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.white70,
            ),
            const Gap(6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> showSubmissionAuthErrorModal(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'User not logged in',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'You must be logged in to leave a review',
            style: TextStyle(color: Colors.white70),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog first
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (BuildContext context) => const ProfileSignUp(),
                  ),
                );
              },
              child: const Text(
                'Log in',
                style: TextStyle(color: Colors.greenAccent),
              ),
            ),
          ],
        );
      },
    );
  }

  void toggleHeart() {
    setState(() {
      liked = !liked;
    });
  }

  Future<void> handleSubmit() async {
    if (auth.currentUser == null) {
      showSubmissionAuthErrorModal(context);
      return;
    }

    final String review = reviewController.text.trim();
    final tags = _tagsFromController;

    // Required: write your review and at least one tag
    if (review.isEmpty || tags.isEmpty) {
      setState(() => _showRequiredError = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            review.isEmpty && tags.isEmpty
                ? 'Please write your review and add at least one tag'
                : review.isEmpty
                    ? 'Please write your review before submitting'
                    : 'Please add at least one tag (e.g. rock, indie)',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await submitReview(
        review,
        ratingScore,
        _selectedTrackArtist.isNotEmpty ? _selectedTrackArtist : widget.artist,
        _selectedTrackTitle.isNotEmpty ? _selectedTrackTitle : widget.title,
        liked,
        _selectedTrackImageUrl.isNotEmpty
            ? _selectedTrackImageUrl
            : widget.albumImageUrl,
        tags, // stored as genres (required, validated above)
      );

      // Log review_submit signal (strongest explicit signal)
      final submittedArtist = _selectedTrackArtist.isNotEmpty
          ? _selectedTrackArtist
          : widget.artist;
      final submittedTrack = _selectedTrackTitle.isNotEmpty
          ? _selectedTrackTitle
          : widget.title;
      SignalCollectionService.logReviewSubmit(
        artist: submittedArtist,
        track: submittedTrack,
        rating: ratingScore,
        genres: tags,
      );

      // Check if this review matches a pending recommendation (Phase 4)
      RecommendationOutcomeService.checkAndRecordOutcome(
        artist: submittedArtist,
        track: submittedTrack,
        rating: ratingScore,
      );

      // Invalidate reviews provider to refresh all screens automatically
      ref.invalidate(userReviewsProvider);
      if (liked) {
        updateSavedTracks(
          _selectedTrackArtist.isNotEmpty
              ? _selectedTrackArtist
              : widget.artist,
          _selectedTrackTitle.isNotEmpty ? _selectedTrackTitle : widget.title,
        );
      } else if (!liked) {
        updateRemovePreferences(
          _selectedTrackArtist.isNotEmpty
              ? _selectedTrackArtist
              : widget.artist,
          _selectedTrackTitle.isNotEmpty ? _selectedTrackTitle : widget.title,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review Posted!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not submit review: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ─── Extracted sub-widgets ───────────────────────────────────

  /// Header row with back button and user display name.
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        Row(
          children: [
            Text(
              auth.currentUser?.displayName ?? 'NotSignedIn',
              style: const TextStyle(color: Colors.white),
            ),
            const Gap(8),
            const Icon(
              Ionicons.person_circle_outline,
              color: Colors.white,
            ),
          ],
        ),
      ],
    );
  }

  /// The search error banner shown when a search fails.
  Widget _buildSearchErrorBanner() {
    if (_searchError == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.red.withAlpha(30),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.withAlpha(80)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _searchError!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _searchError = null),
              child: const Icon(Icons.close, color: Colors.redAccent, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  /// Album / track info header shown when a track is selected for review.
  Widget _buildSelectedTrackInfo() {
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[800],
          ),
          child: _selectedTrackImageUrl.isNotEmpty
              ? AppCachedImage(
                  imageUrl: _selectedTrackImageUrl,
                  borderRadius: BorderRadius.circular(8),
                )
              : const Icon(Icons.music_note, color: Colors.white),
        ),
        const Gap(16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedTrackTitle.isNotEmpty
                    ? _selectedTrackTitle
                    : widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Gap(4),
              Text(
                _selectedTrackArtist.isNotEmpty
                    ? _selectedTrackArtist
                    : widget.artist,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Opens the full-screen review text editor and returns the text on "Done".
  Future<void> _openReviewEditor() async {
    final imageUrl = _selectedTrackImageUrl.isNotEmpty
        ? _selectedTrackImageUrl
        : widget.albumImageUrl;
    final isEditing = reviewController.text.trim().isNotEmpty;

    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ReviewTextEditor(
          initialText: reviewController.text,
          albumImageUrl: imageUrl,
          headerTitle: isEditing ? 'Edit Review' : 'Add Review',
        ),
      ),
    );

    // If the user pressed "Done", update the controller with the returned text.
    if (result != null && mounted) {
      setState(() {
        reviewController.text = result;
      });
    }
  }

  /// Tappable review preview — opens the full-screen editor on tap.
  Widget _buildReviewTextField() {
    final hasText = reviewController.text.trim().isNotEmpty;
    final showError = _showRequiredError && !hasText;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: GestureDetector(
        onTap: _openReviewEditor,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 120, maxWidth: 500),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: showError ? Colors.orange : Colors.grey[700]!,
              width: showError ? 2 : 1,
            ),
            boxShadow: showError
                ? [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showError)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'Required',
                    style: TextStyle(
                      color: Colors.orange[400],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: hasText
                        ? Text(
                            reviewController.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              height: 1.4,
                            ),
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                          )
                        : const Text(
                            'What did you think?\nTap to write your review…',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    hasText ? Icons.edit_outlined : Icons.rate_review_outlined,
                    color: Colors.white38,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tags input field (comma-separated).
  Widget _buildTagsField() {
    final tagsEmpty = _tagsFromController.isEmpty;
    final showError = _showRequiredError && tagsEmpty;
    final errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.orange, width: 2),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showError)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Required',
              style: TextStyle(
                color: Colors.orange[400],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: showError
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                )
              : null,
          child: TextFormField(
            controller: _tagsController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Tags',
              labelStyle: const TextStyle(color: Colors.white70),
              hintText: 'rock, indie, workout (comma-separated)',
              hintStyle: const TextStyle(color: Colors.white30),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white30),
              ),
              enabledBorder: showError
                  ? errorBorder
                  : OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white30),
                    ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: showError ? Colors.orange : Colors.red,
                  width: 2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Submit button.
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Save Review',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: background),
      height: MediaQuery.of(context).size.height * 1.0,
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _selectedTrackImageUrl.isEmpty
              ? Expanded(
                  child: Column(
                    children: [
                      SearchBar(
                        controller: searchParams,
                        leading: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(Icons.search_rounded),
                        ),
                        hintText: 'Search for a song, artist, or album...',
                        backgroundColor:
                            WidgetStateProperty.all(Colors.white10),
                        padding: WidgetStateProperty.all(
                            const EdgeInsets.symmetric(horizontal: 16.0)),
                        trailing: _isSearching
                            ? [
                                const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.0,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  ),
                                )
                              ]
                            : searchParams.text.isNotEmpty
                                ? [
                                    IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        searchParams.clear();
                                        setState(() {
                                          _trackResults = [];
                                          _albumResults = [];
                                          _searchError = null;
                                        });
                                      },
                                    )
                                  ]
                                : null,
                      ),
                      const Gap(12),
                      // Filter pills: All, Song, Album
                      Row(
                        children: [
                          _buildFilterPill('all', 'All', Icons.music_note),
                          const Gap(8),
                          _buildFilterPill('song', 'Song', Icons.audiotrack),
                          const Gap(8),
                          _buildFilterPill('album', 'Album', Icons.album),
                        ],
                      ),
                      const Gap(16),
                      _buildSearchErrorBanner(),
                      // Search results
                      if (_trackResults.isNotEmpty || _albumResults.isNotEmpty)
                        Expanded(
                          child: ListView.builder(
                            itemCount:
                                _trackResults.length + _albumResults.length,
                            itemBuilder: (context, index) {
                              // Show tracks first, then albums
                              if (index < _trackResults.length) {
                                final track = _trackResults[index];
                                final albumImages = track.album?.images;
                                final imageUrl = albumImages?.isNotEmpty == true
                                    ? albumImages!.first.url
                                    : null;
                                final artistNames = track.artists
                                        ?.map((a) => a.name)
                                        .join(', ') ??
                                    'Unknown Artist';

                                return Card(
                                  key: ValueKey('track_${track.id ?? index}'),
                                  color: Colors.grey[900],
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 4, horizontal: 0),
                                  child: ListTile(
                                    leading: imageUrl != null
                                        ? AppCachedImage(
                                            imageUrl: imageUrl,
                                            width: 56,
                                            height: 56,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          )
                                        : Container(
                                            width: 56,
                                            height: 56,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[800],
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: const Icon(
                                              Icons.music_note,
                                              color: Colors.white70,
                                            ),
                                          ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            track.name ?? 'Unknown Track',
                                            style: const TextStyle(
                                                color: Colors.white),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.only(left: 8.0),
                                          child: Icon(
                                            Icons.audiotrack,
                                            size: 16,
                                            color: Colors.white54,
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      artistNames,
                                      style: const TextStyle(
                                          color: Colors.white70),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: () => _selectTrack(track),
                                  ),
                                );
                              } else {
                                // Show albums (can be Album or AlbumSimple)
                                final albumIndex = index - _trackResults.length;
                                final album = _albumResults[albumIndex];

                                // Handle both Album and AlbumSimple
                                String? imageUrl;
                                String artistNames = 'Unknown Artist';
                                String albumName = 'Unknown Album';
                                String releaseYear = '';

                                if (album is spotify.Album) {
                                  albumName = album.name ?? 'Unknown Album';
                                  imageUrl = album.images?.isNotEmpty == true
                                      ? album.images!.first.url
                                      : null;
                                  artistNames = album.artists
                                          ?.map((a) => a.name)
                                          .join(', ') ??
                                      'Unknown Artist';
                                  // Extract year from releaseDate
                                  if (album.releaseDate != null) {
                                    final dateStr =
                                        album.releaseDate.toString();
                                    if (dateStr.length >= 4) {
                                      releaseYear = dateStr.substring(0, 4);
                                    }
                                  }
                                } else if (album is spotify.AlbumSimple) {
                                  albumName = album.name ?? 'Unknown Album';
                                  imageUrl = album.images?.isNotEmpty == true
                                      ? album.images!.first.url
                                      : null;
                                  artistNames = album.artists
                                          ?.map((a) => a.name ?? 'Unknown')
                                          .join(', ') ??
                                      'Unknown Artist';
                                  // Extract year from releaseDate
                                  if (album.releaseDate != null) {
                                    final dateStr =
                                        album.releaseDate.toString();
                                    if (dateStr.length >= 4) {
                                      releaseYear = dateStr.substring(0, 4);
                                    }
                                  }
                                } else {
                                  // Fallback for dynamic type
                                  albumName =
                                      album.name?.toString() ?? 'Unknown Album';
                                  if (album.images != null &&
                                      album.images is List &&
                                      (album.images as List).isNotEmpty) {
                                    final firstImage =
                                        (album.images as List).first;
                                    imageUrl = firstImage.url?.toString();
                                  }
                                  if (album.artists != null) {
                                    if (album.artists is List) {
                                      artistNames = (album.artists as List)
                                          .map((a) =>
                                              a.name?.toString() ?? 'Unknown')
                                          .join(', ');
                                    }
                                  }
                                  // Try to extract year from releaseDate
                                  if (album.releaseDate != null) {
                                    final dateStr =
                                        album.releaseDate.toString();
                                    if (dateStr.length >= 4) {
                                      releaseYear = dateStr.substring(0, 4);
                                    }
                                  }
                                }

                                return Card(
                                  key: ValueKey('album_${album.id ?? index}'),
                                  color: Colors.grey[900],
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 4, horizontal: 0),
                                  child: ListTile(
                                    leading: imageUrl != null
                                        ? AppCachedImage(
                                            imageUrl: imageUrl,
                                            width: 56,
                                            height: 56,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          )
                                        : Container(
                                            width: 56,
                                            height: 56,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[800],
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: const Icon(
                                              Icons.album,
                                              color: Colors.white70,
                                            ),
                                          ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            albumName,
                                            style: const TextStyle(
                                                color: Colors.white),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.only(left: 8.0),
                                          child: Icon(
                                            Icons.album,
                                            size: 16,
                                            color: Colors.white54,
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      releaseYear.isNotEmpty
                                          ? '$artistNames • $releaseYear'
                                          : artistNames,
                                      style: const TextStyle(
                                          color: Colors.white70),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: () => _selectAlbum(album),
                                  ),
                                );
                              }
                            },
                          ),
                        )
                      else if (searchParams.text.isNotEmpty && !_isSearching)
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(
                              child: Text(
                                'No results found',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              : Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: Column(
                      children: [
                        const Gap(16),
                        _buildSelectedTrackInfo(),
                        // Rating and like section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Rating stars
                            RatingBar(
                              initialRating: ratingScore,
                              minRating: 0,
                              maxRating: 5,
                              allowHalfRating: true,
                              itemSize: 32,
                              itemPadding:
                                  const EdgeInsets.symmetric(horizontal: 4.0),
                              ratingWidget: RatingWidget(
                                full:
                                    const Icon(Icons.star, color: Colors.amber),
                                empty: const Icon(Icons.star_border,
                                    color: Colors.grey),
                                half: const Icon(Icons.star_half,
                                    color: Colors.amber),
                              ),
                              onRatingUpdate: (rating) {
                                setState(() {
                                  ratingScore = rating;
                                });
                              },
                            ),

                            // Like button
                            IconButton(
                              onPressed: toggleHeart,
                              icon: Icon(
                                liked ? Ionicons.heart : Ionicons.heart_outline,
                                color: liked ? Colors.red : Colors.grey,
                                size: 28,
                              ),
                            ),
                          ],
                        ),

                        // const Gap(16),
                        _buildTagsField(),
                        const Gap(12),
                        _buildReviewTextField(),
                        const Gap(16),
                        _buildSubmitButton(),

                        const Gap(16),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
