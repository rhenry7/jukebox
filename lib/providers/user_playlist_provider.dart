import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/models/user_playlist.dart';
import 'package:flutter_test_project/providers/auth_provider.dart';
import 'package:flutter_test_project/providers/friends_provider.dart';
import 'package:flutter_test_project/services/playlist_likes_service.dart';
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
final singlePlaylistProvider = StreamProvider.autoDispose.family<UserPlaylist?, String>((ref, playlistId) {
  return UserPlaylistService.getPlaylistStream(playlistId);
});

/// Provider for all community playlists (all users)
final communityPlaylistsProvider = StreamProvider<List<UserPlaylist>>((ref) {
  return UserPlaylistService.getAllPlaylists();
});

/// Provider for friends' playlists
final friendsPlaylistsProvider = StreamProvider<List<UserPlaylist>>((ref) {
  final friendIds = ref.watch(friendIdsProvider).value ?? [];
  if (friendIds.isEmpty) return Stream.value([]);
  return UserPlaylistService.getPlaylistsByUserIds(friendIds);
});

/// Stream of playlist IDs liked/saved by the current user.
final likedPlaylistIdsProvider = StreamProvider<List<String>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);
  return PlaylistLikesService.likedPlaylistIdsStream(userId);
});

/// Playlists liked/saved by the current user (real-time).
final likedPlaylistsProvider = StreamProvider<List<UserPlaylist>>((ref) {
  final likedIds = ref.watch(likedPlaylistIdsProvider).value ?? [];
  return UserPlaylistService.getPlaylistsByIds(likedIds);
});

/// Per-playlist like status for the current user.
final playlistLikeStatusProvider =
    StreamProvider.autoDispose.family<bool, String>((ref, playlistId) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(false);
  return PlaylistLikesService.likeStatusStream(playlistId, userId);
});

/// Display name for a given userId (fetched once from Firestore).
final userDisplayNameProvider =
    FutureProvider.autoDispose.family<String, String>((ref, userId) async {
  if (userId.isEmpty) return '';
  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    return doc.data()?['displayName'] as String? ?? '';
  } catch (_) {
    return '';
  }
});
