import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/review_comment.dart';
import 'auth_provider.dart' show currentUserIdProvider;
import '../services/review_comments_service.dart';

/// A review's comments. Only signed-in users may read them (Firestore
/// rules), so signed out this is empty without asking; screens show a
/// sign-in prompt instead (check `currentUserIdProvider`).
final reviewCommentsProvider =
    StreamProvider.autoDispose.family<List<ReviewComment>, String>((ref, reviewId) {
  if (ref.watch(currentUserIdProvider) == null) {
    return Stream.value(const <ReviewComment>[]);
  }
  return ReviewCommentsService().commentsStream(reviewId);
});

// Key: (reviewId, commentId, userId) packed as a record
typedef _CommentLikeKey = ({
  String reviewId,
  String commentId,
  String userId
});

final commentLikeStatusProvider =
    StreamProvider.autoDispose.family<bool, _CommentLikeKey>((ref, key) {
  return ReviewCommentsService().commentLikeStream(
    key.reviewId,
    key.commentId,
    key.userId,
  );
});
