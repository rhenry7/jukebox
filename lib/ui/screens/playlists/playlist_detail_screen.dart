import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/Api/api_key.dart';
import 'package:flutter_test_project/GIFs/gifs.dart';
import 'package:flutter_test_project/models/crate_comment.dart';
import 'package:flutter_test_project/models/user_playlist.dart';
import 'package:flutter_test_project/providers/auth_provider.dart';
import 'package:flutter_test_project/providers/crate_comments_provider.dart';
import 'package:flutter_test_project/providers/user_playlist_provider.dart';
import 'package:flutter_test_project/services/crate_comment_service.dart';
import 'package:flutter_test_project/services/user_playlist_service.dart';
import 'package:flutter_test_project/ui/screens/Profile/ProfileSignIn.dart';
import 'package:flutter_test_project/ui/screens/Profile/ProfileSignUpWidget.dart';
import 'package:flutter_test_project/ui/screens/playlists/add_songs_screen.dart';
import 'package:flutter_test_project/utils/cached_image.dart';
import 'package:flutter_test_project/utils/helpers.dart';
import 'package:spotify/spotify.dart' as spotify;

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  final String playlistId;
  const PlaylistDetailScreen({super.key, required this.playlistId});

  @override
  ConsumerState<PlaylistDetailScreen> createState() =>
      _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<spotify.Track> _searchResults = [];
  bool _isSearching = false;
  bool _showSearchResults = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    if (_searchController.text.trim().length >= 2) {
      _searchDebounce = Timer(const Duration(milliseconds: 500), () {
        _performSearch(_searchController.text.trim());
      });
      setState(() => _showSearchResults = true);
    } else {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
    }
  }

  Future<void> _performSearch(String query) async {
    if (_isSearching) return;
    setState(() => _isSearching = true);
    try {
      final credentials =
          spotify.SpotifyApiCredentials(clientId, clientSecret);
      final spotifyApi = spotify.SpotifyApi(credentials);
      final searchResults = await spotifyApi.search
          .get(query, types: [spotify.SearchType.track]).first(20);
      final tracks = <spotify.Track>[];
      for (final page in searchResults) {
        if (page.items != null) {
          for (final item in page.items!) {
            if (item is spotify.Track) tracks.add(item);
          }
        }
      }
      if (mounted) setState(() { _searchResults = tracks; _isSearching = false; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error searching: $e')));
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _addTrack(spotify.Track track, String playlistId) async {
    try {
      final playlistTrack = PlaylistTrack(
        trackId: track.id ?? '',
        title: track.name ?? 'Unknown',
        artist:
            track.artists?.map((a) => a.name ?? '').join(', ') ?? 'Unknown',
        albumTitle: track.album?.name,
        imageUrl: track.album?.images?.isNotEmpty == true
            ? track.album!.images!.first.url
            : null,
        durationMs: track.durationMs,
        spotifyUri: track.uri,
        addedAt: DateTime.now(),
      );
      await UserPlaylistService.addTrackToPlaylist(
          playlistId: playlistId, track: playlistTrack);
      _searchController.clear();
      setState(() { _showSearchResults = false; _searchResults = []; });
      ref.invalidate(singlePlaylistProvider(playlistId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Added "${track.name}"'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _removeTrack(
      PlaylistTrack track, String playlistId, BuildContext ctx) async {
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Remove Track',
            style: TextStyle(color: Colors.white)),
        content: Text('Remove "${track.title}" from this crate?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Remove')),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await UserPlaylistService.removeTrackFromPlaylist(
            playlistId: playlistId, trackId: track.trackId);
        if (mounted) ref.invalidate(singlePlaylistProvider(playlistId));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  /// Total duration of all tracks in minutes
  int _totalMinutes(List<PlaylistTrack> tracks) {
    final totalMs =
        tracks.fold<int>(0, (sum, t) => sum + (t.durationMs ?? 0));
    return (totalMs / 60000).round();
  }

  @override
  Widget build(BuildContext context) {
    final playlistAsync =
        ref.watch(singlePlaylistProvider(widget.playlistId));

    return Scaffold(
      backgroundColor: Colors.black,
      body: playlistAsync.when(
        loading: () => const DiscoBallLoading(),
        error: (e, _) => Center(
          child: Text('Error loading crate',
              style: TextStyle(color: Colors.white.withOpacity(0.6))),
        ),
        data: (playlist) {
          if (playlist == null) {
            return const Center(
              child: Text('Crate not found',
                  style: TextStyle(color: Colors.white70)),
            );
          }
          final currentUserId = ref.watch(currentUserIdProvider);
          final isOwner =
              currentUserId != null && currentUserId == playlist.userId;
          final creatorName =
              ref.watch(userDisplayNameProvider(playlist.userId)).value ?? '';
          final heroImageUrl = playlist.coverImageUrl ??
              (playlist.tracks.isNotEmpty
                  ? playlist.tracks.first.imageUrl
                  : null);

          return RefreshIndicator(
            color: Colors.red[600],
            onRefresh: () async {
              ref.invalidate(singlePlaylistProvider(widget.playlistId));
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: CustomScrollView(
              slivers: [
                // ── Hero image ────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Stack(
                    children: [
                      heroImageUrl != null
                          ? AppCachedImage(
                              imageUrl: heroImageUrl,
                              width: double.infinity,
                              height:
                                  MediaQuery.of(context).size.height * 0.38,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: double.infinity,
                              height:
                                  MediaQuery.of(context).size.height * 0.38,
                              color: Colors.grey[900],
                              child: const Icon(Icons.music_note,
                                  color: Colors.white12, size: 80),
                            ),
                      // Gradient fade into black at bottom
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0.5, 1.0],
                              colors: [
                                Colors.transparent,
                                Colors.black,
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Back button
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 8,
                        left: 12,
                        child: _CircleButton(
                          icon: Icons.close,
                          onTap: () => Navigator.pop(context),
                        ),
                      ),
                      // Add songs (owner only)
                      if (isOwner)
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 8,
                          right: 12,
                          child: _CircleButton(
                            icon: Icons.add,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => AddSongsScreen(
                                      playlistId: widget.playlistId)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ── Header info ───────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tags (hashtag pills)
                        if (playlist.tags.isNotEmpty) ...[
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: playlist.tags.map((tag) {
                              return Text(
                                '#${tag.toUpperCase()}',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 8),
                        ],
                        // Crate name
                        Text(
                          playlist.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                          ),
                        ),
                        // Creator
                        if (creatorName.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.grey[800],
                                  border: Border.all(
                                      color: Colors.white24, width: 1),
                                ),
                                child: const Icon(Icons.person,
                                    size: 14, color: Colors.white54),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                '@$creatorName',
                                style: const TextStyle(
                                    color: Colors.white60, fontSize: 14),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Stats row
                        Row(
                          children: [
                            _StatCell(
                                value:
                                    '${playlist.tracks.length}',
                                label: 'TRACKS'),
                            const SizedBox(width: 28),
                            _StatCell(
                                value: '${_totalMinutes(playlist.tracks)}',
                                label: 'MINS'),
                            const SizedBox(width: 28),
                            const _StatCell(value: '—', label: 'SAVES'),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Curator's note (description)
                        if (playlist.description != null &&
                            playlist.description!.isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(10),
                              border: Border(
                                left: BorderSide(
                                    color: Colors.red[700]!, width: 3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "CURATOR'S NOTE",
                                  style: TextStyle(
                                    color: Colors.red[400],
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '"${playlist.description}"',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Tracklist header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'TRACKLIST',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                            if (isOwner)
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => AddSongsScreen(
                                          playlistId: widget.playlistId)),
                                ),
                                child: const Icon(Icons.add,
                                    color: Colors.white38, size: 18),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Owner search bar
                        if (isOwner) ...[
                          TextField(
                            controller: _searchController,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Search to add tracks...',
                              hintStyle:
                                  const TextStyle(color: Colors.white30),
                              prefixIcon: const Icon(Icons.search,
                                  color: Colors.white38, size: 18),
                              suffixIcon: _isSearching
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white54),
                                      ),
                                    )
                                  : _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear,
                                              color: Colors.white38),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() {
                                              _showSearchResults = false;
                                              _searchResults = [];
                                            });
                                          },
                                        )
                                      : null,
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Colors.white24),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Colors.white24),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color: Colors.red[600]!, width: 1.5),
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                ),

                // ── Search results ────────────────────────────────────
                if (isOwner && _showSearchResults && _searchResults.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final track = _searchResults[index];
                          final imageUrl =
                              track.album?.images?.isNotEmpty == true
                                  ? track.album!.images!.first.url
                                  : null;
                          final already = ref
                              .read(singlePlaylistProvider(widget.playlistId))
                              .value
                              ?.tracks
                              .any((t) => t.trackId == track.id) ??
                              false;
                          return _TrackRow(
                            imageUrl: imageUrl,
                            title: track.name ?? 'Unknown',
                            artist: track.artists
                                    ?.map((a) => a.name)
                                    .join(', ') ??
                                '',
                            trailing: already
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green, size: 20)
                                : IconButton(
                                    icon: const Icon(Icons.add_circle,
                                        color: Colors.red, size: 20),
                                    onPressed: () =>
                                        _addTrack(track, widget.playlistId),
                                  ),
                          );
                        },
                        childCount: _searchResults.length,
                      ),
                    ),
                  ),

                // ── Tracks ────────────────────────────────────────────
                if (playlist.tracks.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.music_off,
                              size: 56, color: Colors.white24),
                          const SizedBox(height: 14),
                          Text(
                            isOwner
                                ? 'No tracks yet — search above to add some!'
                                : 'No tracks in this crate.',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 15),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final track = playlist.tracks[index];
                          final duration = track.durationMs != null
                              ? _formatDuration(track.durationMs!)
                              : null;
                          return _TrackRow(
                            imageUrl: track.imageUrl,
                            title: track.title,
                            artist: track.artist,
                            duration: duration,
                            trailing: isOwner
                                ? IconButton(
                                    icon: const Icon(Icons.more_vert,
                                        color: Colors.white38, size: 20),
                                    onPressed: () => _removeTrack(
                                        track, widget.playlistId, context),
                                  )
                                : null,
                          );
                        },
                        childCount: playlist.tracks.length,
                      ),
                    ),
                  ),

                // ── Community / Comments ──────────────────────────────
                SliverToBoxAdapter(
                  child: _CommentSection(
                    playlistId: widget.playlistId,
                    currentUserId: currentUserId,
                    isPlaylistOwner: isOwner,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _formatDuration(int ms) {
    final total = (ms / 1000).round();
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

// ---------------------------------------------------------------------------
// Reusable widgets
// ---------------------------------------------------------------------------

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withOpacity(0.55),
          border: Border.all(color: Colors.white24, width: 0.8),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  const _StatCell({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 10,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _TrackRow extends StatelessWidget {
  final String? imageUrl;
  final String title;
  final String artist;
  final String? duration;
  final Widget? trailing;

  const _TrackRow({
    required this.title,
    required this.artist,
    this.imageUrl,
    this.duration,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.07), width: 0.8),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: imageUrl != null
                ? AppCachedImage(
                    imageUrl: imageUrl!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 48,
                    height: 48,
                    color: Colors.white10,
                    child: const Icon(Icons.music_note,
                        color: Colors.white24, size: 22),
                  ),
          ),
          title: Text(
            title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            artist,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: duration != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(duration!,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12)),
                    if (trailing != null) trailing!,
                  ],
                )
              : trailing,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Comment section
// ---------------------------------------------------------------------------

class _CommentSection extends ConsumerStatefulWidget {
  final String playlistId;
  final String? currentUserId;
  final bool isPlaylistOwner;

  const _CommentSection({
    required this.playlistId,
    required this.currentUserId,
    required this.isPlaylistOwner,
  });

  @override
  ConsumerState<_CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends ConsumerState<_CommentSection> {
  final TextEditingController _input = TextEditingController();
  bool _posting = false;
  // tracks locally liked comment IDs (session-only; no per-user persistence needed for MVP)
  final Set<String> _likedIds = {};

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _showSignInPrompt(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Join the discussion!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Sign up or sign in to post comments and interact with crates.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfileSignUp()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF39FF6A),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF39FF6A).withOpacity(0.35),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'Sign Up',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SignInScreen()),
                  );
                },
                child: const Text(
                  'Sign In',
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _post() async {
    final text = _input.text.trim();
    if (text.isEmpty || widget.currentUserId == null) return;
    setState(() => _posting = true);

    // Fetch display name once
    final displayName = await ref
            .read(userDisplayNameProvider(widget.currentUserId!).future) ??
        'Anonymous';

    try {
      await CrateCommentService.addComment(
        playlistId: widget.playlistId,
        userId: widget.currentUserId!,
        displayName: displayName,
        text: text,
      );
      _input.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error posting: $e')));
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _delete(CrateComment comment) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Delete comment',
            style: TextStyle(color: Colors.white)),
        content: const Text('Remove this comment?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await CrateCommentService.deleteComment(
          widget.playlistId, comment.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync =
        ref.watch(crateCommentsProvider(widget.playlistId));

    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 28, 16, MediaQuery.paddingOf(context).bottom + 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section header ──────────────────────────────────────
          commentsAsync.when(
            data: (comments) => Row(
              children: [
                const Text(
                  'COMMUNITY',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red[700],
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${comments.length}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            loading: () => const Text('Discussion',
                style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2)),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 14),

          // ── Input box (signed-in users only) ───────────────
          Builder(builder: (context) {
            if (widget.currentUserId != null) {
              // Real user — show comment input
              return Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24, width: 0.8),
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _input,
                          style:
                              const TextStyle(color: Colors.white, fontSize: 14),
                          maxLines: 3,
                          minLines: 2,
                          decoration: const InputDecoration(
                            hintText: 'Join the discussion...',
                            hintStyle: TextStyle(color: Colors.white30),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.fromLTRB(14, 12, 14, 4),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              GestureDetector(
                                onTap: _posting ? null : _post,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: _posting
                                        ? Colors.grey[700]
                                        : Colors.red[700],
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  child: _posting
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white),
                                        )
                                      : const Text('Send',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              );
            } else {
              // Anonymous user — tappable prompt
              return GestureDetector(
                onTap: () => _showSignInPrompt(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12, width: 0.8),
                  ),
                  child: const Text(
                    'Sign up or Sign in to join the discussion!',
                    style: TextStyle(color: Colors.white38, fontSize: 14),
                  ),
                ),
              );
            }
          }),

          // ── Comment list ─────────────────────────────────────────
          commentsAsync.when(
            loading: () => const Center(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(
                        color: Colors.white24, strokeWidth: 2))),
            error: (_, __) => const SizedBox.shrink(),
            data: (comments) {
              if (comments.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No comments yet — be the first!',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 14),
                  ),
                );
              }
              return Column(
                children: comments.map((c) {
                  final canDelete = widget.currentUserId == c.userId ||
                      widget.isPlaylistOwner;
                  final isLiked = _likedIds.contains(c.id);
                  return _CommentTile(
                    comment: c,
                    isLiked: isLiked,
                    canDelete: canDelete,
                    onLike: () async {
                      setState(() {
                        isLiked
                            ? _likedIds.remove(c.id)
                            : _likedIds.add(c.id);
                      });
                      await CrateCommentService.toggleLike(
                          widget.playlistId, c.id, isLiked);
                    },
                    onDelete: () => _delete(c),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final CrateComment comment;
  final bool isLiked;
  final bool canDelete;
  final VoidCallback onLike;
  final VoidCallback onDelete;

  const _CommentTile({
    required this.comment,
    required this.isLiked,
    required this.canDelete,
    required this.onLike,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[800],
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: const Icon(Icons.person,
                size: 18, color: Colors.white54),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + timestamp
                Row(
                  children: [
                    Text(
                      '@${comment.displayName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '• ${formatRelativeTime(comment.createdAt)}',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                // Comment text
                Text(
                  comment.text,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.45),
                ),
                const SizedBox(height: 8),
                // Action row
                Row(
                  children: [
                    // Like
                    GestureDetector(
                      onTap: onLike,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 14,
                            color: isLiked
                                ? Colors.red
                                : Colors.white38,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${comment.likes}',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    // Delete (owner or author)
                    if (canDelete) ...[
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: onDelete,
                        child: const Text(
                          'Delete',
                          style: TextStyle(
                              color: Colors.white24, fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
