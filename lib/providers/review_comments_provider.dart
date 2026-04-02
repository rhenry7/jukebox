import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/review_comment.dart';
import '../services/review_comments_service.dart';

final reviewCommentsProvider =
    StreamProvider.family<List<ReviewComment>, String>((ref, reviewId) {
  return ReviewCommentsService().commentsStream(reviewId);
});

// Key: (reviewId, commentId, userId) packed as a record
typedef _CommentLikeKey = ({
  String reviewId,
  String commentId,
  String userId
});

final commentLikeStatusProvider =
    StreamProvider.family<bool, _CommentLikeKey>((ref, key) {
  return ReviewCommentsService().commentLikeStream(
    key.reviewId,
    key.commentId,
    key.userId,
  );
});
