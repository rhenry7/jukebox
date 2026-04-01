import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/GIFs/gifs.dart';
import 'package:flutter_test_project/models/user_playlist.dart';
import 'package:flutter_test_project/providers/auth_provider.dart';
import 'package:flutter_test_project/providers/friends_provider.dart';
import 'package:flutter_test_project/providers/user_playlist_provider.dart';
import 'package:flutter_test_project/services/playlist_likes_service.dart';
import 'package:flutter_test_project/ui/screens/playlists/create_playlist_screen.dart';
import 'package:flutter_test_project/ui/screens/playlists/playlist_detail_screen.dart';
import 'package:flutter_test_project/providers/crate_comments_provider.dart';
import 'package:flutter_test_project/utils/cached_image.dart';
import 'package:ionicons/ionicons.dart';

// ---------------------------------------------------------------------------
// Main Crates screen — three horizontal-scroll rows
// ---------------------------------------------------------------------------

class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    final communityAsync = ref.watch(communityPlaylistsProvider);
    final friendIds = ref.watch(friendIdsProvider).value ?? [];
    final friendsAsync = ref.watch(friendsPlaylistsProvider);
    final yourAsync = ref.watch(userPlaylistsProvider);

    return RefreshIndicator(
      color: Colors.red[600],
      onRefresh: () async {
        ref.invalidate(communityPlaylistsProvider);
        ref.invalidate(friendsPlaylistsProvider);
        ref.invalidate(userPlaylistsProvider);
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: ListView(
        padding: EdgeInsets.only(
          top: 12,
          bottom: MediaQuery.paddingOf(context).bottom + 100,
        ),
        children: [
          // ── Popular Crates ──────────────────────────────────────────────
          _SectionHeader(
            title: 'Popular Crates',
            subtitle: 'Curated by the global archive community.',
            onViewAll: () => _pushAllCrates(
              context,
              title: 'Popular Crates',
              asyncPlaylists: communityAsync,
            ),
          ),
          _HorizontalCrateRow(
            asyncPlaylists: communityAsync,
            emptyMessage: 'No community crates yet.',
          ),
          const SizedBox(height: 32),

          // ── Friends' Crates ─────────────────────────────────────────────
          _SectionHeader(
            title: "Friend's Crates",
            subtitle: 'What your network is listening to right now.',
            onViewAll: friendIds.isEmpty
                ? null
                : () => _pushAllCrates(
                      context,
                      title: "Friends' Crates",
                      asyncPlaylists: friendsAsync,
                    ),
          ),
          if (friendIds.isEmpty)
            _EmptyRow(message: 'Add friends to see their crates!')
          else
            _HorizontalCrateRow(
              asyncPlaylists: friendsAsync,
              emptyMessage: "Your friends haven't created any crates yet.",
            ),
          const SizedBox(height: 32),

          // ── Your Crates ─────────────────────────────────────────────────
          _SectionHeader(
            title: 'Your Crates',
            subtitle: 'Your personal collection.',
            trailing: userId != null
                ? GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CreatePlaylistScreen()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text('New',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  )
                : null,
          ),
          if (userId == null)
            _EmptyRow(message: 'Sign in to create your own crates!')
          else
            _HorizontalCrateRow(
              asyncPlaylists: yourAsync,
              emptyMessage: 'No crates yet — tap New to create one!',
            ),
        ],
      ),
    );
  }

  void _pushAllCrates(
    BuildContext context, {
    required String title,
    required AsyncValue<List<UserPlaylist>> asyncPlaylists,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AllCratesScreen(
          title: title,
          asyncPlaylists: asyncPlaylists,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onViewAll;
  final Widget? trailing;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.onViewAll,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
              if (onViewAll != null && trailing == null)
                GestureDetector(
                  onTap: onViewAll,
                  child: const Text(
                    'VIEW ALL',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Horizontal crate row
// ---------------------------------------------------------------------------

class _HorizontalCrateRow extends ConsumerWidget {
  final AsyncValue<List<UserPlaylist>> asyncPlaylists;
  final String emptyMessage;

  const _HorizontalCrateRow({
    required this.asyncPlaylists,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return asyncPlaylists.when(
      loading: () => const SizedBox(
        height: 280,
        child: Center(child: DiscoBallLoading()),
      ),
      error: (e, _) => SizedBox(
        height: 100,
        child: Center(
          child: Text(
            'No Crates to share!',
            style: TextStyle(color: Colors.white.withOpacity(0.4)),
          ),
        ),
      ),
      data: (playlists) {
        if (playlists.isEmpty) {
          return _EmptyRow(message: emptyMessage);
        }
        return SizedBox(
          height: 330,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: playlists.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) =>
                _CrateCard(playlist: playlists[index]),
          ),
        );
      },
    );
  }
}

class _EmptyRow extends StatelessWidget {
  final String message;
  const _EmptyRow({required this.message});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: Center(
        child: Text(
          message,
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Crate card — portrait, fixed width, for horizontal scroll
// ---------------------------------------------------------------------------

class _CrateCard extends ConsumerWidget {
  final UserPlaylist playlist;
  static const double _cardWidth = 210;

  const _CrateCard({required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final isOwner = currentUserId == playlist.userId;
    final isLiked =
        ref.watch(playlistLikeStatusProvider(playlist.id)).value ?? false;
    final creatorName =
        ref.watch(userDisplayNameProvider(playlist.userId)).value ?? '';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => PlaylistDetailScreen(playlistId: playlist.id)),
      ),
      child: Container(
        width: _cardWidth,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 2×2 album art grid ────────────────────────────────────
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: SizedBox(
                width: _cardWidth,
                height: 160,
                child: _AlbumGrid(tracks: playlist.tracks),
              ),
            ),
            // ── Info ──────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // ── Top content (clamped) ────────────────────────
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          playlist.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (creatorName.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'By $creatorName',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.45),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        // Description — 1 line max with ellipsis
                        if (playlist.description != null &&
                            playlist.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            playlist.description!,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        // Tags
                        if (playlist.tags.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 5,
                            runSpacing: 4,
                            children: playlist.tags.take(3).map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Colors.white30, width: 1),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 11),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                    // ── Bottom row: four items evenly spread ─────────
                    Row(
                      //crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Track count
                        Row(
                          //mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.music_note_outlined,
                                size: 13, color: Colors.white38),
                            const SizedBox(width: 3),
                            Text(
                              '${playlist.tracks.length}',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 11),
                            ),
                          ],
                        ),
                        // Comment count (live from Firestore)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Ionicons.chatbubble_outline,
                                size: 13, color: Colors.white38),
                            const SizedBox(width: 3),
                            Text(
                              '${ref.watch(crateCommentsProvider(playlist.id)).value?.length ?? 0}',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 11),
                            ),
                          ],
                        ),
                        // Heart
                        GestureDetector(
                          onTap: currentUserId != null
                              ? () async {
                                  if (isLiked) {
                                    await PlaylistLikesService.unlikePlaylist(
                                        playlist.id, currentUserId);
                                  } else {
                                    await PlaylistLikesService.likePlaylist(
                                        playlist.id, currentUserId);
                                  }
                                }
                              : null,
                          child: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            size: 18,
                            color: isLiked ? Colors.red : Colors.white38,
                          ),
                        ),
                        // Share
                        GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Share "${playlist.name}" — coming soon'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: const Icon(Icons.ios_share,
                              size: 18, color: Colors.white38),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 2×2 grid of album art images
class _AlbumGrid extends StatelessWidget {
  final List<PlaylistTrack> tracks;
  const _AlbumGrid({required this.tracks});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _imageRow(0)),
        Expanded(child: _imageRow(1)),
      ],
    );
  }

  Widget _imageRow(int rowIndex) {
    return Row(
      children: [
        Expanded(child: _cell(rowIndex * 2)),
        Expanded(child: _cell(rowIndex * 2 + 1)),
      ],
    );
  }

  Widget _cell(int index) {
    final imageUrl = index < tracks.length ? tracks[index].imageUrl : null;
    if (imageUrl != null) {
      return AppCachedImage(imageUrl: imageUrl, fit: BoxFit.cover);
    }
    return const ColoredBox(
      color: Color(0xFF1A1A1A),
      child: Center(
        child: Icon(Icons.music_note_outlined, color: Colors.white12, size: 24),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// "View All" full-list screen
// ---------------------------------------------------------------------------

class _AllCratesScreen extends StatelessWidget {
  final String title;
  final AsyncValue<List<UserPlaylist>> asyncPlaylists;

  const _AllCratesScreen({
    required this.title,
    required this.asyncPlaylists,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: asyncPlaylists.when(
        loading: () => const Center(child: DiscoBallLoading()),
        error: (e, _) => Center(
          child: Text('Failed to load.',
              style: TextStyle(color: Colors.white.withOpacity(0.5))),
        ),
        data: (playlists) {
          if (playlists.isEmpty) {
            return Center(
              child: Text('No crates yet.',
                  style: TextStyle(color: Colors.white.withOpacity(0.4))),
            );
          }
          return ListView.builder(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.paddingOf(context).bottom + 90,
            ),
            itemCount: playlists.length,
            itemBuilder: (context, index) =>
                _PlaylistSection(playlist: playlists[index]),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Full-size playlist card (used in "View All" screen)
// ---------------------------------------------------------------------------

class _PlaylistSection extends ConsumerWidget {
  final UserPlaylist playlist;
  const _PlaylistSection({required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final isOwner = currentUserId == playlist.userId;
    final isLiked =
        ref.watch(playlistLikeStatusProvider(playlist.id)).value ?? false;
    final creatorName =
        ref.watch(userDisplayNameProvider(playlist.userId)).value ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => PlaylistDetailScreen(playlistId: playlist.id)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: playlist.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (creatorName.isNotEmpty)
                    TextSpan(
                      text: '  By $creatorName',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                ],
              ),
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
                                      imageUrl: imageUrl, fit: BoxFit.cover)
                                  : ColoredBox(
                                      color: Colors.white.withOpacity(0.05),
                                      child: const Icon(Icons.music_note,
                                          color: Colors.white24),
                                    ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  if (playlist.tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: playlist.tags
                          .map((tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Colors.white30, width: 1),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(tag,
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                              ))
                          .toList(),
                    ),
                  ],
                  if (playlist.description != null &&
                      playlist.description!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      playlist.description!,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 14),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (!isOwner && currentUserId != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _HeartButton(
                        isLiked: isLiked,
                        onTap: () async {
                          if (isLiked) {
                            await PlaylistLikesService.unlikePlaylist(
                                playlist.id, currentUserId);
                          } else {
                            await PlaylistLikesService.likePlaylist(
                                playlist.id, currentUserId);
                          }
                        },
                      ),
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

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class _HeartButton extends StatelessWidget {
  final bool isLiked;
  final VoidCallback onTap;
  const _HeartButton({required this.isLiked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(
            color: isLiked ? Colors.red.withOpacity(0.6) : Colors.white30,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(
          isLiked ? Icons.favorite : Icons.favorite_border,
          color: isLiked ? Colors.red : Colors.white70,
          size: 16,
        ),
      ),
    );
  }
}
