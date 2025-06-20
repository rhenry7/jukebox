import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test_project/GIFs/gifs.dart';
import 'package:flutter_test_project/MusicPreferences/musicRecommendationService.dart';
import 'package:flutter_test_project/models/enhanced_user_preferences.dart';
import 'package:flutter_test_project/models/music_recommendation.dart';
import 'package:ionicons/ionicons.dart';

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
              Row(
                children: [
                  IconButton(
                      onPressed: () => {},
                      icon: const Icon(Ionicons.close_circle_outline,
                          color: Colors.grey)),
                  IconButton(
                      onPressed: () => {},
                      icon: const Icon(Ionicons.add_circle_outline,
                          color: Colors.green)),
                ],
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
                    : RefreshIndicator(
                        onRefresh: () async {
                          _refreshRecommendations();
                          // Wait for recommendations to reload
                          await _albumsFuture;
                        },
                        child: FutureBuilder<List<MusicRecommendation>>(
                          future: _albumsFuture,
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Column(
                                children: [
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: AlbumList(albums: snapshot.data!),
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
