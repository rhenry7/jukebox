import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/review.dart';
import 'notifications_service.dart';

class RepostService {
  final FirebaseFirestore _db;

  RepostService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  // reposts/{sanitizedReviewId}/reposters/{userId}
  String _sanitize(String reviewId) => reviewId.replaceAll('/', '_');

  CollectionReference<Map<String, dynamic>> _repostersRef(String reviewId) =>
      _db
          .collection('reposts')
          .doc(_sanitize(reviewId))
          .collection('reposters');

  // ── Streams ─────────────────────────────────────────────────────────────────

  Stream<bool> repostStatusStream(String originalReviewId, String userId) =>
      _repostersRef(originalReviewId)
          .doc(userId)
          .snapshots()
          .map((doc) => doc.exists);

  Stream<int> repostCountStream(String originalReviewId) =>
      _db
          .collection('reposts')
          .doc(_sanitize(originalReviewId))
          .snapshots()
          .map((doc) => (doc.data()?['count'] as num?)?.toInt() ?? 0);

  // ── Toggle ───────────────────────────────────────────────────────────────────

  Future<void> toggleRepost({
    required String originalReviewId, // full path: users/uid/reviews/docId
    required String reposterUserId,
    required String reposterDisplayName,
    required Review originalReview,
    required String originalUserId,
  }) async {
    final reposterDoc = _repostersRef(originalReviewId).doc(reposterUserId);
    final existing = await reposterDoc.get();

    if (existing.exists) {
      await _unrepost(
        reposterDoc: reposterDoc,
        repostedDocId: existing.data()?['repostedDocId'] as String?,
        reposterUserId: reposterUserId,
        originalReviewId: originalReviewId,
      );
    } else {
      await _repost(
        reposterDoc: reposterDoc,
        originalReviewId: originalReviewId,
        reposterUserId: reposterUserId,
        reposterDisplayName: reposterDisplayName,
        originalReview: originalReview,
        originalUserId: originalUserId,
      );
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  Future<void> _repost({
    required DocumentReference<Map<String, dynamic>> reposterDoc,
    required String originalReviewId,
    required String reposterUserId,
    required String reposterDisplayName,
    required Review originalReview,
    required String originalUserId,
  }) async {
    // 1. Write a copy into the reposter's reviews collection
    final repostData = {
      ...originalReview.toJson(),
      'isRepost': true,
      'repostedByDisplayName': reposterDisplayName,
      'repostedByUserId': reposterUserId,
      'originalReviewId': _sanitize(originalReviewId),
      'date': FieldValue.serverTimestamp(),
    };

    final repostDocRef = await _db
        .collection('users')
        .doc(reposterUserId)
        .collection('reviews')
        .add(repostData);

    // 2. Record in the reposters subcollection (for status lookup + count)
    final batch = _db.batch();
    batch.set(reposterDoc, {
      'repostedDocId': repostDocRef.id,
      'repostedAt': FieldValue.serverTimestamp(),
    });
    // Increment the top-level count doc
    batch.set(
      _db.collection('reposts').doc(_sanitize(originalReviewId)),
      {'count': FieldValue.increment(1)},
      SetOptions(merge: true),
    );
    await batch.commit();

    debugPrint('[REPOST] ${reposterUserId} reposted $originalReviewId');

    // 3. Notify original author (non-fatal)
    if (originalUserId != reposterUserId) {
      try {
        await NotificationsService().createRepostNotification(
          targetUserId: originalUserId,
          actorUserId: reposterUserId,
          reviewId: originalReviewId,
          reviewTitle: originalReview.title,
          reviewArtist: originalReview.artist,
        );
      } catch (e) {
        debugPrint('[REPOST] Notification failed (non-fatal): $e');
      }
    }
  }

  Future<void> _unrepost({
    required DocumentReference<Map<String, dynamic>> reposterDoc,
    required String? repostedDocId,
    required String reposterUserId,
    required String originalReviewId,
  }) async {
    final batch = _db.batch();

    // Remove the repost copy from the reposter's reviews
    if (repostedDocId != null) {
      batch.delete(
        _db
            .collection('users')
            .doc(reposterUserId)
            .collection('reviews')
            .doc(repostedDocId),
      );
    }

    // Remove from reposters subcollection
    batch.delete(reposterDoc);

    // Decrement count
    batch.set(
      _db.collection('reposts').doc(_sanitize(originalReviewId)),
      {'count': FieldValue.increment(-1)},
      SetOptions(merge: true),
    );

    await batch.commit();
    debugPrint('[REPOST] ${reposterUserId} un-reposted $originalReviewId');
  }
}
