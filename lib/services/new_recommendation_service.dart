import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test_project/models/enhanced_user_preferences.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/providers/reviews_provider.dart';
import 'package:flutter_test_project/services/review_recommendation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple recommendation service for "For You".
///
/// Behavior:
/// - Pull all community reviews (no cache).
/// - Filter to reviews that match at least one favorite genre.
class NewRecommendationService {
  static const String _cacheKeyPrefix = 'for_you_review_recs_v1';

  static Future<List<ScoredReview>> getRecommendedReviews(
    String userId, {
    int topN = 200,
    bool forceRefresh = false,
  }) async {
    final userPrefs = await _fetchUserPreferences(userId);
    final preferencesSignature = _buildPreferencesSignature(userPrefs);

    if (!forceRefresh) {
      final cached = await _loadCachedRecommendations(
        userId: userId,
        preferencesSignature: preferencesSignature,
      );
      if (cached != null) {
        debugPrint('[NEW_REC] Using local cached recommendations (${cached.length})');
        return cached;
      }
    }

    final favoriteGenres = _extractFavoriteGenres(userPrefs);

    if (favoriteGenres.isEmpty) {
      debugPrint('[NEW_REC] No favoriteGenres found for user=$userId');
      await _saveCachedRecommendations(
        userId: userId,
        preferencesSignature: preferencesSignature,
        recommendations: const <ScoredReview>[],
      );
      return [];
    }

    final allReviews = await _fetchAllCommunityReviews(userId);
    if (allReviews.isEmpty) {
      debugPrint('[NEW_REC] No community reviews found');
      await _saveCachedRecommendations(
        userId: userId,
        preferencesSignature: preferencesSignature,
        recommendations: const <ScoredReview>[],
      );
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
    await _saveCachedRecommendations(
      userId: userId,
      preferencesSignature: preferencesSignature,
      recommendations: results,
    );
    debugPrint(
      '[NEW_REC] Returning ${results.length} recommendations '
      '(from ${allReviews.length} reviews, favorites=${favoriteGenres.length})',
    );
    return results;
  }

  static Future<void> clearLocalCache(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_cacheKeyPrefix|$userId');
      debugPrint('[NEW_REC] Cleared local recommendation cache for user=$userId');
    } catch (e) {
      debugPrint('[NEW_REC] Error clearing local cache: $e');
    }
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

  static String _buildPreferencesSignature(EnhancedUserPreferences? prefs) {
    if (prefs == null) return 'none';

    final favoriteGenres = prefs.favoriteGenres
        .map(_normalizeGenre)
        .where((g) => g.isNotEmpty)
        .toList()
      ..sort();
    final dislikedGenres = prefs.dislikedGenres
        .map(_normalizeGenre)
        .where((g) => g.isNotEmpty)
        .toList()
      ..sort();
    final weighted = prefs.genreWeights.entries
        .map((e) => '${_normalizeGenre(e.key)}:${e.value.toStringAsFixed(3)}')
        .toList()
      ..sort();

    return 'f=${favoriteGenres.join(",")};d=${dislikedGenres.join(",")};w=${weighted.join(",")}';
  }

  static Future<List<ScoredReview>?> _loadCachedRecommendations({
    required String userId,
    required String preferencesSignature,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('$_cacheKeyPrefix|$userId');
      if (jsonString == null || jsonString.isEmpty) return null;

      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) return null;

      final cachedSig = decoded['preferencesSignature'] as String?;
      if (cachedSig != preferencesSignature) return null;

      final items = decoded['items'] as List<dynamic>?;
      if (items == null) return null;

      return items.map((item) {
        final map = item as Map<String, dynamic>;
        final reviewMap = map['review'] as Map<String, dynamic>;
        final review = Review.fromJson(reviewMap);
        return ScoredReview(
          reviewWithDocId: ReviewWithDocId(
            review: review,
            docId: map['docId'] as String? ?? '',
            fullReviewId: map['fullReviewId'] as String?,
          ),
          finalScore: (map['finalScore'] as num?)?.toDouble() ?? 0.0,
          genreScore: (map['genreScore'] as num?)?.toDouble() ?? 0.0,
          semanticScore: (map['semanticScore'] as num?)?.toDouble() ?? 0.0,
          sentimentScore: (map['sentimentScore'] as num?)?.toDouble() ?? 0.0,
          artistScore: (map['artistScore'] as num?)?.toDouble() ?? 0.0,
          recencyBonus: (map['recencyBonus'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList();
    } catch (e) {
      debugPrint('[NEW_REC] Error loading local cache: $e');
      return null;
    }
  }

  static Future<void> _saveCachedRecommendations({
    required String userId,
    required String preferencesSignature,
    required List<ScoredReview> recommendations,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final items = recommendations.map((sr) {
        final r = sr.reviewWithDocId.review;
        return <String, dynamic>{
          'review': r.toJson(),
          'docId': sr.reviewWithDocId.docId,
          'fullReviewId': sr.reviewWithDocId.fullReviewId,
          'finalScore': sr.finalScore,
          'genreScore': sr.genreScore,
          'semanticScore': sr.semanticScore,
          'sentimentScore': sr.sentimentScore,
          'artistScore': sr.artistScore,
          'recencyBonus': sr.recencyBonus,
        };
      }).toList();

      final payload = <String, dynamic>{
        'preferencesSignature': preferencesSignature,
        'updatedAt': DateTime.now().toIso8601String(),
        'items': items,
      };
      await prefs.setString('$_cacheKeyPrefix|$userId', jsonEncode(payload));
    } catch (e) {
      debugPrint('[NEW_REC] Error saving local cache: $e');
    }
  }
}
