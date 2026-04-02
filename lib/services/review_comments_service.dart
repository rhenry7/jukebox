import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/review_comment.dart';
import 'notifications_service.dart';

class ReviewCommentsService {
  final FirebaseFirestore _db;

  ReviewCommentsService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  static const int maxLength = 1000;

  // reviewComments/{sanitizedReviewId}/comments/{commentId}
  String _sanitize(String reviewId) => reviewId.replaceAll('/', '_');

  CollectionReference<Map<String, dynamic>> _commentsRef(String reviewId) =>
      _db
          .collection('reviewComments')
          .doc(_sanitize(reviewId))
          .collection('comments');

  DocumentReference<Map<String, dynamic>> _likeRef(
          String reviewId, String commentId, String userId) =>
      _commentsRef(reviewId).doc(commentId).collection('likes').doc(userId);

  // ── Read ────────────────────────────────────────────────────────────────────

  Stream<List<ReviewComment>> commentsStream(String reviewId) {
    return _commentsRef(reviewId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ReviewComment.fromFirestore(d)).toList())
        .handleError((e) {
      debugPrint('[COMMENTS] Stream error: $e');
    });
  }

  Stream<bool> commentLikeStream(
      String reviewId, String commentId, String userId) {
    return _likeRef(reviewId, commentId, userId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  // ── Write ───────────────────────────────────────────────────────────────────

  Future<void> addComment({
    required String reviewId,
    required String userId,
    required String displayName,
    required String text,
    // For notification: who owns this review
    String? reviewOwnerUserId,
    String? reviewTitle,
    String? reviewArtist,
  }) async {
    final trimmed = text.trim();
    assert(trimmed.isNotEmpty && trimmed.length <= maxLength);

    final ref = await _commentsRef(reviewId).add({
      'userId': userId,
      'displayName': displayName,
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
      'likes': 0,
    });
    debugPrint('[COMMENTS] Added comment ${ref.id} on review $reviewId');

    // Notify the review owner (skip if they're commenting on their own review)
    if (reviewOwnerUserId != null && reviewOwnerUserId != userId) {
      try {
        await NotificationsService().createReviewCommentNotification(
          targetUserId: reviewOwnerUserId,
          actorUserId: userId,
          reviewId: reviewId,
          reviewTitle: reviewTitle,
          reviewArtist: reviewArtist,
          commentPreview: trimmed.length > 80
              ? '${trimmed.substring(0, 80)}…'
              : trimmed,
        );
      } catch (e) {
        debugPrint('[COMMENTS] Notification failed (non-fatal): $e');
      }
    }
  }

  Future<void> updateComment({
    required String reviewId,
    required String commentId,
    required String userId,
    required String newText,
  }) async {
    final trimmed = newText.trim();
    assert(trimmed.isNotEmpty && trimmed.length <= maxLength);

    final doc = await _commentsRef(reviewId).doc(commentId).get();
    if (!doc.exists || doc.data()?['userId'] != userId) {
      throw Exception('Not authorised to edit this comment');
    }
    await _commentsRef(reviewId).doc(commentId).update({'text': trimmed});
  }

  Future<void> deleteComment({
    required String reviewId,
    required String commentId,
    required String userId,
  }) async {
    final doc = await _commentsRef(reviewId).doc(commentId).get();
    if (!doc.exists || doc.data()?['userId'] != userId) {
      throw Exception('Not authorised to delete this comment');
    }
    await _commentsRef(reviewId).doc(commentId).delete();
  }

  Future<void> toggleCommentLike({
    required String reviewId,
    required String commentId,
    required String userId,
  }) async {
    final likeRef = _likeRef(reviewId, commentId, userId);
    final commentRef = _commentsRef(reviewId).doc(commentId);

    final existing = await likeRef.get();
    if (existing.exists) {
      await Future.wait([
        likeRef.delete(),
        commentRef.update({'likes': FieldValue.increment(-1)}),
      ]);
    } else {
      await Future.wait([
        likeRef.set({'likedAt': FieldValue.serverTimestamp()}),
        commentRef.update({'likes': FieldValue.increment(1)}),
      ]);
    }
  }
}
