import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test_project/DiscoveryTab/track_recommendation_list.dart';
import 'package:flutter_test_project/GIFs/gifs.dart';
import 'package:flutter_test_project/MusicPreferences/musicRecommendationService.dart';
import 'package:flutter_test_project/models/enhanced_user_preferences.dart';
import 'package:flutter_test_project/models/music_recommendation.dart';
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

class _RecommendedAlbumScreenState extends State<RecommendedAlbumScreen> {
  Future<List<MusicRecommendation>>? _albumsFuture;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
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
      return EnhancedUserPreferences.fromJson(doc.data()!);
    } else {
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
    try {
      final preferences = await _fetchUserPreferences();
      final prefs = await SharedPreferences.getInstance();
      final List<String>? recsJsonList = prefs.getStringList('cached_recs');
      if (recsJsonList != null && recsJsonList.isNotEmpty) {
        debugPrint('pull from cached');
        final List<MusicRecommendation> cachedRecs = [];
        for (final jsonStr in recsJsonList) {
          try {
            final decoded = jsonDecode(jsonStr);
            if (decoded is Map<String, dynamic>) {
              final rec = MusicRecommendation.fromJson(decoded);
              if (rec.isValid) {
                cachedRecs.add(rec);
              }
            }
          } catch (e) {
            debugPrint('Error parsing cached music recommendation: $e');
            // Continue to next item
          }
        }
        
        // If we got valid recommendations from cache, return them
        if (cachedRecs.isNotEmpty) {
          return cachedRecs;
        } else {
          // Cache is corrupted, clear it and fetch fresh
          debugPrint('Cache corrupted, clearing and fetching fresh');
          await prefs.remove('cached_recs');
        }
      }
      
      // Fetch new recommendations
      debugPrint('Fetching new recommendations');
      // OPTIMIZATION: Using spotify-only mode (default) - skips MusicBrainz for speed
      // MusicBrainz validation is skipped by default (saves ~1 second per recommendation)
      // Options:
      // - validationMode: 'spotify-only' (default, fastest) or 'hybrid' (includes MusicBrainz)
      // - validateTopN: Only validate top N recommendations (0 = all)
      // - skipMetadataEnrichment: Skip images/metadata for faster validation
      final List<MusicRecommendation> recommendations =
          await MusicRecommendationService.getRecommendations(
        preferences,
        // validationMode defaults to 'spotify-only' (skips MusicBrainz)
        validateTopN: 10, // Only validate top 10 (rest shown without validation)
        skipMetadataEnrichment: false, // Keep metadata for better UX
      );
      final newRecsJsonList =
          recommendations.map((rec) => jsonEncode(rec.toJson())).toList();
      await prefs.setStringList('cached_recs', newRecsJsonList);
      return recommendations;
    } catch (error) {
      debugPrint('Error fetching user preferences and or recommendations: $error');
      // Clear cache on error to prevent future issues
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('cached_recs');
      } catch (e) {
        debugPrint('Error clearing cache: $e');
      }
      rethrow;
    }
  }

  Future<List<MusicRecommendation>> fetchNewRecommendations() async {
    try {
      final preferences = await _fetchUserPreferences();
      final prefs = await SharedPreferences.getInstance();

      // OPTIMIZATION: Using spotify-only mode (default) - skips MusicBrainz for speed
      final List<MusicRecommendation> recommendations =
          await MusicRecommendationService.getRecommendations(
        preferences,
        // validationMode defaults to 'spotify-only' (skips MusicBrainz)
      );
      final newRecsJsonList =
          recommendations.map((rec) => jsonEncode(rec.toJson())).toList();
      await prefs.setStringList('cached_recs', newRecsJsonList);
      return recommendations;
    } catch (error) {
      debugPrint('Error in fetching new recommendations: $error');
      return [];
    }
  }

  void _loadRecommendations() async {
    try {
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
                          // _refreshRecommendations();
                          // // Wait for recommendations to reload
                          // await _albumsFuture;
                        },
                        child: FutureBuilder<List<MusicRecommendation>>(
                          future: _albumsFuture,
                          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
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
                                      style: const TextStyle(color: Colors.white70),
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
                                    final hasPreferences = prefsSnapshot.data ?? false;
                                    
                                    return Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.music_off, 
                                              size: 64, color: Colors.grey),
                                          const SizedBox(height: 16),
                                          Text(
                                            hasPreferences 
                                                ? 'No recommendations yet'
                                                : 'Set your preferences to start getting recommendations',
                                            style: const TextStyle(
                                                color: Colors.white, fontSize: 20),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            hasPreferences
                                                ? 'Update your music preferences to get personalized recommendations!'
                                                : 'Tell us about your music taste to receive personalized recommendations.',
                                            style: const TextStyle(color: Colors.white70),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 24),
                                          if (hasPreferences)
                                            ElevatedButton.icon(
                                              onPressed: _refreshRecommendations,
                                              icon: const Icon(Icons.refresh),
                                              label: const Text('Refresh'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red[600],
                                                foregroundColor: Colors.white,
                                              ),
                                            )
                                          else
                                            ElevatedButton.icon(
                                              onPressed: () {
                                                // Navigate to preferences
                                                Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (context) => Scaffold(
                                                      appBar: AppBar(
                                                        title: const Text('Set Up Preferences'),
                                                        backgroundColor: Colors.black,
                                                      ),
                                                      body: profileRoute('Preferences'),
                                                    ),
                                                  ),
                                                );
                                              },
                                              icon: const Icon(Icons.settings),
                                              label: const Text('Set Preferences'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red[600],
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
