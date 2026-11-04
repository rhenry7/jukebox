import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Kinds of rows in the Profile → Activity tab.
class ActivityType {
  // Things the user did. like / repost / comment are stored in the activity
  // log; review comes from the user's own reviews.
  static const String like = 'like';
  static const String repost = 'repost';
  static const String comment = 'comment';
  static const String review = 'review';

  // Things others did to the user, from their notifications.
  static const String likedYourReview = 'liked_your_review';
  static const String commentedOnYourReview = 'commented_on_your_review';
  static const String repostedYourReview = 'reposted_your_review';
  static const String friendAdded = 'friend_added';

  static const Set<String> _onYou = {
    likedYourReview,
    commentedOnYourReview,
    repostedYourReview,
    friendAdded,
  };

  /// True for things others did to the user; false for the user's own.
  static bool isOnYou(String type) => _onYou.contains(type);
}

/// One row in the Profile → Activity tab.
class ActivityItem {
  const ActivityItem({
    required this.id,
    required this.type,
    this.reviewId,
    this.title,
    this.artist,
    this.albumImageUrl,
    this.reviewAuthorName,
    this.commentText,
    this.actorId,
    this.actorDisplayName,
    this.score,
    this.createdAt,
  });

  final String id;
  final String type;

  /// Full path of the review: users/{uid}/reviews/{docId}.
  final String? reviewId;
  final String? title;
  final String? artist;
  final String? albumImageUrl;
  final String? reviewAuthorName;
  final String? commentText;

  /// For rows about someone else's action: who did it.
  final String? actorId;
  final String? actorDisplayName;

  /// For [ActivityType.review]: the star rating given.
  final double? score;
  final DateTime? createdAt;

  factory ActivityItem.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final createdAt = data['createdAt'];
    return ActivityItem(
      id: doc.id,
      type: data['type'] as String? ?? '',
      reviewId: data['reviewId'] as String?,
      title: data['title'] as String?,
      artist: data['artist'] as String?,
      albumImageUrl: data['albumImageUrl'] as String?,
      reviewAuthorName: data['reviewAuthorName'] as String?,
      commentText: data['commentText'] as String?,
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
    );
  }
}

/// The user's own activity log at users/{uid}/activity: reviews they liked,
/// reposted or commented on. Written alongside each action (like the
/// notifications the other person gets) and removed when it is undone.
///
/// Logging never fails the action itself — errors are only printed.
class ActivityService {
  ActivityService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const int streamLimit = 100;

  CollectionReference<Map<String, dynamic>> _ref(String userId) =>
      _db.collection('users').doc(userId).collection('activity');

  /// One entry per review for likes and reposts, one per comment.
  static String _docId(String type, String key) =>
      '${type}_${key.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}';

  Stream<List<ActivityItem>> activityStream(String userId) => _ref(userId)
      .orderBy('createdAt', descending: true)
      .limit(streamLimit)
      .snapshots()
      .map((snap) => snap.docs.map(ActivityItem.fromFirestore).toList());

  Future<void> recordLike(String userId, String reviewId) =>
      _record(userId, ActivityType.like, reviewId, key: reviewId);

  Future<void> removeLike(String userId, String reviewId) =>
      _remove(userId, ActivityType.like, reviewId);

  Future<void> recordRepost(String userId, String reviewId) =>
      _record(userId, ActivityType.repost, reviewId, key: reviewId);

  Future<void> removeRepost(String userId, String reviewId) =>
      _remove(userId, ActivityType.repost, reviewId);

  Future<void> recordComment(
    String userId,
    String reviewId, {
    required String commentId,
    required String text,
  }) =>
      _record(userId, ActivityType.comment, reviewId,
          key: commentId, commentText: text);

  Future<void> updateCommentText(
      String userId, String commentId, String text) async {
    try {
      await _ref(userId)
          .doc(_docId(ActivityType.comment, commentId))
          .update({'commentText': text});
    } catch (e) {
      // Older comments have no activity entry; nothing to update.
      debugPrint('[ACTIVITY] Failed to update comment $commentId: $e');
    }
  }

  Future<void> removeComment(String userId, String commentId) =>
      _remove(userId, ActivityType.comment, commentId);

  Future<void> _record(
    String userId,
    String type,
    String reviewId, {
    required String key,
    String? commentText,
  }) async {
    try {
      // Copy what the row shows, so the tab is a single read.
      final review = (await _db.doc(reviewId).get()).data() ?? const {};
      await _ref(userId).doc(_docId(type, key)).set({
        'type': type,
        'reviewId': reviewId,
        'title': review['title'],
        'artist': review['artist'],
        'albumImageUrl': review['albumImageUrl'],
        'reviewAuthorName': review['displayName'],
        if (commentText != null) 'commentText': commentText,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[ACTIVITY] Failed to record $type on $reviewId: $e');
    }
  }

  Future<void> _remove(String userId, String type, String key) async {
    try {
      await _ref(userId).doc(_docId(type, key)).delete();
    } catch (e) {
      debugPrint('[ACTIVITY] Failed to remove $type $key: $e');
    }
  }
}
