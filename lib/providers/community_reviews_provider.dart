import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/providers/auth_provider.dart';
import 'package:flutter_test_project/providers/reviews_provider.dart';

/// How many of the newest reviews the Popular tab draws from. The tab shows
/// them in a random order, a page at a time, so this is the whole pool.
const int popularPoolSize = 200;

/// Reviews shorter than this (in characters) are left out of Popular.
const int popularMinReviewLength = 50;

/// Whether a review is good enough to show in Popular: real written text
/// (over [popularMinReviewLength] characters) and album art.
bool isPopularEligible(Review review) =>
    review.review.trim().length > popularMinReviewLength &&
    (review.albumImageUrl?.trim().isNotEmpty ?? false);

/// [reviews] in a random order picked by [seed]. Each review's position
/// depends only on the seed and its own ID, so a live update (a new like, a
/// new review) doesn't reshuffle the cards already on screen.
List<ReviewWithDocId> shuffleReviews(List<ReviewWithDocId> reviews, int seed) {
  double rank(ReviewWithDocId r) =>
      math.Random(Object.hash(seed, r.fullReviewId ?? r.docId)).nextDouble();
  final ranks = {for (final r in reviews) r: rank(r)};
  return [...reviews]..sort((a, b) => ranks[a]!.compareTo(ranks[b]!));
}

/// The Popular pool: the newest [popularPoolSize] community reviews (all
/// users) that pass [isPopularEligible], newest first. The tab shuffles them.
///
/// Reviews are publicly readable — no auth required.
final communityReviewsProvider =
    StreamProvider.autoDispose<List<ReviewWithDocId>>((ref) {
  final userId = ref.watch(currentUserIdProvider);

  debugPrint(
      '[COMMUNITY] Starting collectionGroup stream (limit=$popularPoolSize) userId=${userId ?? 'unauthenticated'}');
  return FirebaseFirestore.instance
      .collectionGroup('reviews')
      .orderBy('date', descending: true)
      .limit(popularPoolSize)
      .snapshots()
      .map((snapshot) {
    debugPrint('[COMMUNITY] Received ${snapshot.docs.length} review docs');
    return snapshot.docs
        .map((doc) {
          try {
            final review = Review.fromFirestore(doc.data());
            // Full path is the review ID for likes: users/{userId}/reviews/{reviewId}
            final fullReviewId = doc.reference.path;

            return ReviewWithDocId(
              review: review,
              docId: doc.id,
              fullReviewId: fullReviewId,
            );
          } catch (e) {
            debugPrint('[COMMUNITY] Error parsing review ${doc.id}: $e');
            return null;
          }
        })
        .whereType<ReviewWithDocId>()
        .where((r) => isPopularEligible(r.review))
        .toList();
  });
});
