import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test_project/DiscoveryTab/track_recommendation_list.dart';
import 'package:flutter_test_project/GIFs/gifs.dart';
import 'package:flutter_test_project/MusicPreferences/musicRecommendationService.dart';
import 'package:flutter_test_project/models/enhanced_user_preferences.dart';
import 'package:flutter_test_project/models/music_recommendation.dart';
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
        : "";

    if (userId.isEmpty) {
      print("User not logged in, cannot fetch preferences.");
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

  Future<List<MusicRecommendation>> processRecommendations() async {
    try {
      final preferences = await _fetchUserPreferences();
      final prefs = await SharedPreferences.getInstance();
      final List<String>? recsJsonList = prefs.getStringList('cached_recs');
      if (recsJsonList != null && recsJsonList.isNotEmpty) {
        print("pull from cached");
        return recsJsonList
            .map((jsonStr) {
              try {
                return MusicRecommendation.fromJson(jsonDecode(jsonStr));
              } catch (e) {
                print("Error parsing cached music recommendations: $e");
                return null;
              }
            })
            .whereType<MusicRecommendation>()
            .toList();
      } else {
        print("Fetching new recommendations");
        final List<MusicRecommendation> recommendations =
            await MusicRecommendationService.getRecommendations(
                preferences.toJson());
        final newRecsJsonList =
            recommendations.map((rec) => jsonEncode(rec.toJson())).toList();
        await prefs.setStringList('cached_recs', newRecsJsonList);
        return recommendations;
      }
    } catch (error) {
      print("Error fetching user preferences and or recommendations: $error");
      rethrow;
    }
  }

  Future<List<MusicRecommendation>> fetchNewRecommendations() async {
    try {
      final preferences = await _fetchUserPreferences();
      final prefs = await SharedPreferences.getInstance();
      final List<MusicRecommendation> recommendations =
          await MusicRecommendationService.getRecommendations(
              preferences.toJson());
      final newRecsJsonList =
          recommendations.map((rec) => jsonEncode(rec.toJson())).toList();
      await prefs.setStringList('cached_recs', newRecsJsonList);
      return recommendations;
    } catch (error) {
      print("Error in fetching new recommendations: $error");
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
      print("Error fetching user preferences: $error");
      setState(() {
        _albumsFuture = Future.value([]);
        _isInitialized = true;
      });
    }
  }

  void _refreshRecommendations() async {
    try {
      setState(() {
        _albumsFuture = fetchNewRecommendations();
        _isInitialized = true;
      });
    } catch (error) {
      print("Error fetching user recs: $error");
      setState(() {
        _albumsFuture = Future.value([]);
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: !_isInitialized
                ? const Center(child: CircularProgressIndicator())
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
                            if (snapshot.hasData) {
                              return Column(
                                children: [
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: TrackRecommendationFromPreferences(
                                        albums: snapshot.data!),
                                  ),
                                  IconButton(
                                    iconSize: 24,
                                    icon: const Icon(Icons.refresh_rounded),
                                    onPressed: () {
                                      _refreshRecommendations();
                                    },
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
