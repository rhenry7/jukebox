import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/providers/auth_provider.dart';
import 'package:flutter_test_project/providers/reviews_provider.dart';

/// Parameter record for the album reviews family provider.
typedef AlbumReviewsParam = ({String artist, String title});

/// Fetches all community reviews matching a given (artist, title) pair.
///
/// Reuses the existing `collectionGroup('reviews')` index (same as
/// [communityReviewsProvider] and [ReviewRecommendationService]), then
/// filters client-side by normalized artist + title. No new Firestore
/// indexes required.
final albumReviewsProvider =
    FutureProvider.family<List<ReviewWithDocId>, AlbumReviewsParam>(
        (ref, param) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  debugPrint(
      '[ALBUM_REVIEWS] Fetching reviews for "${param.title}" by ${param.artist}');

  final snapshot = await FirebaseFirestore.instance
      .collectionGroup('reviews')
      .orderBy('date', descending: true)
      .limit(400)
      .get();

  final normalizedArtist = param.artist.trim().toLowerCase();
  final normalizedTitle = param.title.trim().toLowerCase();

  final results = snapshot.docs
      .map((doc) {
        try {
          final review = Review.fromFirestore(doc.data());
          if (review.artist.trim().toLowerCase() != normalizedArtist) {
            return null;
          }
          if (review.title.trim().toLowerCase() != normalizedTitle) return null;
          return ReviewWithDocId(
            review: review,
            docId: doc.id,
            fullReviewId: doc.reference.path,
          );
        } catch (e) {
          debugPrint('[ALBUM_REVIEWS] Error parsing review ${doc.id}: $e');
          return null;
        }
      })
      .whereType<ReviewWithDocId>()
      .toList();

  debugPrint('[ALBUM_REVIEWS] Found ${results.length} reviews');
  return results;
});
