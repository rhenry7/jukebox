import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/GIFs/gifs.dart';
import 'package:flutter_test_project/models/user_playlist.dart';
import 'package:flutter_test_project/providers/auth_provider.dart';
import 'package:flutter_test_project/providers/user_playlist_provider.dart';
import 'package:flutter_test_project/ui/screens/playlists/create_playlist_screen.dart';
import 'package:flutter_test_project/ui/screens/playlists/playlist_detail_screen.dart';
import 'package:flutter_test_project/utils/cached_image.dart';

/// Main playlists screen - shows user's playlists or "add playlist" button
class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);

    if (userId == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_off, size: 80, color: Colors.grey),
                SizedBox(height: 24),
                Text(
                  'Sign In Required',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Sign in to create and manage your playlists!',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final playlistsAsync = ref.watch(userPlaylistsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: playlistsAsync.when(
        data: (playlists) {
          if (playlists.isEmpty) {
            return Stack(
              children: [
                const Center(
                  child: Text(
                    'No playlists yet.\nTap + to create one!',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 16,
                  child: _AddButton(),
                ),
              ],
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(userPlaylistsProvider);
              await Future.delayed(const Duration(milliseconds: 500));
            },
            color: Colors.red[600],
            child: ListView.builder(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 32,
              ),
              itemCount: playlists.length + 1, // +1 for the header row
              itemBuilder: (context, index) {
                if (index == 0) {
                  // Header row with + button
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _AddButton(),
                    ),
                  );
                }
                return _PlaylistSection(playlist: playlists[index - 1]);
              },
            ),
          );
        },
        loading: () => const DiscoBallLoading(),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Error loading playlists',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(userPlaylistsProvider);
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

/// Small circular "+" button that navigates to CreatePlaylistScreen
class _AddButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CreatePlaylistScreen(),
          ),
        );
      },
      child: Container(
        width: 40,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[800],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 12),
      ),
    );
  }
}

/// A single playlist section: title + row of 4 album art squares
class _PlaylistSection extends StatelessWidget {
  final UserPlaylist playlist;

  const _PlaylistSection({required this.playlist});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  PlaylistDetailScreen(playlistId: playlist.id),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              playlist.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(4, (i) {
                      final track = i < playlist.tracks.length
                          ? playlist.tracks[i]
                          : null;
                      final imageUrl = track?.imageUrl;

                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: i < 3 ? 8 : 0),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: imageUrl != null
                                  ? AppCachedImage(
                                      imageUrl: imageUrl,
                                      fit: BoxFit.cover,
                                    )
                                  : ColoredBox(
                                      color:
                                          Colors.white.withValues(alpha: 0.05),
                                      child: const Icon(
                                        Icons.music_note,
                                        color: Colors.white24,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  if (playlist.description != null &&
                      playlist.description!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      playlist.description!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
