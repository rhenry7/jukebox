import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/models/user_playlist.dart';
import 'package:flutter_test_project/providers/auth_provider.dart';
import 'package:flutter_test_project/services/user_playlist_service.dart';

/// Provider for user's playlists
final userPlaylistsProvider = StreamProvider<List<UserPlaylist>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  
  if (userId == null) {
    return Stream.value([]);
  }
  
  return UserPlaylistService.getUserPlaylists(userId);
});

/// Provider for a single playlist by ID (stream for real-time updates)
final playlistProvider = StreamProvider.family<UserPlaylist?, String>((ref, playlistId) {
  return UserPlaylistService.getPlaylistStream(playlistId);
});
