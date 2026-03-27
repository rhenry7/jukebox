import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/GIFs/gifs.dart';
import 'package:flutter_test_project/models/user_playlist.dart';
import 'package:flutter_test_project/providers/auth_provider.dart';
import 'package:flutter_test_project/providers/friends_provider.dart';
import 'package:flutter_test_project/providers/user_playlist_provider.dart';
import 'package:flutter_test_project/services/playlist_likes_service.dart';
import 'package:flutter_test_project/ui/screens/playlists/create_playlist_screen.dart';
import 'package:flutter_test_project/ui/screens/playlists/playlist_detail_screen.dart';
import 'package:flutter_test_project/utils/cached_image.dart';

/// Main playlists screen — tabbed layout with Your Playlists / Community / Friends
class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  static const Duration _headerTweenDuration = Duration(milliseconds: 280);
  static const double _scrollToggleThreshold = 14.0;
  static const List<String> _genreOptions = <String>[
    'All',
    'Chill',
    'Rap',
    'Rock',
    'Electronic',
    'Classy',
    'Reggae',
    'Soul Funk',
    'Jazz',
    'Acoustic',
  ];

  bool _isTabBarVisible = true;
  final Set<String> _selectedGenres = <String>{};
  double _accumulatedScrollDelta = 0.0;
  double? _lastScrollPixels;

  Widget _buildPillTab(String label) {
    return Tab(
      child: SizedBox(
        height: 42,
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBarHeader() {
    return Container(
      padding: const EdgeInsets.only(
        left: 14.0,
        right: 14.0,
        top: 8.0,
        bottom: 16.0,
      ),
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 18,
              spreadRadius: 1,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: TabBar(
            labelColor: Colors.black,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.92),
            isScrollable: false,
            tabAlignment: TabAlignment.fill,
            splashFactory: NoSplash.splashFactory,
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: Colors.grey.shade300,
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelPadding: EdgeInsets.zero,
            tabs: [
              _buildPillTab('Your Playlists'),
              _buildPillTab('Community'),
              _buildPillTab('Friends'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenreFilterRow() {
    return Container(
      padding: const EdgeInsets.only(
        left: 14.0,
        right: 14.0,
        bottom: 12.0,
      ),
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _genreOptions.map((genre) {
            final key = genre.toLowerCase();
            final selected = key == 'all'
                ? _selectedGenres.isEmpty
                : _selectedGenres.contains(key);

            return Padding(
              padding: const EdgeInsets.only(right: 10.0),
              child: FilterChip(
                label: Text(
                  genre,
                  style: TextStyle(
                    color: selected ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                selected: selected,
                onSelected: (_) => _toggleGenreFilter(genre),
                showCheckmark: false,
                backgroundColor: Colors.white10,
                selectedColor: Colors.grey.shade300,
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 0.8,
                ),
                shape: const StadiumBorder(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _toggleGenreFilter(String genre) {
    final key = genre.toLowerCase();
    setState(() {
      if (key == 'all') {
        _selectedGenres.clear();
        return;
      }

      if (_selectedGenres.contains(key)) {
        _selectedGenres.remove(key);
      } else {
        _selectedGenres.add(key);
      }
    });
  }

  void _setBarsVisible(bool visible) {
    if (_isTabBarVisible == visible) return;
    setState(() {
      _isTabBarVisible = visible;
    });
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;

    if (notification is ScrollStartNotification) {
      _lastScrollPixels = notification.metrics.pixels;
      _accumulatedScrollDelta = 0.0;
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      final currentPixels = notification.metrics.pixels;
      final lastPixels = _lastScrollPixels;
      _lastScrollPixels = currentPixels;
      if (lastPixels == null) return false;

      final delta = currentPixels - lastPixels;
      if (delta.abs() < 0.1) return false;

      final sameDirection = _accumulatedScrollDelta == 0.0 ||
          (_accumulatedScrollDelta.isNegative == delta.isNegative);
      _accumulatedScrollDelta =
          sameDirection ? (_accumulatedScrollDelta + delta) : delta;

      if (_accumulatedScrollDelta.abs() >= _scrollToggleThreshold) {
        if (_accumulatedScrollDelta > 0) {
          _setBarsVisible(false);
        } else {
          _setBarsVisible(true);
        }
        _accumulatedScrollDelta = 0.0;
      }
      return false;
    }

    if (notification is UserScrollNotification &&
        notification.metrics.extentAfter <= 1.0 &&
        notification.direction == ScrollDirection.idle) {
      _accumulatedScrollDelta = 0.0;
      _setBarsVisible(true);
      return false;
    }

    if (notification is ScrollEndNotification) {
      _accumulatedScrollDelta = 0.0;
      _lastScrollPixels = null;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          children: [
            ClipRect(
              child: TweenAnimationBuilder<double>(
                duration: _headerTweenDuration,
                curve: _isTabBarVisible
                    ? Curves.easeOutCubic
                    : Curves.easeInCubic,
                tween: Tween<double>(end: _isTabBarVisible ? 1.0 : 0.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTabBarHeader(),
                    _buildGenreFilterRow(),
                  ],
                ),
                builder: (context, value, child) {
                  final visibility = value.clamp(0.0, 1.0);
                  return Align(
                    alignment: Alignment.topCenter,
                    heightFactor: visibility == 0 ? 0.0001 : visibility,
                    child: Opacity(
                      opacity: visibility,
                      child: Transform.translate(
                        offset: Offset(0, -(1 - visibility) * 10),
                        child: child,
                      ),
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScrollNotification,
                child: TabBarView(
                  children: [
                    _YourPlaylistsTab(
                      selectedGenres: _selectedGenres,
                    ),
                    _CommunityPlaylistsTab(
                      selectedGenres: _selectedGenres,
                    ),
                    _FriendsPlaylistsTab(
                      selectedGenres: _selectedGenres,
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

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

List<UserPlaylist> _filterPlaylistsByTags(
    List<UserPlaylist> playlists, Set<String> selectedGenres) {
  if (selectedGenres.isEmpty) return playlists;
  return playlists.where((p) {
    final tags = p.tags.map((t) => t.toLowerCase().trim()).toSet();
    return selectedGenres
        .any((g) => tags.any((t) => t.contains(g) || g.contains(t)));
  }).toList();
}

// ---------------------------------------------------------------------------
// Your Playlists tab
// ---------------------------------------------------------------------------

class _YourPlaylistsTab extends ConsumerWidget {
  final Set<String> selectedGenres;

  const _YourPlaylistsTab({required this.selectedGenres});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);

    if (userId == null) {
      return const Center(
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
      );
    }

    final playlistsAsync = ref.watch(userPlaylistsProvider);
    final likedPlaylists = ref.watch(likedPlaylistsProvider).value ?? [];

    return playlistsAsync.when(
      data: (playlists) {
        final filtered = _filterPlaylistsByTags(playlists, selectedGenres);
        final filteredLiked = _filterPlaylistsByTags(likedPlaylists, selectedGenres);

        final hasOwn = filtered.isNotEmpty;
        final hasLiked = filteredLiked.isNotEmpty;

        if (!hasOwn && !hasLiked) {
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

        // Layout:
        // 0          : _AddButton
        // 1..own     : own playlists
        // own+1      : "Saved Playlists" header  (only if hasLiked)
        // own+2..end : liked playlists
        final likedHeaderIndex = filtered.length + 1;
        final totalCount = 1 +
            filtered.length +
            (hasLiked ? 1 + filteredLiked.length : 0);

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(userPlaylistsProvider);
            ref.invalidate(likedPlaylistsProvider);
            await Future.delayed(const Duration(milliseconds: 500));
          },
          color: Colors.red[600],
          child: ListView.builder(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.paddingOf(context).bottom + 90,
            ),
            itemCount: totalCount,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _AddButton(),
                  ),
                );
              }
              if (index <= filtered.length) {
                return _PlaylistSection(playlist: filtered[index - 1]);
              }
              if (hasLiked) {
                if (index == likedHeaderIndex) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16, top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.favorite,
                            color: Colors.red, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Saved Playlists',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final likedIndex = index - likedHeaderIndex - 1;
                if (likedIndex >= 0 && likedIndex < filteredLiked.length) {
                  return _PlaylistSection(playlist: filteredLiked[likedIndex]);
                }
              }
              return const SizedBox.shrink();
            },
          ),
        );
      },
      loading: () => const DiscoBallLoading(),
      error: (error, stack) => _ErrorView(
        error: error,
        onRetry: () => ref.invalidate(userPlaylistsProvider),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Community tab
// ---------------------------------------------------------------------------

class _CommunityPlaylistsTab extends ConsumerWidget {
  final Set<String> selectedGenres;

  const _CommunityPlaylistsTab({required this.selectedGenres});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(communityPlaylistsProvider);

    return playlistsAsync.when(
      data: (playlists) {
        final filtered = _filterPlaylistsByTags(playlists, selectedGenres);

        if (filtered.isEmpty) {
          return const Center(
            child: Text(
              'No community playlists yet.',
              style: TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(communityPlaylistsProvider);
            await Future.delayed(const Duration(milliseconds: 500));
          },
          color: Colors.red[600],
          child: ListView.builder(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.paddingOf(context).bottom + 90,
            ),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              return _PlaylistSection(playlist: filtered[index]);
            },
          ),
        );
      },
      loading: () => const DiscoBallLoading(),
      error: (error, stack) => _ErrorView(
        error: error,
        onRetry: () => ref.invalidate(communityPlaylistsProvider),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Friends tab
// ---------------------------------------------------------------------------

class _FriendsPlaylistsTab extends ConsumerWidget {
  final Set<String> selectedGenres;

  const _FriendsPlaylistsTab({required this.selectedGenres});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendIds = ref.watch(friendIdsProvider).value ?? [];
    final playlistsAsync = ref.watch(friendsPlaylistsProvider);

    // No friends at all
    if (friendIds.isEmpty) {
      return const Center(
        child: Text(
          'Add friends to see their playlists!',
          style: TextStyle(color: Colors.white70, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }

    return playlistsAsync.when(
      data: (playlists) {
        final filtered = _filterPlaylistsByTags(playlists, selectedGenres);

        if (filtered.isEmpty) {
          return const Center(
            child: Text(
              "Your friends haven't created any playlists yet.",
              style: TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(friendsPlaylistsProvider);
            await Future.delayed(const Duration(milliseconds: 500));
          },
          color: Colors.red[600],
          child: ListView.builder(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.paddingOf(context).bottom + 90,
            ),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              return _PlaylistSection(playlist: filtered[index]);
            },
          ),
        );
      },
      loading: () => const DiscoBallLoading(),
      error: (error, stack) => _ErrorView(
        error: error,
        onRetry: () => ref.invalidate(friendsPlaylistsProvider),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

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

/// A single playlist card: title row, album art, tags, description, heart button.
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
            // ── Title + "By [creator]" ──────────────────────────────────
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
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // ── Card ───────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Album art row
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
                  // Tags row
                  if (playlist.tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: playlist.tags
                          .map(
                            (tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                border:
                                    Border.all(color: Colors.white30, width: 1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                tag,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  // Description
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
                  // Heart button — bottom right, only for non-owners
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
            color: isLiked
                ? Colors.red.withValues(alpha: 0.6)
                : Colors.white30,
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

/// Reusable error view with retry button
class _ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
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
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
