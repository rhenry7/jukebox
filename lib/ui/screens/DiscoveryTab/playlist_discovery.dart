import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:flutter_test_project/providers/playlist_provider.dart';
import 'package:flutter_test_project/services/playlist_generation_service.dart';
import 'package:flutter_test_project/providers/auth_provider.dart';

/// Playlist Discovery Screen - Shows genre-based playlist
class PlaylistDiscoveryScreen extends ConsumerWidget {
  const PlaylistDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);

    if (userId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_off, size: 80, color: Colors.grey),
              const Gap(24),
              const Text(
                'Sign In Required',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Gap(16),
              const Text(
                'Sign in to discover personalized playlists based on your music preferences!',
                style: TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final playlistRequest = PlaylistRequest(
      playlistType: 'genre',
      trackCount: 50, // Show more tracks
    );
    final playlistAsync = ref.watch(playlistProvider(playlistRequest));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Playlists',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(playlistProvider(playlistRequest));
            },
          ),
        ],
      ),
      body: playlistAsync.when(
        data: (tracks) {
          if (tracks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.music_off, size: 64, color: Colors.grey),
                  const Gap(16),
                  const Text(
                    'No tracks found',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const Gap(8),
                  const Text(
                    'Try updating your music preferences',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(playlistProvider(playlistRequest));
              await Future.delayed(const Duration(milliseconds: 500));
            },
            color: Colors.red[600],
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.65, // Adjusted to prevent overflow
              ),
              itemCount: tracks.length,
              itemBuilder: (context, index) {
                return _PlaylistTrackCard(track: tracks[index]);
              },
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.red),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const Gap(16),
              const Text(
                'Error loading playlist',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const Gap(8),
              Text(
                error.toString(),
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const Gap(16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(playlistProvider(playlistRequest));
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card for context-based playlists
class _ContextPlaylistCard extends ConsumerWidget {
  final String context;
  final IconData icon;
  final String title;
  final Color color;

  const _ContextPlaylistCard({
    required this.context,
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlaylistDetailScreen(
              playlistRequest: PlaylistRequest(
                context: this.context,
                trackCount: 20,
              ),
              title: title,
            ),
          ),
        );
      },
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const Gap(12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card for playlist types
class _TypePlaylistCard extends ConsumerWidget {
  final String type;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _TypePlaylistCard({
    required this.type,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get a preview image from the playlist (first track)
    final playlistAsync = ref.watch(playlistProvider(PlaylistRequest(
      playlistType: type,
      trackCount: 1, // Just get one track for preview
    )));

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlaylistDetailScreen(
              playlistRequest: PlaylistRequest(
                playlistType: type,
                trackCount: 20,
              ),
              title: title,
            ),
          ),
        );
      },
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            // Background image if available
            playlistAsync.when(
              data: (tracks) {
                if (tracks.isNotEmpty && tracks.first.imageUrl != null) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      tracks.first.imageUrl!,
                      width: 160,
                      height: 180,
                      fit: BoxFit.cover,
                      opacity: const AlwaysStoppedAnimation(0.3),
                      errorBuilder: (context, error, stackTrace) {
                        return Container();
                      },
                    ),
                  );
                }
                return Container();
              },
              loading: () => Container(),
              error: (_, __) => Container(),
            ),
            // Content overlay
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 40, color: color),
                  const Gap(12),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Gap(4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Detail screen showing the generated playlist
class PlaylistDetailScreen extends ConsumerWidget {
  final PlaylistRequest playlistRequest;
  final String title;

  const PlaylistDetailScreen({
    super.key,
    required this.playlistRequest,
    required this.title,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistAsync = ref.watch(playlistProvider(playlistRequest));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(playlistProvider(playlistRequest));
            },
          ),
        ],
      ),
      body: playlistAsync.when(
        data: (tracks) {
          if (tracks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.music_off, size: 64, color: Colors.grey),
                  const Gap(16),
                  const Text(
                    'No tracks found',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const Gap(8),
                  const Text(
                    'Try updating your music preferences',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tracks.length,
            itemBuilder: (context, index) {
              final track = tracks[index];
              return _PlaylistTrackCard(track: track);
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.red),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const Gap(16),
              Text(
                'Error loading playlist',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              const Gap(8),
              Text(
                error.toString(),
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const Gap(16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(playlistProvider(playlistRequest));
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Individual track card in playlist - Column layout with image on top
class _PlaylistTrackCard extends StatelessWidget {
  final PlaylistTrack track;

  const _PlaylistTrackCard({required this.track});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Album cover art at the top
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            child: track.imageUrl != null && track.imageUrl!.isNotEmpty
                ? AspectRatio(
                    aspectRatio: 1.0,
                    child: Image.network(
                      track.imageUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildPlaceholder();
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.grey[900],
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 2,
                              color: Colors.red,
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : _buildPlaceholder(),
          ),
          // Track info below the image
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Text(
                    track.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Gap(4),
                  // Artist
                  Text(
                    track.artist,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Gap(6),
                  // Tags
                  if (track.tags.isNotEmpty)
                    Flexible(
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: track.tags.take(2).map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 9,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  const Gap(6),
                  // Date and rating info
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (track.releaseDate != null) ...[
                        Icon(
                          Icons.calendar_today,
                          size: 11,
                          color: Colors.white70,
                        ),
                        const Gap(3),
                        Text(
                          track.releaseDate!.year.toString(),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      ],
                      if (track.rating != null && track.releaseDate != null)
                        const Gap(8),
                      if (track.rating != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 12,
                            ),
                            const Gap(3),
                            Text(
                              track.rating!.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.2),
        ),
        child: const Icon(
          Icons.music_note,
          color: Colors.red,
          size: 50,
        ),
      ),
    );
  }
}
