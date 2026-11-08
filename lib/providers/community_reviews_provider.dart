import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/providers/cache_first.dart';
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

/// On a first visit (nothing cached), how many of the newest reviews Popular
/// shows before the rest of the pool arrives.
const int popularFirstBatch = 10;

/// [reviews] in the order the Popular tab shows them: reviews already placed
/// ([placedIds], in order) keep their places, so cards on screen never jump
/// when more of the pool arrives; new ones follow, shuffled by [seed].
List<ReviewWithDocId> keepPlacedOrder(
  List<ReviewWithDocId> reviews,
  List<String> placedIds,
  int seed,
) {
  String id(ReviewWithDocId r) => r.fullReviewId ?? r.docId;
  final byId = {for (final r in reviews) id(r): r};
  final placed = [
    for (final placedId in placedIds)
      if (byId.remove(placedId) case final review?) review,
  ];
  return [...placed, ...shuffleReviews(byId.values.toList(), seed)];
}

/// The Popular pool: the newest [popularPoolSize] community reviews (all
/// users) that pass [isPopularEligible], newest first. The tab shuffles them.
///
/// Read once, not kept live: a live listener on 200 reviews re-sent changes
/// all the time. Pull-to-refresh, the Home re-tap and posting a review
/// re-read it (`ref.invalidate`). Comes in stages so cards show early:
///  - a repeat visit shows the on-device copy (when it holds most of the
///    pool), then the server's;
///  - a first visit shows the newest [popularFirstBatch] as soon as they
///    arrive, then the whole pool.
/// Kept for a few minutes after the tab closes.
///
/// Reviews are publicly readable — no auth required.
final communityReviewsProvider =
    StreamProvider.autoDispose<List<ReviewWithDocId>>((ref) async* {
  final userId = ref.watch(currentUserIdProvider);
  ref.keepAliveFor();

  debugPrint(
      '[COMMUNITY] Reading the Popular pool (limit=$popularPoolSize) userId=${userId ?? 'unauthenticated'}');
  final query = FirebaseFirestore.instance
      .collectionGroup('reviews')
      .orderBy('date', descending: true);
  final pool = query.limit(popularPoolSize);

  var shown = false;
  try {
    final cached = await pool.get(const GetOptions(source: Source.cache));
    // A cache holding only a few of the 200 would show a thin feed, so
    // only use it when it holds most of the pool.
    if (cached.docs.length >= popularPoolSize ~/ 2) {
      yield _popularFrom(cached);
      shown = true;
    }
  } catch (_) {
    // Nothing cached.
  }
  if (!shown) {
    try {
      final first = _popularFrom(await query.limit(popularFirstBatch).get());
      if (first.isNotEmpty) {
        yield first;
        shown = true;
      }
    } catch (e) {
      debugPrint('[COMMUNITY] First batch failed: $e');
    }
  }
  try {
    yield _popularFrom(await pool.get());
  } catch (e) {
    if (!shown) rethrow;
    debugPrint('[COMMUNITY] Pool read failed; keeping what is shown: $e');
  }
});

List<ReviewWithDocId> _popularFrom(
    QuerySnapshot<Map<String, dynamic>> snapshot) {
  debugPrint('[COMMUNITY] Received ${snapshot.docs.length} review docs');
  return snapshot.docs
      .map((doc) {
        try {
          // Full path is the review ID for likes: users/{userId}/reviews/{reviewId}
          return ReviewWithDocId(
            review: Review.fromFirestore(doc.data()),
            docId: doc.id,
            fullReviewId: doc.reference.path,
          );
        } catch (e) {
          debugPrint('[COMMUNITY] Error parsing review ${doc.id}: $e');
          return null;
        }
      })
      .whereType<ReviewWithDocId>()
      .where((r) => isPopularEligible(r.review))
      .toList();
}
