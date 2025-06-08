import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test_project/GIFs/gifs.dart';
import 'package:flutter_test_project/MusicPreferences/MusicTaste.dart';
import 'package:flutter_test_project/MusicPreferences/musicRecommendationService.dart';
import 'package:flutter_test_project/api_key.dart';
import 'package:flutter_test_project/MusicPreferences/spotifyRecommendations/helpers/tokenManager.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

// Album Model
class Album {
  final String name;
  final String artist;
  final String imageUrl;
  final String albumUrl;

  Album({
    required this.name,
    required this.artist,
    required this.imageUrl,
    required this.albumUrl,
  });

  factory Album.fromTrackJson(Map<String, dynamic> track) {
    final album = track['album'];
    return Album(
      name: album['name'],
      artist: track['artists'][0]['name'],
      imageUrl: album['images'][0]['url'],
      albumUrl: album['external_urls']['spotify'],
    );
  }
}

// Function to sort and get top genres

// Album List Widget
class AlbumList extends StatelessWidget {
  final List<MusicRecommendation> albums;

  const AlbumList({super.key, required this.albums});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: albums.length,
      itemBuilder: (_, index) {
        final album = albums[index];
        return Card(
          elevation: 1,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            side: BorderSide(color: Color.fromARGB(56, 158, 158, 158)),
          ),
          color: Colors.black,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.music_note,
                    size: 10,
                    color: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Expanded content with proper constraints
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      album.song,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      album.artist,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      album.album,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    // Button with size constraints
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Main Widget
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

  void _loadRecommendations() {
    _fetchUserPreferences().then((preferences) {
      setState(() {
        _albumsFuture =
            MusicRecommendationService.getRecommendations(preferences.toJson());
        _isInitialized = true;
      });
    }).catchError((error) {
      print("Error fetching user preferences: $error");
      setState(() {
        _albumsFuture = Future.value([]);
        _isInitialized = true;
      });
    });
  }

  void _refreshRecommendations() {
    setState(() {
      _isInitialized = false;
    });
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
                    : FutureBuilder<List<MusicRecommendation>>(
                        future: _albumsFuture,
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return Column(
                              children: [
                                const SizedBox(height: 16),
                                Expanded(
                                  child: AlbumList(albums: snapshot.data!),
                                ),
                                // Padding(
                                //   padding: const EdgeInsets.all(16.0),
                                //   child: SizedBox(
                                //     width: double.infinity,
                                //     child: ElevatedButton.icon(
                                //       onPressed: _refreshRecommendations,
                                //       icon: const Icon(Icons.refresh),
                                //       label: const Text(''),
                                //       style: ElevatedButton.styleFrom(
                                //         shape: RoundedRectangleBorder(
                                //           borderRadius: BorderRadius.circular(
                                //               25), // Creates pill-shaped indicatorRound radius
                                //         ),
                                //         padding: const EdgeInsets.symmetric(
                                //             horizontal: 24, vertical: 12),
                                //         backgroundColor:
                                //             Colors.yellow[600], // Button color
                                //       ),
                                //     ),
                                //   ),
                                // ),
                              ],
                            );
                          }
                          return const DiscoBallLoading();
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
