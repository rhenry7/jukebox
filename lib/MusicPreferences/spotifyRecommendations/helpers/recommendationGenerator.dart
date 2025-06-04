import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test_project/MusicPreferences/MusicTaste.dart';
import 'package:flutter_test_project/MusicPreferences/openAIRecommendations.dart';
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
  final List<String> albums;

  const AlbumList({super.key, required this.albums});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: albums.length,
      itemBuilder: (_, index) {
        final album = albums[index];
        return ListTile(
          title: Text(album),
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
  Future<List<String>>? _albumsFuture;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
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
              : FutureBuilder<List<String>>(
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
