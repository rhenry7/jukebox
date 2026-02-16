import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test_project/DiscoveryTab/track_recommendation_list.dart';
import 'package:flutter_test_project/GIFs/gifs.dart';
import 'package:flutter_test_project/MusicPreferences/musicRecommendationService.dart';
import 'package:flutter_test_project/models/enhanced_user_preferences.dart';
import 'package:flutter_test_project/models/music_recommendation.dart';
import 'package:flutter_test_project/services/review_analysis_service.dart';
import 'package:flutter_test_project/ui/screens/Profile/helpers/profileHelpers.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Function to sort and get top genres
class RecommendedAlbumScreen extends StatefulWidget {
  const RecommendedAlbumScreen({
    super.key,
  });

  @override
  State<RecommendedAlbumScreen> createState() => _RecommendedAlbumScreenState();
}

class _RecommendedAlbumScreenState extends State<RecommendedAlbumScreen>
    with AutomaticKeepAliveClientMixin {
  Future<List<MusicRecommendation>>? _albumsFuture;
  bool _isInitialized = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _preferencesSubscription;
  String? _lastPreferenceSignature;
  static const String _recentShownRecsKey = 'recent_shown_recs_v1';
  static const int _maxRecentShown = 80;
  static List<MusicRecommendation>? _sessionRecommendations;
  static String? _sessionPreferenceSignature;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _listenForPreferenceChanges();
    _loadRecommendations();
  }

  @override
  void dispose() {
    _preferencesSubscription?.cancel();
    super.dispose();
  }

  void _listenForPreferenceChanges() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || userId.isEmpty) return;

    _preferencesSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('musicPreferences')
        .doc('profile')
        .snapshots()
        .listen((doc) {
      final nextSignature = _buildPreferenceSignature(doc.data());
      if (_lastPreferenceSignature == null) {
        _lastPreferenceSignature = nextSignature;
        return;
      }

      if (nextSignature != _lastPreferenceSignature) {
        _lastPreferenceSignature = nextSignature;
        debugPrint(
          'Preferences changed in Discover tab, refreshing recommendations...',
        );
        _refreshRecommendations();
      }
    });
  }

  String _buildPreferenceSignature(Map<String, dynamic>? data) {
    if (data == null) return 'none';

    final favorites = (data['favoriteGenres'] as List<dynamic>? ?? [])
        .map((e) => e.toString().toLowerCase().trim())
        .where((e) => e.isNotEmpty)
        .toList()
      ..sort();

    final disliked = (data['dislikedGenres'] as List<dynamic>? ?? [])
        .map((e) => e.toString().toLowerCase().trim())
        .where((e) => e.isNotEmpty)
        .toList()
      ..sort();

    final weightsMap = data['genreWeights'] as Map<String, dynamic>? ?? {};
    final weighted = weightsMap.entries
        .map((e) => '${e.key.toLowerCase().trim()}:${e.value}')
        .toList()
      ..sort();

    return 'f=${favorites.join(",")}|d=${disliked.join(",")}|w=${weighted.join(",")}';
  }

  Future<EnhancedUserPreferences> _fetchUserPreferences() async {
    final String userId = FirebaseAuth.instance.currentUser != null
        ? FirebaseAuth.instance.currentUser!.uid
        : '';

    if (userId.isEmpty) {
      debugPrint('User not logged in, cannot fetch preferences.');
      return EnhancedUserPreferences(favoriteGenres: [], favoriteArtists: []);
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('musicPreferences')
        .doc('profile')
        .get();

    if (doc.exists) {
      _lastPreferenceSignature = _buildPreferenceSignature(doc.data());
      return EnhancedUserPreferences.fromJson(doc.data()!);
    } else {
      _lastPreferenceSignature = 'none';
      return EnhancedUserPreferences(favoriteGenres: [], favoriteArtists: []);
    }
  }

  Future<bool> _checkIfUserHasPreferences() async {
    final String userId = FirebaseAuth.instance.currentUser != null
        ? FirebaseAuth.instance.currentUser!.uid
        : '';

    if (userId.isEmpty) {
      return false;
    }

    return hasUserPreferences(userId);
  }

  Future<List<MusicRecommendation>> processRecommendations() async {
    return _fetchFreshRecommendations();
  }

  Future<List<String>> _readRecentShownKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_recentShownRecsKey) ?? [];
    return stored
        .map((e) => e.toLowerCase().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> _storeRecentShown(
      List<MusicRecommendation> recommendations) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await _readRecentShownKeys();

    final merged = <String>[...existing];
    for (final rec in recommendations) {
      final key = '${rec.artist}|${rec.song}'.toLowerCase().trim();
      if (!merged.contains(key)) {
        merged.add(key);
      }
    }

    final trimmed = merged.length > _maxRecentShown
        ? merged.sublist(merged.length - _maxRecentShown)
        : merged;
    await prefs.setStringList(_recentShownRecsKey, trimmed);
  }

  Future<List<MusicRecommendation>> _fetchFreshRecommendations() async {
    try {
      final preferences = await _fetchUserPreferences();
      final prefs = await SharedPreferences.getInstance();
      // Legacy cache key no longer used for playback to avoid repetition.
      await prefs.remove('cached_recs');

      final recentShown = await _readRecentShownKeys();
      final recentShownSet = recentShown.toSet();
      debugPrint('Fetching fresh recommendations '
          '(excluding ${recentShown.length} recently shown tracks)');
      // OPTIMIZATION: Using spotify-only mode (default) - skips MusicBrainz for speed
      // MusicBrainz validation is skipped by default (saves ~1 second per recommendation)
      // Options:
      // - validationMode: 'spotify-only' (default, fastest) or 'hybrid' (includes MusicBrainz)
      // - validateTopN: Only validate top N recommendations (0 = all)
      // - skipMetadataEnrichment: Skip images/metadata for faster validation
      final List<MusicRecommendation> recommendations =
          await MusicRecommendationService.getRecommendations(
        preferences,
        excludeSongs: recentShown,
        count: 20, // fetch wider pool, then filter already-shown tracks
        // validationMode defaults to 'spotify-only' (skips MusicBrainz)
        validateTopN:
            10, // Only validate top 10 (rest shown without validation)
        skipMetadataEnrichment: false, // Keep metadata for better UX
      );

      // Hard guard: never show already-seen tracks if possible.
      final unseenRecommendations = recommendations.where((rec) {
        final key = '${rec.artist}|${rec.song}'.toLowerCase().trim();
        return !recentShownSet.contains(key);
      }).toList();

      final finalRecommendations = unseenRecommendations.isNotEmpty
          ? unseenRecommendations
          : recommendations;

      _sessionRecommendations = finalRecommendations;
      _sessionPreferenceSignature = _lastPreferenceSignature ?? 'none';
      await _storeRecentShown(finalRecommendations);
      return finalRecommendations;
    } catch (error) {
      debugPrint(
          'Error fetching user preferences and or recommendations: $error');
      rethrow;
    }
  }

  Future<List<MusicRecommendation>> fetchNewRecommendations() async {
    try {
      return await _fetchFreshRecommendations();
    } catch (error) {
      debugPrint('Error in fetching new recommendations: $error');
      return [];
    }
  }

  Future<void> _clearCachesOnRefresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_recs'); // legacy
      _sessionRecommendations = null;
      _sessionPreferenceSignature = null;

      // Clear Firestore-backed review analysis cache so refresh is fully fresh.
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null && userId.isNotEmpty) {
        await ReviewAnalysisService.clearCache(userId);
      }
    } catch (e) {
      debugPrint('Error clearing recommendation caches on refresh: $e');
    }
  }

  void _loadRecommendations() async {
    try {
      await _fetchUserPreferences();
      final currentSignature = _lastPreferenceSignature ?? 'none';

      if (_sessionRecommendations != null &&
          _sessionRecommendations!.isNotEmpty &&
          _sessionPreferenceSignature == currentSignature) {
        debugPrint('Using in-memory Discover recommendations '
            '(${_sessionRecommendations!.length})');
        setState(() {
          _albumsFuture = Future.value(_sessionRecommendations!);
          _isInitialized = true;
        });
        return;
      }

      setState(() {
        _albumsFuture = processRecommendations();
        _isInitialized = true;
      });
    } catch (error) {
      debugPrint('Error fetching user preferences: $error');
      setState(() {
        _albumsFuture = Future.value([]);
        _isInitialized = true;
      });
    }
  }

  void _refreshRecommendations() async {
    try {
      await _clearCachesOnRefresh();

      // Create a new future for the refresh
      final newFuture = fetchNewRecommendations();

      setState(() {
        _albumsFuture = newFuture;
        _isInitialized = true;
      });

      // Wait for the future to complete to ensure UI updates
      await newFuture;

      // Force a rebuild after the future completes
      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      debugPrint('Error fetching user recs: $error');
      if (mounted) {
        setState(() {
          _albumsFuture = Future.value([]);
          _isInitialized = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: !_isInitialized
                ? const Center(child: DiscoBallLoading())
                : _albumsFuture == null
                    ? const Center(
                        child: Text('Failed to load recommendations'))
                    : RefreshIndicator(
                        onRefresh: () async {
                          _refreshRecommendations();
                          await _albumsFuture;
                        },
                        child: FutureBuilder<List<MusicRecommendation>>(
                          future: _albumsFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const DiscoBallLoading();
                            }

                            if (snapshot.hasError) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.error_outline,
                                        color: Colors.red, size: 48),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Error loading recommendations',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 18),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${snapshot.error}',
                                      style: const TextStyle(
                                          color: Colors.white70),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: _refreshRecommendations,
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              );
                            }

                            if (snapshot.hasData) {
                              if (snapshot.data!.isEmpty) {
                                // Check if user has preferences set up
                                return FutureBuilder<bool>(
                                  future: _checkIfUserHasPreferences(),
                                  builder: (context, prefsSnapshot) {
                                    final hasPreferences =
                                        prefsSnapshot.data ?? false;

                                    return Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.music_off,
                                              size: 64, color: Colors.grey),
                                          const SizedBox(height: 16),
                                          Text(
                                            hasPreferences
                                                ? 'No recommendations yet'
                                                : 'Set your preferences to start getting recommendations',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 20),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            hasPreferences
                                                ? 'Update your music preferences or leave more reviews to get personalized recommendations!'
                                                : 'Leave more reviews to get personalized recommendations.',
                                            style: const TextStyle(
                                                color: Colors.white70),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 24),
                                          if (hasPreferences)
                                            ElevatedButton.icon(
                                              onPressed:
                                                  _refreshRecommendations,
                                              icon: const Icon(Icons.refresh),
                                              label: const Text('Refresh'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.red[600],
                                                foregroundColor: Colors.white,
                                              ),
                                            )
                                          else
                                            ElevatedButton.icon(
                                              onPressed: () {
                                                // Navigate to preferences
                                                Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        Scaffold(
                                                      appBar: AppBar(
                                                        title: const Text(
                                                            'Set Up Preferences'),
                                                        backgroundColor:
                                                            Colors.black,
                                                      ),
                                                      body: profileRoute(
                                                          'Preferences'),
                                                    ),
                                                  ),
                                                );
                                              },
                                              icon: const Icon(Icons.settings),
                                              label:
                                                  const Text('Set Preferences'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.red[600],
                                                foregroundColor: Colors.white,
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              }
                              return Column(
                                children: [
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: TrackRecommendationFromPreferences(
                                        albums: snapshot.data!),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(15.0),
                                    child: SizedBox(
                                        width: 300,
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.only(left: 10.0),
                                          child: FilledButton.tonalIcon(
                                              style: ButtonStyle(
                                                backgroundColor:
                                                    WidgetStateProperty.all(
                                                        Colors.white12),
                                              ),
                                              onPressed:
                                                  _refreshRecommendations,
                                              icon: const Icon(Icons.refresh,
                                                  color: Colors.white),
                                              label: const Text('')),
                                        )),
                                  ),
                                ],
                              );
                            }

                            return const DiscoBallLoading();
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
