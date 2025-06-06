import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
  final List<EnrichedTrack> albums;

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
                child: album.imageUrl.isNotEmpty
                    ? Image.network(
                        album.imageUrl,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.music_note,
                              size: 40,
                              color: Colors.grey,
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        },
                      )
                    : Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.music_note,
                          size: 40,
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
                      album.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      album.artist,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    // Button with size constraints
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: album.albumUrl.isNotEmpty
                            ? () async {
                                final url = album.albumUrl;
                                if (await canLaunch(url)) {
                                  await launch(url);
                                } else {
                                  // Show error message instead of throwing
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('Could not open Spotify link'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            : null, // Disable button if no URL
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF1DB954), // Spotify green
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: const Text(
                          'Listen on Spotify',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
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
  Future<List<EnrichedTrack>>? _albumsFuture;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _fetchUserPreferences().then((preferences) {
      setState(() {
        _albumsFuture = UpdatedRecommendationService.getEnrichedRecommendations(
            preferences.toJson());
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
      appBar: AppBar(title: Text('Recommended Albums')),
      body: !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : _albumsFuture == null
              ? const Center(child: Text('Failed to load recommendations'))
              : FutureBuilder<List<EnrichedTrack>>(
                  future: _albumsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    } else if (snapshot.hasData) {
                      return AlbumList(albums: snapshot.data!);
                    } else {
                      return const Center(child: Text('No recommendations.'));
                    }
                  },
                ),
    );
  }
}
