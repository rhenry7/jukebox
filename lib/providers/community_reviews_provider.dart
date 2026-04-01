import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/providers/auth_provider.dart';
import 'package:flutter_test_project/providers/reviews_provider.dart';

/// Provider for all community reviews (all users) with lazy loading support.
///
/// Anonymous sign-in is handled at app startup (main.dart) so that Firestore
/// auth rules are satisfied before this provider first runs.
final communityReviewsProvider = StreamProvider.family<List<ReviewWithDocId>, int>((ref, limit) {
  final userId = ref.watch(currentUserIdProvider);

  // No auth session yet — keep showing loading until the auth state resolves.
  if (userId == null) {
    debugPrint('[COMMUNITY] Waiting for auth session...');
    return const Stream.empty();
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
