import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for managing review likes
/// Structure: reviewLikes/{reviewId}/likes/{userId}
class ReviewLikesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get the full path to a review like document
  /// reviewId should be in format: users/{userId}/reviews/{reviewId}
  /// We'll use a sanitized version of the path as the document ID
  String _getLikePath(String reviewId, String userId) {
    // Sanitize reviewId to use as document ID (replace / with _)
    final sanitizedReviewId = reviewId.replaceAll('/', '_');
    // Subcollection: likes/{userId}
    return 'reviewLikes/$sanitizedReviewId/likes/$userId';
  }
  
  /// Get the sanitized review ID for the reviewLikes document
  String _getSanitizedReviewId(String reviewId) {
    return reviewId.replaceAll('/', '_');
  }

  /// Like a review
  /// Returns true if successful, false if already liked
  Future<bool> likeReview(String reviewId, String userId) async {
    try {
      final likeRef = _firestore.doc(_getLikePath(reviewId, userId));
      final likeDoc = await likeRef.get();

      if (likeDoc.exists) {
        // Already liked
        return false;
      }

      // Add like
      await likeRef.set({
        'userId': userId,
        'reviewId': reviewId,
        'likedAt': FieldValue.serverTimestamp(),
      });

      // Update like count in reviewLikes document
      final sanitizedId = _getSanitizedReviewId(reviewId);
      await _firestore.doc('reviewLikes/$sanitizedId').set({
        'reviewId': reviewId,
        'likeCount': FieldValue.increment(1),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      print('Error liking review: $e');
      rethrow;
    }
  }

  /// Unlike a review
  /// Returns true if successful, false if not liked
  Future<bool> unlikeReview(String reviewId, String userId) async {
    try {
      final likeRef = _firestore.doc(_getLikePath(reviewId, userId));
      final likeDoc = await likeRef.get();

      if (!likeDoc.exists) {
        // Not liked
        return false;
      }

      // Remove like
      await likeRef.delete();

      // Update like count in reviewLikes document
      final sanitizedId = _getSanitizedReviewId(reviewId);
      await _firestore.doc('reviewLikes/$sanitizedId').set({
        'reviewId': reviewId,
        'likeCount': FieldValue.increment(-1),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      print('Error unliking review: $e');
      rethrow;
    }
  }

  /// Toggle like status (like if not liked, unlike if liked)
  Future<bool> toggleLike(String reviewId, String userId) async {
    try {
      final isLiked = await isReviewLikedByUser(reviewId, userId);
      if (isLiked) {
        return await unlikeReview(reviewId, userId);
      } else {
        return await likeReview(reviewId, userId);
      }
    } catch (e) {
      print('Error toggling like: $e');
      rethrow;
    }
  }

  /// Check if a review is liked by a user
  Future<bool> isReviewLikedByUser(String reviewId, String userId) async {
    try {
      final likeRef = _firestore.doc(_getLikePath(reviewId, userId));
      final likeDoc = await likeRef.get();
      return likeDoc.exists;
    } catch (e) {
      print('Error checking if review is liked: $e');
      return false;
    }
  }

  /// Get like count for a review
  Future<int> getLikeCount(String reviewId) async {
    try {
      final sanitizedId = _getSanitizedReviewId(reviewId);
      final doc = await _firestore.doc('reviewLikes/$sanitizedId').get();
      if (doc.exists && doc.data() != null) {
        return (doc.data()!['likeCount'] as int?) ?? 0;
      }
      return 0;
    } catch (e) {
      print('Error getting like count: $e');
      return 0;
    }
  }

  /// Get stream of like count for a review
  Stream<int> getLikeCountStream(String reviewId) {
    final sanitizedId = _getSanitizedReviewId(reviewId);
    return _firestore
        .doc('reviewLikes/$sanitizedId')
        .snapshots()
        .map((doc) {
          if (doc.exists && doc.data() != null) {
            return (doc.data()!['likeCount'] as int?) ?? 0;
          }
          return 0;
        });
  }

  /// Get stream of user's like status for a review
  Stream<bool> getUserLikeStatusStream(String reviewId, String userId) {
    return _firestore
        .doc(_getLikePath(reviewId, userId))
        .snapshots()
        .map((doc) => doc.exists);
  }

  /// Get the full review ID from a ReviewWithDocId
  /// Format: users/{userId}/reviews/{docId}
  static String getFullReviewId(String userId, String docId) {
    return 'users/$userId/reviews/$docId';
  }

  /// Parse review ID from collection group query result
  /// Path format: users/{userId}/reviews/{reviewId}
  static String parseReviewIdFromPath(String path) {
    // For collection group queries, the path is: users/{userId}/reviews/{reviewId}
    // We'll use the full path as the review ID
    return path;
  }
}
