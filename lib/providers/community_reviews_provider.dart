import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/providers/auth_provider.dart';
import 'package:flutter_test_project/providers/reviews_provider.dart';

/// Provider for all community reviews (all users) with lazy loading support.
///
/// Depends on [currentUserIdProvider] to ensure the Firestore query only runs
/// after the user is authenticated (Firestore rules require auth).
final communityReviewsProvider = StreamProvider.family<List<ReviewWithDocId>, int>((ref, limit) {
  // Wait for auth — Firestore collectionGroup queries require authentication.
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    debugPrint('[COMMUNITY] No authenticated user — returning empty stream');
    return Stream.value([]);
  }

  debugPrint('[COMMUNITY] Starting collectionGroup stream (limit=$limit) for user=$userId');
  return FirebaseFirestore.instance
      .collectionGroup('reviews')
      .orderBy('date', descending: true)
      .limit(limit)
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
            .where((review) => review != null)
            .cast<ReviewWithDocId>()
            .toList();
      });
});

/// State provider to track the current limit for lazy loading
final communityReviewsLimitProvider = StateProvider<int>((ref) => 20);

/// Function to load more reviews (increases the limit)
final loadMoreCommunityReviewsProvider = Provider<void Function()>((ref) {
  return () {
    final currentLimit = ref.read(communityReviewsLimitProvider);
    ref.read(communityReviewsLimitProvider.notifier).state = currentLimit + 20;
  };
});
