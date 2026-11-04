import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/notification_event.dart';
import '../services/activity_service.dart';
import '../services/notifications_service.dart';
import 'auth_provider.dart';
import 'reviews_provider.dart';

/// Reviews the signed-in user liked, reposted or commented on, newest first.
final userActivityLogProvider =
    StreamProvider.autoDispose<List<ActivityItem>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const []);
  // Activity is a nice-to-have: if the log can't be read (e.g. the rules
  // that allow it aren't deployed yet), show it as empty rather than failing
  // the whole tab.
  return ActivityService().activityStream(userId).transform(
    StreamTransformer.fromHandlers(handleError: (error, _, sink) {
      debugPrint('[ACTIVITY] Could not read activity log: $error');
      sink.add(const <ActivityItem>[]);
    }),
  );
});

/// The signed-in user's notifications: what others did to them.
final userNotificationsProvider =
    StreamProvider.autoDispose<List<NotificationEvent>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const []);
  return NotificationsService().notificationsStream(userId);
});

/// Profile → Activity: everything the user did and everything done to their
/// reviews, newest first. Loading until the activity log arrives; the other
/// sources join as they load (a failure there only hides them).
final profileActivityProvider =
    Provider.autoDispose<AsyncValue<List<ActivityItem>>>((ref) {
  final log = ref.watch(userActivityLogProvider);
  final notifications =
      ref.watch(userNotificationsProvider).valueOrNull ?? const [];
  final ownReviews = ref.watch(userReviewsProvider).valueOrNull ?? const [];
  return log.whenData((items) => buildActivity(
        log: items,
        notifications: notifications,
        ownReviews: ownReviews,
      ));
});

/// Display name for a user whose name a notification didn't store. Tries
/// their profile, then the name on one of their reviews.
final actorNameProvider =
    FutureProvider.family<String?, String>((ref, userId) async {
  final db = FirebaseFirestore.instance;
  try {
    final profile = (await db.collection('users').doc(userId).get()).data();
    final name = (profile?['displayName'] as String?)?.trim();
    if (name != null && name.isNotEmpty) return name;

    final reviews = await db
        .collection('users')
        .doc(userId)
        .collection('reviews')
        .limit(1)
        .get();
    final fromReview = reviews.docs.isEmpty
        ? null
        : (reviews.docs.first.data()['displayName'] as String?)?.trim();
    return (fromReview?.isNotEmpty ?? false) ? fromReview : null;
  } catch (e) {
    debugPrint('[ACTIVITY] Could not look up name for $userId: $e');
    return null;
  }
});

/// True when a stored name is missing or the "Someone" placeholder.
bool needsActorName(String? name) {
  final n = name?.trim() ?? '';
  return n.isEmpty || n == 'Someone';
}

const Map<String, String> _notificationTypes = {
  NotificationType.reviewLike: ActivityType.likedYourReview,
  NotificationType.reviewComment: ActivityType.commentedOnYourReview,
  NotificationType.reviewRepost: ActivityType.repostedYourReview,
  NotificationType.friendAdded: ActivityType.friendAdded,
};

/// Merges the activity sources into one list, newest first:
///  - [log]: the user's likes and comments (its repost entries are skipped —
///    reposts come from [ownReviews], which has every one, old and new);
///  - [ownReviews]: reviews the user wrote, and their reposts;
///  - [notifications]: likes, comments and reposts on the user's reviews,
///    and friend adds.
@visibleForTesting
List<ActivityItem> buildActivity({
  required List<ActivityItem> log,
  required List<NotificationEvent> notifications,
  required List<ReviewWithDocId> ownReviews,
}) {
  // Notifications don't store album art; the user's own reviews have it.
  // Match on the review path, or on title + artist for older notifications
  // whose review path is in a different form.
  String trackKey(String? title, String? artist) =>
      '${title?.trim().toLowerCase()}|${artist?.trim().toLowerCase()}';
  final artByReview = <String, String?>{
    for (final r in ownReviews) ...{
      if (r.fullReviewId != null) r.fullReviewId!: r.review.albumImageUrl,
      trackKey(r.review.title, r.review.artist): r.review.albumImageUrl,
    },
  };

  return newestFirst([
    ...log.where((i) => i.type != ActivityType.repost),
    for (final r in ownReviews)
      ActivityItem(
        id: 'own_${r.docId}',
        type: r.review.isRepost ? ActivityType.repost : ActivityType.review,
        reviewId: r.fullReviewId,
        title: r.review.title,
        artist: r.review.artist,
        albumImageUrl: r.review.albumImageUrl,
        // A repost copy keeps the original author's name.
        reviewAuthorName: r.review.isRepost ? r.review.displayName : null,
        score: r.review.isRepost ? null : r.review.score,
        createdAt: r.review.date,
      ),
    for (final n in _latestPerAction(notifications))
      if (_notificationTypes[n.type] case final type?)
        ActivityItem(
          id: 'notif_${n.id}',
          type: type,
          reviewId: n.reviewId,
          title: n.reviewTitle,
          artist: n.reviewArtist,
          albumImageUrl: artByReview[n.reviewId] ??
              artByReview[trackKey(n.reviewTitle, n.reviewArtist)],
          commentText: n.commentPreview,
          actorId: n.actorId,
          actorDisplayName: n.actorDisplayName,
          createdAt: n.createdAt,
        ),
  ]);
}

/// One notification per person, action and review: liking, unliking and
/// liking again leaves several behind. Keeps the newest of each.
List<NotificationEvent> _latestPerAction(List<NotificationEvent> events) {
  final latest = <String, NotificationEvent>{};
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  for (final n in events) {
    // Each comment is its own action, so comments are never collapsed.
    final key = n.type == NotificationType.reviewComment
        ? n.id
        : '${n.type}|${n.actorId}|${n.reviewId ?? n.reviewTitle}';
    final kept = latest[key];
    if (kept == null ||
        (n.createdAt ?? epoch).isAfter(kept.createdAt ?? epoch)) {
      latest[key] = n;
    }
  }
  return latest.values.toList();
}

List<ActivityItem> newestFirst(Iterable<ActivityItem> items) {
  // A just-written entry has no server time yet; it is the newest.
  final pending = DateTime(9999);
  return [
    ...items
  ]..sort((x, y) => (y.createdAt ?? pending).compareTo(x.createdAt ?? pending));
}
