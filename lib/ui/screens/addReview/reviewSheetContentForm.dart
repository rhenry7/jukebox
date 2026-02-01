import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_test_project/Api/api_key.dart';
import 'package:flutter_test_project/ui/screens/Profile/ProfileSignUpWidget.dart';
import 'package:flutter_test_project/utils/reviews/review_helpers.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import 'package:spotify/spotify.dart' as spotify;

class MyReviewSheetContentForm extends StatefulWidget {
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
  State<MyReviewSheetContentForm> createState() =>
      _MyReviewSheetContentFormState();
}

class _MyReviewSheetContentFormState extends State<MyReviewSheetContentForm> {
  final FirebaseAuth auth = FirebaseAuth.instance;
  late String currentDate;
  bool liked = false;
  double ratingScore = 0;
  final Color background = Colors.white10;
  final TextEditingController reviewController = TextEditingController();
  final TextEditingController searchParams = TextEditingController();

  // Search state
  List<spotify.Track> _searchResults = [];
  bool _isSearching = false;
  String _selectedTrackTitle = '';
  String _selectedTrackArtist = '';
  String _selectedTrackImageUrl = '';
  Timer? _searchDebounce;

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
    if (query.length >= 2) {
      // Debounce search by 500ms
      _searchDebounce = Timer(const Duration(milliseconds: 500), () {
        _performSearch(query);
      });
    } else {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  Future<void> _performSearch(String query) async {
    if (_isSearching) return;

    setState(() {
      _isSearching = true;
    });

    try {
      final credentials = spotify.SpotifyApiCredentials(clientId, clientSecret);
      final spotifyApi = spotify.SpotifyApi(credentials);

      final searchResults = await spotifyApi.search
          .get(query, types: [spotify.SearchType.track]).first(10);

      List<spotify.Track> tracks = [];
      for (var page in searchResults) {
        if (page.items != null) {
          for (var item in page.items!) {
            if (item is spotify.Track) {
              tracks.add(item);
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _searchResults = tracks;
          _isSearching = false;
        });
      }
    } catch (e) {
      print('Error searching: $e');
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  void _selectTrack(spotify.Track track) {
    setState(() {
      _selectedTrackTitle = track.name ?? '';
      _selectedTrackArtist = track.artists?.map((a) => a.name).join(', ') ?? '';
      _selectedTrackImageUrl = track.album?.images?.isNotEmpty == true
          ? track.album!.images!.first.url ?? ''
          : '';
      _searchResults = [];
      searchParams.clear();
    });
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
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
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
                                          _searchResults = [];
                                        });
                                      },
                                    )
                                  ]
                                : null,
                      ),
                      const Gap(16),
                      // Search results
                      if (_searchResults.isNotEmpty)
                        Expanded(
                          child: ListView.builder(
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final track = _searchResults[index];
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
                                  title: Text(
                                    track.name ?? 'Unknown Track',
                                    style: const TextStyle(color: Colors.white),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    artistNames,
                                    style:
                                        const TextStyle(color: Colors.white70),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () => _selectTrack(track),
                                ),
                              );
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
