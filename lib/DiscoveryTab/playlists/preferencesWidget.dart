// Example Flutter widget using the personalized playlist service
import 'package:flutter/material.dart' as flutter;
import 'package:flutter/material.dart';
import 'package:flutter_test_project/Api/api_key.dart';
import 'package:flutter_test_project/DiscoveryTab/playlists/preferences.dart';
import 'package:flutter_test_project/GIFs/gifs.dart';
import 'package:spotify/spotify.dart';

class PersonalizedPlaylistsTab extends StatefulWidget {
  final UserPreferences userPreferences;

  const PersonalizedPlaylistsTab({
    super.key,
    required this.userPreferences,
  });

  @override
  _PersonalizedPlaylistsTabState createState() =>
      _PersonalizedPlaylistsTabState();
}

class _PersonalizedPlaylistsTabState extends State<PersonalizedPlaylistsTab> {
  late PersonalizedPlaylistService _playlistService;
  List<Playlist> _playlists = [];
  bool _isLoading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _playlistService = PersonalizedPlaylistService(clientId, clientSecret);
    _loadPersonalizedPlaylists();
  }

  Future<void> _loadPersonalizedPlaylists() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final playlists = await _playlistService
          .fetchPersonalizedPlaylists(widget.userPreferences);

      setState(() {
        _playlists = playlists;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load playlists: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _onPlaylistLiked(String playlistId) async {
    // Update user preferences based on liked playlist
    try {
      final updatedPreferences =
          await _playlistService.updatePreferencesFromHistory(
        widget.userPreferences,
        [playlistId], // liked playlists
        [], // disliked playlists
      );

      // Save updated preferences to your user profile/database
      // await _saveUserPreferences(updatedPreferences);

      // Optionally refresh recommendations
      _loadPersonalizedPlaylists();
    } catch (e) {
      print('Error updating preferences: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Playlists'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPersonalizedPlaylists,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPersonalizedPlaylists,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DiscoBallLoading(),
            SizedBox(height: 16),
            Text('Finding playlists for you...'),
          ],
        ),
      );
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPersonalizedPlaylists,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_playlists.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.playlist_play, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No playlists found'),
            Text('Try updating your music preferences'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _playlists.length,
      itemBuilder: (context, index) {
        final playlist = _playlists[index];
        return PlaylistCard(
          playlist: playlist,
          onTap: () => _onPlaylistTapped(playlist),
          onLike: () => _onPlaylistLiked(playlist.id!),
        );
      },
    );
  }

  void _onPlaylistTapped(Playlist playlist) {
    // Navigate to playlist detail page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaylistDetailPage(playlist: playlist),
      ),
    );
  }
}

class PlaylistDetailPage extends StatelessWidget {
  final Playlist playlist;

  const PlaylistDetailPage({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.name ?? 'Playlist Details'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (playlist.images?.isNotEmpty == true)
              flutter.Image.network(
                playlist.images!.first.url!,
                width: 200,
                height: 200,
                fit: flutter.BoxFit.cover,
              ),
            const SizedBox(height: 16),
            Text(
              playlist.name ?? 'Unknown Playlist',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              playlist.description ?? 'No description available',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Custom playlist card widget
class PlaylistCard extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback onTap;
  final VoidCallback onLike;

  const PlaylistCard({
    super.key,
    required this.playlist,
    required this.onTap,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Playlist image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: playlist.images?.isNotEmpty == true
                    ? flutter.Image.network(
                        playlist.images!.first.url!,
                        width: 60,
                        height: 60,
                        fit: flutter.BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildPlaceholderImage(),
                      )
                    : _buildPlaceholderImage(),
              ),
              const SizedBox(width: 12),

              // Playlist info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name ?? 'Unknown Playlist',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (playlist.description?.isNotEmpty == true)
                      Text(
                        playlist.description!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.music_note, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          '${playlist.tracks?.total ?? 0} tracks',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                        ),
                        if (playlist.followers?.total != null) ...[
                          const SizedBox(width: 12),
                          const Icon(Icons.people, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            _formatFollowerCount(playlist.followers!.total!),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Like button
              IconButton(
                onPressed: onLike,
                icon: const Icon(Icons.favorite_border),
                color: Colors.red,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.music_note,
        color: Colors.grey[600],
        size: 30,
      ),
    );
  }

  String _formatFollowerCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
  }
}

// Example of how to initialize user preferences
UserPreferences createExampleUserPreferences() {
  return UserPreferences(
    favoriteGenres: ['metal', 'jazz', 'rock'],
    favoriteArtists: ['Metallica', 'Miles Davis', 'Led Zeppelin'],
    dislikedGenres: ['country', 'pop'],
    genreWeights: {
      'metal': 0.9,
      'jazz': 0.8,
      'rock': 0.85,
    },
    recentlyPlayed: [],
    savedTracks: [],
  );
}
