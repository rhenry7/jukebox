import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/Api/api_key.dart';
import 'package:flutter_test_project/GIFs/gifs.dart';
import 'package:flutter_test_project/providers/reviews_provider.dart';
import 'package:flutter_test_project/ui/screens/Profile/ProfileSignUpWidget.dart';
import 'package:flutter_test_project/utils/reviews/review_helpers.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import 'package:spotify/spotify.dart' as spotify;

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

class _MyReviewSheetContentFormState extends ConsumerState<MyReviewSheetContentForm> {
  final FirebaseAuth auth = FirebaseAuth.instance;
  late String currentDate;
  bool liked = false;
  double ratingScore = 0;
  final Color background = Colors.white10;
  final TextEditingController reviewController = TextEditingController();
  final TextEditingController searchParams = TextEditingController();

  // Search state
  List<spotify.Track> _trackResults = [];
  List<dynamic> _albumResults = []; // Use dynamic to handle both Album and AlbumSimple
  bool _isSearching = false;
  String _selectedTrackTitle = '';
  String _selectedTrackArtist = '';
  String _selectedTrackImageUrl = '';
  Timer? _searchDebounce;
  String _searchFilter = 'all'; // 'all', 'song', 'album'

  @override
  void initState() {
    super.initState();
    DateTime now = DateTime.now();
    currentDate = DateFormat.yMMMMd('en_US').format(now);

    // Initialize with widget values if provided
    _selectedTrackTitle = widget.title;
    _selectedTrackArtist = widget.artist;
    _selectedTrackImageUrl = widget.albumImageUrl;

    // Listen to search input changes
    searchParams.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    reviewController.dispose();
    searchParams.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    // Cancel previous debounce timer
    _searchDebounce?.cancel();

    final query = searchParams.text.trim();
    print('⌨️  [INPUT] Search input changed: "$query" (length: ${query.length})');
    
    if (query.length >= 2) {
      print('   ✅ Query length sufficient, starting debounce timer (500ms)');
      // Debounce search by 500ms
      _searchDebounce = Timer(const Duration(milliseconds: 500), () {
        print('   ⏰ Debounce timer completed, executing search');
        _performSearch(query);
      });
    } else {
      print('   ⚠️  Query too short, clearing results');
      setState(() {
        _trackResults = [];
        _albumResults = [];
        _isSearching = false;
      });
    }
  }

  Future<void> _performSearch(String query) async {
    if (_isSearching) return;

    print('🔍 [SEARCH] Starting search...');
    print('   Query: "$query"');
    print('   Filter: $_searchFilter');

    setState(() {
      _isSearching = true;
    });

    try {
      final credentials = spotify.SpotifyApiCredentials(clientId, clientSecret);
      final spotifyApi = spotify.SpotifyApi(credentials);

      // Determine search types based on filter
      List<spotify.SearchType> searchTypes = [];
      if (_searchFilter == 'all') {
        searchTypes = [spotify.SearchType.track, spotify.SearchType.album];
        print('   Search types: [track, album]');
      } else if (_searchFilter == 'song') {
        searchTypes = [spotify.SearchType.track];
        print('   Search types: [track]');
      } else if (_searchFilter == 'album') {
        searchTypes = [spotify.SearchType.album];
        print('   Search types: [album]');
      }

      // Search based on selected filter
      // Increase limit to get more results, especially for albums
      final limit = _searchFilter == 'album' ? 20 : 10;
      print('   Limit: $limit');
      print('   Making API request to Spotify...');

      final searchResults = await spotifyApi.search
          .get(query, types: searchTypes)
          .first(limit);

      print('   ✅ API request successful');
      print('   Processing results...');

      List<spotify.Track> tracks = [];
      List<dynamic> albums = []; // Use dynamic to handle both Album and AlbumSimple
      int totalItemsProcessed = 0;
      
      for (var page in searchResults) {
        if (page.items != null) {
          print('   📄 Processing page with ${page.items!.length} items');
          for (var item in page.items!) {
            totalItemsProcessed++;
            if (item is spotify.Track) {
              tracks.add(item);
              print('   🎵 Track found: "${item.name}" by ${item.artists?.map((a) => a.name).join(', ') ?? 'Unknown'}');
            } else if (item is spotify.Album) {
              albums.add(item);
              print('   💿 Album found: "${item.name}" by ${item.artists?.map((a) => a.name).join(', ') ?? 'Unknown'}');
            } else if (item is spotify.AlbumSimple) {
              // Handle AlbumSimple - it has the same properties we need
              albums.add(item);
              final artistNames = item.artists != null
                  ? item.artists!.map((a) => a.name ?? 'Unknown').join(', ')
                  : 'Unknown';
              print('   💿 AlbumSimple found: "${item.name}" by $artistNames');
            } else {
              print('   ⚠️  Unknown item type: ${item.runtimeType}');
            }
          }
        } else {
          print('   ⚠️  Page has no items');
        }
      }

      print('   📊 Search Summary:');
      print('      Total items processed: $totalItemsProcessed');
      print('      Tracks found: ${tracks.length}');
      print('      Albums found: ${albums.length}');

      if (tracks.isNotEmpty) {
        print('   🎵 Tracks:');
        for (var track in tracks.take(5)) {
          print('      - "${track.name}" by ${track.artists?.map((a) => a.name).join(', ') ?? 'Unknown'}');
        }
        if (tracks.length > 5) {
          print('      ... and ${tracks.length - 5} more tracks');
        }
      }

      if (albums.isNotEmpty) {
        print('   💿 Albums:');
        for (var album in albums.take(5)) {
          print('      - "${album.name}" by ${album.artists?.map((a) => a.name).join(', ') ?? 'Unknown'}');
        }
        if (albums.length > 5) {
          print('      ... and ${albums.length - 5} more albums');
        }
      }

      if (mounted) {
        setState(() {
          _trackResults = tracks;
          _albumResults = albums;
          _isSearching = false;
        });
        print('   ✅ State updated successfully');
      }
    } catch (e, stackTrace) {
      print('❌ [SEARCH ERROR]');
      print('   Query: "$query"');
      print('   Filter: $_searchFilter');
      print('   Error: $e');
      print('   Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _trackResults = [];
          _albumResults = [];
          _isSearching = false;
        });
        print('   ✅ Error state handled, search cleared');
      }
    }
  }

  void _selectTrack(spotify.Track track) {
    print('🎵 [SELECT] Track selected:');
    print('   Title: "${track.name}"');
    print('   Artist: ${track.artists?.map((a) => a.name).join(', ') ?? 'Unknown'}');
    print('   Album: ${track.album?.name ?? 'Unknown'}');
    print('   Image URL: ${track.album?.images?.isNotEmpty == true ? track.album!.images!.first.url ?? 'None' : 'None'}');
    
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
    print('   ✅ Track selection complete');
  }

  void _selectAlbum(spotify.Album album) {
    print('💿 [SELECT] Album selected:');
    print('   Title: "${album.name}"');
    print('   Artist: ${album.artists?.map((a) => a.name).join(', ') ?? 'Unknown'}');
    print('   Image URL: ${album.images?.isNotEmpty == true ? album.images!.first.url ?? 'None' : 'None'}');
    print('   Release Date: ${album.releaseDate ?? 'Unknown'}');
    print('   Album Type: ${album.albumType ?? 'Unknown'}');
    
    setState(() {
      _selectedTrackTitle = album.name ?? '';
      _selectedTrackArtist = album.artists?.map((a) => a.name).join(', ') ?? '';
      _selectedTrackImageUrl = album.images?.isNotEmpty == true
          ? album.images!.first.url ?? ''
          : '';
      _trackResults = [];
      _albumResults = [];
      searchParams.clear();
    });
    print('   ✅ Album selection complete');
  }

  Widget _buildFilterPill(String filter, String label, IconData icon) {
    final isSelected = _searchFilter == filter;
    return GestureDetector(
      onTap: () {
        print('🏷️  [FILTER] Changed filter from "$_searchFilter" to "$filter"');
        setState(() {
          _searchFilter = filter;
          // Trigger new search if there's a query
          if (searchParams.text.trim().length >= 2) {
            print('   Triggering new search with filter "$filter"');
            _performSearch(searchParams.text.trim());
          } else {
            print('   No active query, filter changed but no search triggered');
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

    String review = reviewController.text.trim();

    // Basic validation
    if (review.isEmpty && ratingScore == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a rating or write a review'),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: background),
      height: MediaQuery.of(context).size.height * 0.9, // Responsive height
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with back button and user info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              Row(
                children: [
                  Text(
                    auth.currentUser?.displayName ?? "NotSignedIn",
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
          ),

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
                                  child: const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: DiscoBallLoading(),
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
                      // Search results
                      if (_trackResults.isNotEmpty || _albumResults.isNotEmpty)
                        Expanded(
                          child: ListView.builder(
                            itemCount: _trackResults.length + _albumResults.length,
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
                                  color: Colors.grey[900],
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 4, horizontal: 0),
                                  child: ListTile(
                                    leading: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: imageUrl != null
                                          ? Image.network(
                                              imageUrl,
                                              width: 56,
                                              height: 56,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                return Container(
                                                  width: 56,
                                                  height: 56,
                                                  color: Colors.grey[800],
                                                  child: const Icon(
                                                    Icons.music_note,
                                                    color: Colors.white70,
                                                  ),
                                                );
                                              },
                                            )
                                          : Container(
                                              width: 56,
                                              height: 56,
                                              color: Colors.grey[800],
                                              child: const Icon(
                                                Icons.music_note,
                                                color: Colors.white70,
                                              ),
                                            ),
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            track.name ?? 'Unknown Track',
                                            style: const TextStyle(color: Colors.white),
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
                                      style: const TextStyle(color: Colors.white70),
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
                                  artistNames = album.artists?.map((a) => a.name).join(', ') ?? 'Unknown Artist';
                                  // Extract year from releaseDate
                                  if (album.releaseDate != null) {
                                    final dateStr = album.releaseDate.toString();
                                    if (dateStr.length >= 4) {
                                      releaseYear = dateStr.substring(0, 4);
                                    }
                                  }
                                } else if (album is spotify.AlbumSimple) {
                                  albumName = album.name ?? 'Unknown Album';
                                  imageUrl = album.images?.isNotEmpty == true
                                      ? album.images!.first.url
                                      : null;
                                  artistNames = album.artists?.map((a) => a.name ?? 'Unknown').join(', ') ?? 'Unknown Artist';
                                  // Extract year from releaseDate
                                  if (album.releaseDate != null) {
                                    final dateStr = album.releaseDate.toString();
                                    if (dateStr.length >= 4) {
                                      releaseYear = dateStr.substring(0, 4);
                                    }
                                  }
                                } else {
                                  // Fallback for dynamic type
                                  albumName = album.name?.toString() ?? 'Unknown Album';
                                  if (album.images != null && album.images is List && (album.images as List).isNotEmpty) {
                                    final firstImage = (album.images as List).first;
                                    imageUrl = firstImage.url?.toString();
                                  }
                                  if (album.artists != null) {
                                    if (album.artists is List) {
                                      artistNames = (album.artists as List)
                                          .map((a) => a.name?.toString() ?? 'Unknown')
                                          .join(', ');
                                    }
                                  }
                                  // Try to extract year from releaseDate
                                  if (album.releaseDate != null) {
                                    final dateStr = album.releaseDate.toString();
                                    if (dateStr.length >= 4) {
                                      releaseYear = dateStr.substring(0, 4);
                                    }
                                  }
                                }

                                return Card(
                                  color: Colors.grey[900],
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 4, horizontal: 0),
                                  child: ListTile(
                                    leading: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: imageUrl != null
                                          ? Image.network(
                                              imageUrl,
                                              width: 56,
                                              height: 56,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                return Container(
                                                  width: 56,
                                                  height: 56,
                                                  color: Colors.grey[800],
                                                  child: const Icon(
                                                    Icons.album,
                                                    color: Colors.white70,
                                                  ),
                                                );
                                              },
                                            )
                                          : Container(
                                              width: 56,
                                              height: 56,
                                              color: Colors.grey[800],
                                              child: const Icon(
                                                Icons.album,
                                                color: Colors.white70,
                                              ),
                                            ),
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            albumName,
                                            style: const TextStyle(color: Colors.white),
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
                                      style: const TextStyle(color: Colors.white70),
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
              : Column(
                  children: [
                    const Gap(16),
                    // Album info section
                    Row(
                      children: [
                        // Album image
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey[800],
                          ),
                          child: _selectedTrackImageUrl.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    _selectedTrackImageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(Icons.music_note,
                                                color: Colors.white),
                                  ),
                                )
                              : const Icon(Icons.music_note,
                                  color: Colors.white),
                        ),

                        const Gap(16),

                        // Title and artist
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
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Gap(24),

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
                            full: const Icon(Icons.star, color: Colors.amber),
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

                    const Gap(24),

                    // Review text field
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: SizedBox(
                        width: 500.0,
                        height: 200.0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[700]!),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: TextField(
                              controller: reviewController,
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: 'What did you think?',
                                hintStyle: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Submit button
                    SizedBox(
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
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const Gap(16),
                  ],
                ),
        ],
      ),
    );
  }
}
