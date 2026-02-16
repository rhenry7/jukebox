import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test_project/models/enhanced_user_preferences.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/providers/reviews_provider.dart';
import 'package:flutter_test_project/services/review_recommendation_service.dart';

/// Simple recommendation service for "For You".
///
/// Behavior:
/// - Pull all community reviews (no cache).
/// - Filter to reviews that match at least one favorite genre.
class NewRecommendationService {
  static Future<List<ScoredReview>> getRecommendedReviews(
    String userId, {
    int topN = 200,
  }) async {
    final userPrefs = await _fetchUserPreferences(userId);
    final favoriteGenres = _extractFavoriteGenres(userPrefs);

    if (favoriteGenres.isEmpty) {
      debugPrint('[NEW_REC] No favoriteGenres found for user=$userId');
      return [];
    }

    final allReviews = await _fetchAllCommunityReviews(userId);
    if (allReviews.isEmpty) {
      debugPrint('[NEW_REC] No community reviews found');
      return [];
    }

    final matched = <ScoredReview>[];
    for (final reviewWithDocId in allReviews) {
      final review = reviewWithDocId.review;
      final reviewGenres = _extractReviewGenres(review);

      final matchedCount = favoriteGenres
          .where((favorite) => reviewGenres.any((g) => _isGenreMatch(favorite, g)))
          .length;
      if (matchedCount == 0) continue;

      final genreScore = (matchedCount / favoriteGenres.length).clamp(0.0, 1.0);
      final ratingScore = (review.score / 5.0).clamp(0.0, 1.0);
      final finalScore = (genreScore * 0.8) + (ratingScore * 0.2);

      matched.add(
        ScoredReview(
          reviewWithDocId: reviewWithDocId,
          finalScore: finalScore,
          genreScore: genreScore,
        ),
      );
    }

    matched.sort((a, b) {
      final scoreCmp = b.finalScore.compareTo(a.finalScore);
      if (scoreCmp != 0) return scoreCmp;
      final dateA = a.reviewWithDocId.review.date;
      final dateB = b.reviewWithDocId.review.date;
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA);
    });

    final results = matched.take(topN).toList();
    debugPrint(
      '[NEW_REC] Returning ${results.length} recommendations '
      '(from ${allReviews.length} reviews, favorites=${favoriteGenres.length})',
    );
    return results;
  }

  static Future<EnhancedUserPreferences?> _fetchUserPreferences(
    String userId,
  ) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('musicPreferences')
          .doc('profile')
          .get();

      if (!doc.exists || doc.data() == null) return null;
      return EnhancedUserPreferences.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('[NEW_REC] Error fetching user preferences: $e');
      return null;
    }
  }

  static Set<String> _extractFavoriteGenres(EnhancedUserPreferences? prefs) {
    if (prefs == null) return <String>{};

    final favorites = prefs.favoriteGenres
        .map(_normalizeGenre)
        .where((g) => g.isNotEmpty)
        .toSet();

    // Fallback to strong genre weights to keep matching resilient even if
    // favoriteGenres list is out of sync.
    final weightedFavorites = prefs.genreWeights.entries
        .where((e) => e.value >= 0.6)
        .map((e) => _normalizeGenre(e.key))
        .where((g) => g.isNotEmpty)
        .toSet();

    return {...favorites, ...weightedFavorites};
  }

  static Future<List<ReviewWithDocId>> _fetchAllCommunityReviews(
    String userId,
  ) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collectionGroup('reviews')
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs
          .map((doc) {
            try {
              final review = Review.fromFirestore(doc.data());
              // Keep behavior aligned with community tab: include all reviews.
              return ReviewWithDocId(
                review: review,
                docId: doc.id,
                fullReviewId: doc.reference.path,
              );
            } catch (_) {
              return null;
            }
          })
          .where((r) => r != null)
          .cast<ReviewWithDocId>()
          .toList();
    } catch (e) {
      debugPrint('[NEW_REC] Error fetching community reviews: $e');
      return [];
    }
  }

  static Set<String> _extractReviewGenres(Review review) {
    return <String>{
      ...(review.genres ?? const <String>[]),
      ...(review.tags ?? const <String>[]),
    }.map(_normalizeGenre).where((g) => g.isNotEmpty).toSet();
  }

  static bool _isGenreMatch(String favoriteGenre, String reviewGenre) {
    return favoriteGenre == reviewGenre ||
        favoriteGenre.contains(reviewGenre) ||
        reviewGenre.contains(favoriteGenre);
  }

  static String _normalizeGenre(String input) {
    final lower = input.toLowerCase().trim();
    return lower.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }
}
