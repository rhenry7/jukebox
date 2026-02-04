import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/Api/api_key.dart';
import 'package:flutter_test_project/GIFs/gifs.dart';
import 'package:flutter_test_project/models/user_playlist.dart';
import 'package:flutter_test_project/providers/user_playlist_provider.dart';
import 'package:flutter_test_project/services/user_playlist_service.dart';
import 'package:flutter_test_project/ui/screens/playlists/add_songs_screen.dart';
import 'package:spotify/spotify.dart' as spotify;

/// Screen showing playlist details and tracks
class PlaylistDetailScreen extends ConsumerStatefulWidget {
  final String playlistId;

  const PlaylistDetailScreen({super.key, required this.playlistId});

  @override
  ConsumerState<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
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
    if (_searchDebounce?.isActive ?? false) {
      _searchDebounce!.cancel();
    }
    if (_searchController.text.trim().length >= 2) {
      _searchDebounce = Timer(const Duration(milliseconds: 500), () {
        _performSearch(_searchController.text.trim());
      });
      setState(() {
        _showSearchResults = true;
      });
    } else {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
    }
  }

  Future<void> _performSearch(String query) async {
    if (_isSearching) return;

    setState(() {
      _isSearching = true;
    });

    try {
      final credentials = spotify.SpotifyApiCredentials(clientId, clientSecret);
      final spotifyApi = spotify.SpotifyApi(credentials);

      final searchResults = await spotifyApi.search
          .get(query, types: [spotify.SearchType.track])
          .first(20);

      final tracks = <spotify.Track>[];
      for (final page in searchResults) {
        if (page.items != null) {
          for (final item in page.items!) {
            if (item is spotify.Track) {
              tracks.add(item);
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _searchResults = tracks;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching: $e')),
        );
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _addTrack(spotify.Track track) async {
    try {
      final playlistTrack = PlaylistTrack(
        trackId: track.id ?? '',
        title: track.name ?? 'Unknown',
        artist: track.artists?.map((a) => a.name ?? '').join(', ') ?? 'Unknown',
        albumTitle: track.album?.name,
        imageUrl: track.album?.images?.isNotEmpty == true
            ? track.album!.images!.first.url
            : null,
        durationMs: track.durationMs,
        spotifyUri: track.uri,
        addedAt: DateTime.now(),
      );

      await UserPlaylistService.addTrackToPlaylist(
        playlistId: widget.playlistId,
        track: playlistTrack,
      );

      // Clear search and refresh
      _searchController.clear();
      setState(() {
        _showSearchResults = false;
        _searchResults = [];
      });

      // Invalidate provider so playlist updates
      ref.invalidate(playlistProvider(widget.playlistId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${track.name}" to playlist'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding track: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playlistAsync = ref.watch(playlistProvider(widget.playlistId));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: playlistAsync.when(
          data: (playlist) => Text(
            playlist?.name ?? 'Playlist',
            style: const TextStyle(color: Colors.white),
          ),
          loading: () => const Text(
            'Playlist',
            style: TextStyle(color: Colors.white),
          ),
          error: (_, __) => const Text(
            'Playlist',
            style: TextStyle(color: Colors.white),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          playlistAsync.when(
            data: (playlist) => playlist != null
                ? IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddSongsScreen(playlistId: widget.playlistId),
                        ),
                      );
                    },
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: playlistAsync.when(
        data: (playlist) {
          if (playlist == null) {
            return const Center(
              child: Text(
                'Playlist not found',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          // Debug: Print playlist info
          debugPrint('🎵 [PLAYLIST DETAIL] Loaded playlist: ${playlist.name}');
          debugPrint('   Track count: ${playlist.tracks.length}');
          if (playlist.tracks.isNotEmpty) {
            debugPrint('   First track: ${playlist.tracks.first.title} by ${playlist.tracks.first.artist}');
          }

          return RefreshIndicator(
            onRefresh: () async {
              // Invalidate and wait for refresh
              ref.invalidate(playlistProvider(widget.playlistId));
              await Future.delayed(const Duration(milliseconds: 500));
            },
            color: Colors.red[600],
            child: CustomScrollView(
              slivers: [
                // Playlist header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cover image
                        if (playlist.coverImageUrl != null)
                          Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                playlist.coverImageUrl!,
                                width: 200,
                                height: 200,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 200,
                                    height: 200,
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.music_note,
                                      color: Colors.red,
                                      size: 80,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        // Name
                        Text(
                          playlist.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Description
                        if (playlist.description != null && playlist.description!.isNotEmpty)
                          Text(
                            playlist.description!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        const SizedBox(height: 8),
                        // Tags
                        if (playlist.tags.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: playlist.tags.map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.red.withOpacity(0.5),
                                  ),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 8),
                        // Track count
                        Text(
                          '${playlist.trackCount} ${playlist.trackCount == 1 ? 'track' : 'tracks'}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Search bar for adding tracks
                        TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Search for songs to add...',
                            hintStyle: const TextStyle(color: Colors.white30),
                            prefixIcon: const Icon(Icons.search, color: Colors.white70),
                            suffixIcon: _isSearching
                                ? const Padding(
                                    padding: EdgeInsets.all(12.0),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: Center(
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, color: Colors.white70),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {
                                            _showSearchResults = false;
                                            _searchResults = [];
                                          });
                                        },
                                      )
                                    : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.white30),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.white30),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.red, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                // Search results (separate sliver to avoid overflow)
                if (_showSearchResults && _searchResults.isNotEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 12),
                          Text(
                            'Search Results',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                if (_showSearchResults && _searchResults.isNotEmpty)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final track = _searchResults[index];
                        final imageUrl = track.album?.images?.isNotEmpty == true
                            ? track.album!.images!.first.url
                            : null;
                        final isInPlaylist = playlist.tracks.any((t) => t.trackId == track.id);

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                          child: Card(
                            color: Colors.white10,
                            child: ListTile(
                              leading: imageUrl != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.network(
                                        imageUrl,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return const Icon(
                                            Icons.music_note,
                                            color: Colors.white70,
                                            size: 50,
                                          );
                                        },
                                      ),
                                    )
                                  : const Icon(Icons.music_note, color: Colors.white70),
                              title: Text(
                                track.name ?? 'Unknown',
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                track.artists?.map((a) => a.name).join(', ') ?? 'Unknown',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              trailing: isInPlaylist
                                  ? const Icon(Icons.check_circle, color: Colors.green)
                                  : IconButton(
                                      icon: const Icon(Icons.add_circle, color: Colors.red),
                                      onPressed: () => _addTrack(track),
                                    ),
                              onTap: isInPlaylist ? null : () => _addTrack(track),
                            ),
                          ),
                        );
                      },
                      childCount: _searchResults.length,
                    ),
                  ),
                // Tracks list
                if (playlist.tracks.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.music_off, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'No tracks yet',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddSongsScreen(playlistId: widget.playlistId),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[600],
                            ),
                            child: const Text('Add Songs'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final track = playlist.tracks[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          color: Colors.white10,
                          child: ListTile(
                            leading: track.imageUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.network(
                                      track.imageUrl!,
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return const Icon(
                                          Icons.music_note,
                                          color: Colors.white70,
                                          size: 50,
                                        );
                                      },
                                    ),
                                  )
                                : const Icon(Icons.music_note, color: Colors.white70),
                            title: Text(
                              track.title,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              track.artist,
                              style: const TextStyle(color: Colors.white70),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Remove Track'),
                                    content: Text(
                                      'Remove "${track.title}" from this playlist?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                        child: const Text('Remove'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  try {
                                    await UserPlaylistService.removeTrackFromPlaylist(
                                      playlistId: widget.playlistId,
                                      trackId: track.trackId,
                                    );
                                    if (mounted) {
                                      ref.invalidate(playlistProvider(widget.playlistId));
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error removing track: $e')),
                                      );
                                    }
                                  }
                                }
                              },
                            ),
                          ),
                        );
                      },
                      childCount: playlist.tracks.length,
                    ),
                  ),
              ],
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
                'Error loading playlist',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
