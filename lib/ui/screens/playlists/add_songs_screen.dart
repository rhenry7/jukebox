import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/Api/api_key.dart';
import 'package:flutter_test_project/GIFs/gifs.dart';
import 'package:flutter_test_project/models/user_playlist.dart';
import 'package:flutter_test_project/providers/user_playlist_provider.dart';
import 'package:flutter_test_project/services/user_playlist_service.dart';
import 'package:spotify/spotify.dart' as spotify;

/// Screen for adding songs to a playlist
class AddSongsScreen extends ConsumerStatefulWidget {
  final String playlistId;

  const AddSongsScreen({super.key, required this.playlistId});

  @override
  ConsumerState<AddSongsScreen> createState() => _AddSongsScreenState();
}

class _AddSongsScreenState extends ConsumerState<AddSongsScreen> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<spotify.Track> _searchResults = [];
  bool _isSearching = false;
  Set<String> _addedTrackIds = {}; // Track IDs already in playlist

  @override
  void initState() {
    super.initState();
    _loadPlaylistTracks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadPlaylistTracks() async {
    final playlist = await UserPlaylistService.getPlaylist(widget.playlistId);
    if (playlist != null) {
      setState(() {
        _addedTrackIds = playlist.tracks.map((t) => t.trackId).toSet();
      });
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().length >= 2) {
      _searchDebounce = Timer(const Duration(milliseconds: 500), () {
        _performSearch(query.trim());
      });
    } else {
      setState(() {
        _searchResults = [];
        _isSearching = false;
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
    if (_addedTrackIds.contains(track.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Track already in playlist')),
      );
      return;
    }

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

      // Refresh the playlist to get updated track list
      await _loadPlaylistTracks();
      
      // Invalidate provider so detail screen updates
      ref.invalidate(singlePlaylistProvider(widget.playlistId));

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
    final playlistAsync = ref.watch(singlePlaylistProvider(widget.playlistId));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: playlistAsync.when(
          data: (playlist) => Text(
            playlist?.name ?? 'Add Songs',
            style: const TextStyle(color: Colors.white),
          ),
          loading: () => const Text(
            'Add Songs',
            style: TextStyle(color: Colors.white),
          ),
          error: (_, __) => const Text(
            'Add Songs',
            style: TextStyle(color: Colors.white),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search for songs...',
                hintStyle: const TextStyle(color: Colors.white30),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: DiscoBallLoading(),
                        ),
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
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          // Search results
          Expanded(
            child: _isSearching
                ? const Center(child: DiscoBallLoading())
                : _searchResults.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'Search for songs to add',
                              style: TextStyle(color: Colors.white70, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final track = _searchResults[index];
                          final isAdded = _addedTrackIds.contains(track.id);
                          final imageUrl = track.album?.images?.isNotEmpty == true
                              ? track.album!.images!.first.url
                              : null;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
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
                              trailing: isAdded
                                  ? const Icon(Icons.check_circle, color: Colors.green)
                                  : IconButton(
                                      icon: const Icon(Icons.add_circle, color: Colors.red),
                                      onPressed: () => _addTrack(track),
                                    ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
