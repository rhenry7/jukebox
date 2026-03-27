import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service for liking/saving playlists.
///
/// Firestore layout:
///   playlistLikes/{playlistId}/likes/{userId}  — per-playlist like records
///   userLikedPlaylists/{userId}                — { playlistIds: [...] }
class PlaylistLikesService {
  static final _db = FirebaseFirestore.instance;

  static Future<void> likePlaylist(String playlistId, String userId) async {
    try {
      final batch = _db.batch();
      batch.set(
        _db
            .collection('playlistLikes')
            .doc(playlistId)
            .collection('likes')
            .doc(userId),
        {
          'userId': userId,
          'playlistId': playlistId,
          'likedAt': FieldValue.serverTimestamp(),
        },
      );
      batch.set(
        _db.collection('userLikedPlaylists').doc(userId),
        {
          'playlistIds': FieldValue.arrayUnion([playlistId])
        },
        SetOptions(merge: true),
      );
      await batch.commit();
    } catch (e) {
      debugPrint('Error liking playlist: $e');
      rethrow;
    }
  }

  static Future<void> unlikePlaylist(String playlistId, String userId) async {
    try {
      final batch = _db.batch();
      batch.delete(
        _db
            .collection('playlistLikes')
            .doc(playlistId)
            .collection('likes')
            .doc(userId),
      );
      batch.set(
        _db.collection('userLikedPlaylists').doc(userId),
        {
          'playlistIds': FieldValue.arrayRemove([playlistId])
        },
        SetOptions(merge: true),
      );
      await batch.commit();
    } catch (e) {
      debugPrint('Error unliking playlist: $e');
      rethrow;
    }
  }

  /// Stream of whether [userId] has liked [playlistId].
  static Stream<bool> likeStatusStream(String playlistId, String userId) {
    return _db
        .collection('playlistLikes')
        .doc(playlistId)
        .collection('likes')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  /// Stream of all playlist IDs liked by [userId].
  static Stream<List<String>> likedPlaylistIdsStream(String userId) {
    return _db.collection('userLikedPlaylists').doc(userId).snapshots().map(
      (doc) {
        if (!doc.exists || doc.data() == null) return <String>[];
        return List<String>.from(doc.data()!['playlistIds'] ?? []);
      },
    );
  }
}
