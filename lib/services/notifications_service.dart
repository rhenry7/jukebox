import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/notification_event.dart';

class NotificationsService {
  final FirebaseFirestore _firestore;

  NotificationsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

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
      final docRef = await _notificationsRef(targetUserId).add({
        'type': NotificationType.friendAdded,
        'actorId': actorUserId,
        'actorDisplayName': actorInfo.displayName,
        'actorPhotoUrl': actorInfo.photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
      debugPrint('[NOTIF] Friend notification created: ${docRef.id} '
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
      final docRef = await _notificationsRef(targetUserId).add({
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
      debugPrint('[NOTIF] Like notification created: ${docRef.id} '
          'in users/$targetUserId/notifications');
    } catch (e) {
      debugPrint('[NOTIF] ERROR creating like notification: $e');
      rethrow;
    }
  }

  Future<_ActorInfo> _fetchActorInfo(String userId) async {
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

      return _ActorInfo(displayName: resolvedName, photoUrl: photoUrl);
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
