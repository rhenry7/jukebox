import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test_project/models/crate_comment.dart';

/// Firestore path: playlists/{playlistId}/comments/{commentId}
class CrateCommentService {
  static CollectionReference<Map<String, dynamic>> _ref(String playlistId) =>
      FirebaseFirestore.instance
          .collection('playlists')
          .doc(playlistId)
          .collection('comments');

  /// Real-time stream of comments, newest first.
  static Stream<List<CrateComment>> commentsStream(String playlistId) {
    return _ref(playlistId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => CrateComment.fromFirestore(d)).toList());
  }

  /// Post a new comment.
  static Future<void> addComment({
    required String playlistId,
    required String userId,
    required String displayName,
    required String text,
  }) async {
    final comment = CrateComment(
      id: '',
      playlistId: playlistId,
      userId: userId,
      displayName: displayName,
      text: text.trim(),
      createdAt: DateTime.now(),
      likes: 0,
    );
    await _ref(playlistId).add(comment.toFirestore());
  }

  /// Delete a comment by its ID.
  static Future<void> deleteComment(
          String playlistId, String commentId) async =>
      _ref(playlistId).doc(commentId).delete();

  /// Toggle like on a comment (simple increment/decrement, no per-user tracking).
  static Future<void> toggleLike(
      String playlistId, String commentId, bool isLiked) async {
    await _ref(playlistId).doc(commentId).update({
      'likes': FieldValue.increment(isLiked ? -1 : 1),
    });
  }
}
