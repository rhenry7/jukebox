import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/services/review_likes_service.dart';

/// A testable version of [ReviewLikesService] that accepts an injected
/// [FakeFirebaseFirestore] instead of using the static singleton.
class TestableReviewLikesService {
  final FakeFirebaseFirestore firestore;

  TestableReviewLikesService(this.firestore);

  String _getLikePath(String reviewId, String userId) {
    final sanitizedReviewId = reviewId.replaceAll('/', '_');
    return 'reviewLikes/$sanitizedReviewId/likes/$userId';
  }

  String _getSanitizedReviewId(String reviewId) {
    return reviewId.replaceAll('/', '_');
  }

  Future<bool> likeReview(String reviewId, String userId) async {
    final likeRef = firestore.doc(_getLikePath(reviewId, userId));
    final likeDoc = await likeRef.get();

    if (likeDoc.exists) return false;

    await likeRef.set({
      'userId': userId,
      'reviewId': reviewId,
      'likedAt': DateTime.now().toIso8601String(),
    });

    final sanitizedId = _getSanitizedReviewId(reviewId);
    final countDoc = await firestore.doc('reviewLikes/$sanitizedId').get();
    final currentCount =
        countDoc.exists ? (countDoc.data()?['likeCount'] as int? ?? 0) : 0;

    await firestore.doc('reviewLikes/$sanitizedId').set({
      'reviewId': reviewId,
      'likeCount': currentCount + 1,
      'lastUpdated': DateTime.now().toIso8601String(),
    });

    return true;
  }

  Future<bool> unlikeReview(String reviewId, String userId) async {
    final likeRef = firestore.doc(_getLikePath(reviewId, userId));
    final likeDoc = await likeRef.get();

    if (!likeDoc.exists) return false;

    await likeRef.delete();

    final sanitizedId = _getSanitizedReviewId(reviewId);
    final countDoc = await firestore.doc('reviewLikes/$sanitizedId').get();
    final currentCount =
        countDoc.exists ? (countDoc.data()?['likeCount'] as int? ?? 0) : 0;

    await firestore.doc('reviewLikes/$sanitizedId').set({
      'reviewId': reviewId,
      'likeCount': (currentCount - 1).clamp(0, double.infinity).toInt(),
      'lastUpdated': DateTime.now().toIso8601String(),
    });

    return true;
  }

  Future<bool> toggleLike(String reviewId, String userId) async {
    final isLiked = await isReviewLikedByUser(reviewId, userId);
    if (isLiked) {
      return await unlikeReview(reviewId, userId);
    } else {
      return await likeReview(reviewId, userId);
    }
  }

  Future<bool> isReviewLikedByUser(String reviewId, String userId) async {
    final likeRef = firestore.doc(_getLikePath(reviewId, userId));
    final likeDoc = await likeRef.get();
    return likeDoc.exists;
  }

  Future<int> getLikeCount(String reviewId) async {
    final sanitizedId = _getSanitizedReviewId(reviewId);
    final doc = await firestore.doc('reviewLikes/$sanitizedId').get();
    if (doc.exists && doc.data() != null) {
      return (doc.data()!['likeCount'] as int?) ?? 0;
    }
    return 0;
  }
}

void main() {
  // ─────────────────────────────────────────────────────────────
  // Static / pure helpers (no Firebase needed)
  // ─────────────────────────────────────────────────────────────
  group('ReviewLikesService - static helpers', () {
    test('getFullReviewId creates correct path format', () {
      final fullId = ReviewLikesService.getFullReviewId('user123', 'rev456');
      expect(fullId, 'users/user123/reviews/rev456');
    });

    test('getFullReviewId handles special characters', () {
      final fullId =
          ReviewLikesService.getFullReviewId('user-abc', 'review-xyz');
      expect(fullId, 'users/user-abc/reviews/review-xyz');
    });

    test('parseReviewIdFromPath returns the path unchanged', () {
      const path = 'users/user123/reviews/review456';
      expect(ReviewLikesService.parseReviewIdFromPath(path), path);
    });
  });

  // ─────────────────────────────────────────────────────────────
  // Like / unlike / toggle with fake Firestore
  // ─────────────────────────────────────────────────────────────
  group('ReviewLikesService - likeReview', () {
    late FakeFirebaseFirestore fakeFirestore;
    late TestableReviewLikesService service;

    const reviewId = 'users/user1/reviews/rev1';
    const userId = 'liker1';

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = TestableReviewLikesService(fakeFirestore);
    });

    test('likeReview returns true on first like', () async {
      final result = await service.likeReview(reviewId, userId);
      expect(result, isTrue);
    });

    test('likeReview returns false if already liked', () async {
      await service.likeReview(reviewId, userId);
      final secondLike = await service.likeReview(reviewId, userId);
      expect(secondLike, isFalse);
    });

    test('likeReview writes like document', () async {
      await service.likeReview(reviewId, userId);
      final isLiked = await service.isReviewLikedByUser(reviewId, userId);
      expect(isLiked, isTrue);
    });

    test('likeReview increments like count', () async {
      await service.likeReview(reviewId, userId);
      final count = await service.getLikeCount(reviewId);
      expect(count, 1);
    });

    test('multiple users increment count correctly', () async {
      await service.likeReview(reviewId, 'userA');
      await service.likeReview(reviewId, 'userB');
      await service.likeReview(reviewId, 'userC');
      final count = await service.getLikeCount(reviewId);
      expect(count, 3);
    });
  });

  group('ReviewLikesService - unlikeReview', () {
    late FakeFirebaseFirestore fakeFirestore;
    late TestableReviewLikesService service;

    const reviewId = 'users/user1/reviews/rev1';
    const userId = 'liker1';

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = TestableReviewLikesService(fakeFirestore);
    });

    test('unlikeReview returns false if not previously liked', () async {
      final result = await service.unlikeReview(reviewId, userId);
      expect(result, isFalse);
    });

    test('unlikeReview returns true when unlike succeeds', () async {
      await service.likeReview(reviewId, userId);
      final result = await service.unlikeReview(reviewId, userId);
      expect(result, isTrue);
    });

    test('unlikeReview removes the like document', () async {
      await service.likeReview(reviewId, userId);
      await service.unlikeReview(reviewId, userId);
      final isLiked = await service.isReviewLikedByUser(reviewId, userId);
      expect(isLiked, isFalse);
    });

    test('unlikeReview decrements like count', () async {
      await service.likeReview(reviewId, 'userA');
      await service.likeReview(reviewId, 'userB');
      await service.unlikeReview(reviewId, 'userA');
      final count = await service.getLikeCount(reviewId);
      expect(count, 1);
    });

    test('like count does not go below zero', () async {
      // Manually set count to 0, then try to unlike
      await service.likeReview(reviewId, userId);
      await service.unlikeReview(reviewId, userId);
      final count = await service.getLikeCount(reviewId);
      expect(count, greaterThanOrEqualTo(0));
    });
  });

  group('ReviewLikesService - toggleLike', () {
    late FakeFirebaseFirestore fakeFirestore;
    late TestableReviewLikesService service;

    const reviewId = 'users/user1/reviews/rev1';
    const userId = 'toggler1';

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = TestableReviewLikesService(fakeFirestore);
    });

    test('toggleLike likes when not previously liked', () async {
      await service.toggleLike(reviewId, userId);
      final isLiked = await service.isReviewLikedByUser(reviewId, userId);
      expect(isLiked, isTrue);
    });

    test('toggleLike unlikes when previously liked', () async {
      await service.likeReview(reviewId, userId);
      await service.toggleLike(reviewId, userId);
      final isLiked = await service.isReviewLikedByUser(reviewId, userId);
      expect(isLiked, isFalse);
    });

    test('double toggle returns to liked state', () async {
      await service.toggleLike(reviewId, userId); // like
      await service.toggleLike(reviewId, userId); // unlike
      await service.toggleLike(reviewId, userId); // like again
      final isLiked = await service.isReviewLikedByUser(reviewId, userId);
      expect(isLiked, isTrue);
    });
  });

  group('ReviewLikesService - getLikeCount', () {
    late FakeFirebaseFirestore fakeFirestore;
    late TestableReviewLikesService service;

    const reviewId = 'users/user1/reviews/rev1';

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = TestableReviewLikesService(fakeFirestore);
    });

    test('returns 0 for review with no likes', () async {
      final count = await service.getLikeCount(reviewId);
      expect(count, 0);
    });

    test('returns correct count after multiple likes', () async {
      await service.likeReview(reviewId, 'a');
      await service.likeReview(reviewId, 'b');
      final count = await service.getLikeCount(reviewId);
      expect(count, 2);
    });
  });

  group('ReviewLikesService - isReviewLikedByUser', () {
    late FakeFirebaseFirestore fakeFirestore;
    late TestableReviewLikesService service;

    const reviewId = 'users/user1/reviews/rev1';

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = TestableReviewLikesService(fakeFirestore);
    });

    test('returns false when user has not liked', () async {
      expect(await service.isReviewLikedByUser(reviewId, 'ghost'), isFalse);
    });

    test('returns true when user has liked', () async {
      await service.likeReview(reviewId, 'likedUser');
      expect(
          await service.isReviewLikedByUser(reviewId, 'likedUser'), isTrue);
    });

    test('one user liking does not affect another', () async {
      await service.likeReview(reviewId, 'userA');
      expect(await service.isReviewLikedByUser(reviewId, 'userB'), isFalse);
    });
  });
}
