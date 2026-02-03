import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/providers/auth_provider.dart';

/// Review with document ID for operations like edit/delete
class ReviewWithDocId {
  final Review review;
  final String docId;
  final String? fullReviewId; // Full path: users/{userId}/reviews/{docId} - for likes
  
  ReviewWithDocId({
    required this.review, 
    required this.docId,
    this.fullReviewId,
  });
}

/// User's reviews stream with document IDs - automatically updates when reviews are added/updated/deleted
final userReviewsProvider = StreamProvider<List<ReviewWithDocId>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  
  if (userId == null) {
    return Stream.value([]);
  }
  
  return FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('reviews')
      .orderBy('date', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) {
            try {
              final review = Review.fromFirestore(doc.data());
              return ReviewWithDocId(review: review, docId: doc.id);
            } catch (e) {
              print('Error parsing review ${doc.id}: $e');
              return null;
            }
          })
          .where((review) => review != null)
          .cast<ReviewWithDocId>()
          .toList());
});

/// Review count for current user
final reviewCountProvider = Provider<int>((ref) {
  final reviewsAsync = ref.watch(userReviewsProvider);
  return reviewsAsync.value?.length ?? 0;
});

/// Get reviews for a specific user (by userId)
final userReviewsByIdProvider = StreamProvider.family<List<Review>, String>((ref, userId) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('reviews')
      .orderBy('date', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) {
            try {
              return Review.fromFirestore(doc.data());
            } catch (e) {
              print('Error parsing review ${doc.id}: $e');
              return null;
            }
          })
          .where((review) => review != null)
          .cast<Review>()
          .toList());
});

/// Firestore instance provider (for dependency injection)
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

/// Provider for submitting reviews - automatically invalidates reviews provider on success
final submitReviewProvider = FutureProvider.family<void, Map<String, dynamic>>((ref, reviewData) async {
  final userId = ref.read(currentUserIdProvider);
  if (userId == null) {
    throw Exception('User must be signed in to submit reviews');
  }
  
  // Import review_helpers function
  // Note: This will be called from the UI, and the provider will auto-invalidate
  // The actual submission logic stays in review_helpers.dart
  // After submission, we invalidate the reviews provider
  ref.invalidate(userReviewsProvider);
});
