import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/providers/auth_provider.dart';
import 'package:flutter_test_project/services/review_likes_service.dart';

/// Provider for like count of a review
/// reviewId should be the full path: users/{userId}/reviews/{reviewId}
final reviewLikeCountProvider = StreamProvider.family<int, String>((ref, reviewId) {
  final service = ReviewLikesService();
  return service.getLikeCountStream(reviewId);
});

/// Provider for user's like status on a review
final reviewUserLikeStatusProvider = StreamProvider.family<bool, String>((ref, reviewId) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return Stream.value(false);
  }
  final service = ReviewLikesService();
  return service.getUserLikeStatusStream(reviewId, userId);
});

/// Provider to get full review ID from userId and docId
final fullReviewIdProvider = Provider.family<String, ({String userId, String docId})>((ref, params) {
  return ReviewLikesService.getFullReviewId(params.userId, params.docId);
});
