import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' as flutter;
import 'package:flutter/material.dart';
import 'package:flutter_test_project/GIFs/gifs.dart';
import 'package:flutter_test_project/Api/api_key.dart';
import 'package:flutter_test_project/DiscoveryTab/playlists/preferences.dart';
import 'package:flutter_test_project/DiscoveryTab/playlists/preferencesWidget.dart';
import 'package:spotify/spotify.dart';

class PersonalizedPlaylistsList extends StatefulWidget {
  const PersonalizedPlaylistsList({super.key});

  @override
  State<PersonalizedPlaylistsList> createState() =>
      _PersonalizedPlaylistsListState();
}

class _PersonalizedPlaylistsListState extends State<PersonalizedPlaylistsList> {
  final String userId = FirebaseAuth.instance.currentUser != null
      ? FirebaseAuth.instance.currentUser!.uid
      : "";

  late PersonalizedPlaylistService _playlistService;
  List<Playlist> _playlists = [];
  UserPreferences? _userPreferences;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _playlistService = PersonalizedPlaylistService(
        clientId, // Replace with your actual client ID
        clientSecret // Replace with your actual client secret
        );
    _loadUserPreferencesAndPlaylists();
  }

  Future<void> _loadUserPreferencesAndPlaylists() async {
    if (userId.isEmpty) {
      setState(() {
        _error = 'User not logged in';
        _isLoading = false;
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load user preferences from Firestore
      //UserPreferences? preferences = await _loadUserPreferencesFromFirestore();
      UserPreferences? preferences = createExampleUserPreferences();

      // if (preferences == null) {
      //   // If no preferences found, use example preferences or prompt user to set them up
      //   preferences = createExampleUserPreferences();
      //   // Optionally save these default preferences to Firestore
      //   await _saveUserPreferencesToFirestore(preferences);
      // }

      setState(() {
        _userPreferences = preferences;
      });

      // Fetch personalized playlists based on preferences
      List<Playlist> playlists =
          await _playlistService.fetchPersonalizedPlaylists(preferences);
      print(
          "Found playlists: $playlists, Found preferences: ${preferences.favoriteGenres}");

      setState(() {
        _playlists = playlists;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading playlists: $e';
        _isLoading = false;
      });
    }
  }

  Future<UserPreferences?> _loadUserPreferencesFromFirestore() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!doc.exists) {
        return null;
      }

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      return UserPreferences(
        favoriteGenres: List<String>.from(data['favoriteGenres'] ?? []),
        favoriteArtists: List<String>.from(data['favoriteArtists'] ?? []),
        dislikedGenres: List<String>.from(data['dislikedGenres'] ?? []),
        genreWeights: Map<String, double>.from(data['genreWeights'] ?? {}),
        recentlyPlayed: List<String>.from(data['recentlyPlayed'] ?? []),
        savedTracks: List<String>.from(data['savedTracks'] ?? []),
      );
    } catch (e) {
      print('Error loading user preferences: $e');
      return null;
    }
  }

  Future<void> _saveUserPreferencesToFirestore(
      UserPreferences preferences) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'favoriteGenres': preferences.favoriteGenres,
        'favoriteArtists': preferences.favoriteArtists,
        'dislikedGenres': preferences.dislikedGenres,
        'genreWeights': preferences.genreWeights,
        'recentlyPlayed': preferences.recentlyPlayed,
        'savedTracks': preferences.savedTracks,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving user preferences: $e');
    }
  }

  Future<void> _onPlaylistLiked(Playlist playlist) async {
    if (_userPreferences == null || playlist.id == null) return;

    try {
      // Update preferences based on liked playlist
      UserPreferences updatedPreferences =
          await _playlistService.updatePreferencesFromHistory(
        _userPreferences!,
        [playlist.id!], // liked playlists
        [], // disliked playlists
      );

      // Save updated preferences to Firestore
      await _saveUserPreferencesToFirestore(updatedPreferences);

      // Update local state
      setState(() {
        _userPreferences = updatedPreferences;
      });

      // Show feedback to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${playlist.name}" to your preferences!'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Refresh',
            onPressed: _loadUserPreferencesAndPlaylists,
          ),
        ),
      );

      // Record the interaction in Firestore for future recommendations
      await _recordPlaylistInteraction(playlist.id!, 'liked');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating preferences: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _recordPlaylistInteraction(
      String playlistId, String action) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('playlist_interactions')
          .add({
        'playlistId': playlistId,
        'action': action, // 'liked', 'disliked', 'played'
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error recording playlist interaction: $e');
    }
  }

  String _getPlaylistSubtitle(Playlist playlist) {
    List<String> subtitleParts = [];

    if (playlist.tracks?.total != null) {
      subtitleParts.add('${playlist.tracks!.total} tracks');
    }

    if (playlist.followers?.total != null) {
      int followers = playlist.followers!.total!;
      if (followers >= 1000000) {
        subtitleParts
            .add('${(followers / 1000000).toStringAsFixed(1)}M followers');
      } else if (followers >= 1000) {
        subtitleParts
            .add('${(followers / 1000).toStringAsFixed(1)}K followers');
      } else if (followers > 0) {
        subtitleParts.add('$followers followers');
      }
    }

    return subtitleParts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    if (userId.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('User not logged in.', style: TextStyle(color: Colors.white)),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const DiscoBallLoading();
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUserPreferencesAndPlaylists,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_playlists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.playlist_play, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No playlists found.',
                style: TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            const Text(
              'Try updating your music preferences',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUserPreferencesAndPlaylists,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUserPreferencesAndPlaylists,
      child: ListView.builder(
        itemCount: _playlists.length,
        itemBuilder: (context, index) {
          var playlist = _playlists[index];
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              elevation: 1,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                side: BorderSide(color: Color.fromARGB(56, 158, 158, 158)),
              ),
              color: Colors.black,
              child: InkWell(
                onTap: () => _onPlaylistTapped(playlist),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      ListTile(
                        leading: SizedBox(
                          width: 48,
                          height: 48,
                          child: _buildPlaylistImage(playlist),
                        ),
                        title: Text(
                          playlist.name ?? 'Unknown Playlist',
                          style: const TextStyle(color: Colors.white),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          _getPlaylistSubtitle(playlist),
                          style: const TextStyle(color: Colors.white70),
                        ),
                        trailing: IconButton(
                          onPressed: () => _onPlaylistLiked(playlist),
                          icon: const Icon(
                            Icons.favorite_border,
                            color: Colors.red,
                          ),
                        ),
                      ),
                      if (playlist.description?.isNotEmpty == true)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              playlist.description!,
                              maxLines: 3,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.0,
                                fontStyle: FontStyle.italic,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaylistImage(Playlist playlist) {
    if (playlist.images?.isNotEmpty == true) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: flutter.Image.network(
          playlist.images!.first.url!,
          width: 48,
          height: 48,
          fit: flutter.BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Center(
                child: flutter.CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.queue_music,
                color: Colors.white,
                size: 24,
              ),
            );
          },
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(
        Icons.queue_music,
        color: Colors.white,
        size: 24,
      ),
    );
  }

  void _onPlaylistTapped(Playlist playlist) {
    // Navigate to playlist detail page or open in Spotify
    if (playlist.externalUrls?.spotify != null) {
      // You can implement navigation to a detailed playlist view
      // or open the Spotify URL
      print('Opening playlist: ${playlist.name}');
      // Navigator.push(context, MaterialPageRoute(builder: (context) => PlaylistDetailPage(playlist: playlist)));
    }
  }
}
