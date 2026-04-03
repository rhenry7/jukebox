import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/notification_event.dart';

class NotificationsService {
  final FirebaseFirestore _firestore;

  NotificationsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // In-process cache to avoid repeated Firestore reads for the same user.
  static final Map<String, _ActorInfo> _actorCache = {};

  static String _sanitizeId(String id) =>
      id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

  CollectionReference<Map<String, dynamic>> _notificationsRef(String userId) {
    return _firestore.collection('users').doc(userId).collection('notifications');
  }

  Stream<List<NotificationEvent>> notificationsStream(String userId) {
    debugPrint('[NOTIF] Starting notifications stream for user: $userId');
    return _notificationsRef(userId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      debugPrint('[NOTIF] Stream snapshot received: ${snapshot.docs.length} docs');
      return snapshot.docs.map((doc) {
        try {
          return NotificationEvent.fromFirestore(doc);
        } catch (e) {
          debugPrint('[NOTIF] Error parsing notification ${doc.id}: $e');
          return null;
        }
      }).where((n) => n != null).cast<NotificationEvent>().toList();
    }).handleError((error) {
      debugPrint('[NOTIF] Stream error: $error');
    });
  }

  Future<void> createFriendAddedNotification({
    required String targetUserId,
    required String actorUserId,
  }) async {
    if (targetUserId == actorUserId) {
      debugPrint('[NOTIF] Skipped friend notification: actor == target');
      return;
    }

    try {
      debugPrint('[NOTIF] Creating friend-added notification: '
          'actor=$actorUserId → target=$targetUserId');
      final actorInfo = await _fetchActorInfo(actorUserId);
      // Deterministic ID: one friend-added notification per actor per target.
      final docId = '${_sanitizeId(actorUserId)}_fa';
      await _notificationsRef(targetUserId).doc(docId).set({
        'type': NotificationType.friendAdded,
        'actorId': actorUserId,
        'actorDisplayName': actorInfo.displayName,
        'actorPhotoUrl': actorInfo.photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
      debugPrint('[NOTIF] Friend notification upserted: $docId '
          'in users/$targetUserId/notifications');
    } catch (e) {
      debugPrint('[NOTIF] ERROR creating friend notification: $e');
      rethrow;
    }
  }

  Future<void> createReviewLikeNotification({
    required String targetUserId,
    required String actorUserId,
    required String reviewId,
    String? reviewTitle,
    String? reviewArtist,
  }) async {
    if (targetUserId == actorUserId) {
      debugPrint('[NOTIF] Skipped like notification: actor == target (own review)');
      return;
    }

    try {
      debugPrint('[NOTIF] Creating review-like notification: '
          'actor=$actorUserId → target=$targetUserId, review=$reviewTitle');
      final actorInfo = await _fetchActorInfo(actorUserId);
      // Deterministic ID: one like notification per actor+review, deduplicates rapid re-likes.
      final docId = '${_sanitizeId(actorUserId)}_${_sanitizeId(reviewId)}_rl';
      await _notificationsRef(targetUserId).doc(docId).set({
        'type': NotificationType.reviewLike,
        'actorId': actorUserId,
        'actorDisplayName': actorInfo.displayName,
        'actorPhotoUrl': actorInfo.photoUrl,
        'reviewId': reviewId,
        'reviewTitle': reviewTitle,
        'reviewArtist': reviewArtist,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
      debugPrint('[NOTIF] Like notification upserted: $docId '
          'in users/$targetUserId/notifications');
    } catch (e) {
      debugPrint('[NOTIF] ERROR creating like notification: $e');
      rethrow;
    }
  }

  Future<void> createRepostNotification({
    required String targetUserId,
    required String actorUserId,
    required String reviewId,
    String? reviewTitle,
    String? reviewArtist,
  }) async {
    if (targetUserId == actorUserId) return;
    try {
      final actorInfo = await _fetchActorInfo(actorUserId);
      // Deterministic ID: one repost notification per actor+review.
      final docId = '${_sanitizeId(actorUserId)}_${_sanitizeId(reviewId)}_rr';
      await _notificationsRef(targetUserId).doc(docId).set({
        'type': NotificationType.reviewRepost,
        'actorId': actorUserId,
        'actorDisplayName': actorInfo.displayName,
        'actorPhotoUrl': actorInfo.photoUrl,
        'reviewId': reviewId,
        'reviewTitle': reviewTitle,
        'reviewArtist': reviewArtist,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      debugPrint('[NOTIF] ERROR creating repost notification: $e');
      rethrow;
    }
  }

  Future<void> createReviewCommentNotification({
    required String targetUserId,
    required String actorUserId,
    required String reviewId,
    String? reviewTitle,
    String? reviewArtist,
    String? commentPreview,
  }) async {
    if (targetUserId == actorUserId) return;

    try {
      debugPrint('[NOTIF] Creating review-comment notification: '
          'actor=$actorUserId → target=$targetUserId');
      final actorInfo = await _fetchActorInfo(actorUserId);
      await _notificationsRef(targetUserId).add({
        'type': NotificationType.reviewComment,
        'actorId': actorUserId,
        'actorDisplayName': actorInfo.displayName,
        'actorPhotoUrl': actorInfo.photoUrl,
        'reviewId': reviewId,
        'reviewTitle': reviewTitle,
        'reviewArtist': reviewArtist,
        'commentPreview': commentPreview,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      debugPrint('[NOTIF] ERROR creating comment notification: $e');
      rethrow;
    }
  }

  Future<_ActorInfo> _fetchActorInfo(String userId) async {
    if (_actorCache.containsKey(userId)) return _actorCache[userId]!;
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final data = doc.data();
      final displayName = (data?['displayName'] as String?)?.trim();
      final email = (data?['email'] as String?)?.trim();
      final fallback = email != null && email.contains('@')
          ? email.split('@').first
          : null;
      final resolvedName = (displayName != null && displayName.isNotEmpty)
          ? displayName
          : (fallback != null && fallback.isNotEmpty)
              ? fallback
              : 'Someone';
      final photoUrl =
          (data?['photoUrl'] as String?) ?? (data?['userImageUrl'] as String?);

      final result = _ActorInfo(displayName: resolvedName, photoUrl: photoUrl);
      _actorCache[userId] = result;
      return result;
    } catch (e) {
      debugPrint('Error fetching actor info: $e');
      return const _ActorInfo(displayName: 'Someone');
    }
  }
}

class _ActorInfo {
  final String displayName;
  final String? photoUrl;

  const _ActorInfo({required this.displayName, this.photoUrl});
}
