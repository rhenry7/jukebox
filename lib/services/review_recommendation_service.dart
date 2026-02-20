import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test_project/Api/api_key.dart';
import 'package:flutter_test_project/models/enhanced_user_preferences.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/providers/reviews_provider.dart';
import 'package:http/http.dart' as http;

/// A review paired with its recommendation (kept for UI compatibility).
class ScoredReview {
  final ReviewWithDocId reviewWithDocId;
  final double finalScore;
  final double genreScore;
  final double semanticScore;
  final double sentimentScore;
  final double artistScore;
  final double recencyBonus;

  const ScoredReview({
    required this.reviewWithDocId,
    this.finalScore = 0.0,
    this.genreScore = 0.0,
    this.semanticScore = 0.0,
    this.sentimentScore = 0.0,
    this.artistScore = 0.0,
    this.recencyBonus = 0.0,
  });
}

/// Recommendation engine that uses OpenAI to rank community reviews
/// based on the logged-in user's preferences and their own review history.
class ReviewRecommendationService {
  static const _openAiEndpoint = 'https://api.openai.com/v1/chat/completions';
  static const _model = 'gpt-4o-mini';
  static const _timeoutDuration = Duration(seconds: 45);
  static const _maxReviewsToSend = 150; // Limit for token budget
  static const _maxTopN = 50; // Max recommendations to request
  static const _reviewSnippetLength = 120; // Truncate long reviews

  /// Get personalized review recommendations for a user.
  ///
  /// 1. Fetches all community reviews from Firestore.
  /// 2. Fetches user preferences and user's own reviews.
  /// 3. Sends to OpenAI to rank by relevance.
  /// 4. Falls back to genre filter if OpenAI fails or no API key.
  static Future<List<ScoredReview>> getRecommendedReviews(
    String userId, {
    int limit = 400,
  }) async {
    final userPrefs = await _fetchUserPreferences(userId);
    final userOwnReviews = await _fetchUserOwnReviews(userId);
    final allReviews = await _fetchAllReviews(userId, limit);

    if (allReviews.isEmpty) {
      debugPrint('[REC] No community reviews found');
      return [];
    }

    // Try OpenAI first if API key is available
    if (openAIKey.isNotEmpty) {
      try {
        final results = await _getOpenAIRecommendations(
          userId: userId,
          communityReviews: allReviews,
          userPrefs: userPrefs,
          userOwnReviews: userOwnReviews,
        );
        if (results.isNotEmpty) {
          debugPrint('[REC] OpenAI returned ${results.length} recommendations');
          return results;
        }
      } catch (e) {
        debugPrint('[REC] OpenAI failed, falling back to genre filter: $e');
      }
    } else {
      debugPrint('[REC] No OpenAI API key, using genre filter');
    }

    // Fallback: genre-based filter
    return _fallbackGenreFilter(allReviews, userPrefs);
  }

  static Future<List<ScoredReview>> _getOpenAIRecommendations({
    required String userId,
    required List<ReviewWithDocId> communityReviews,
    required EnhancedUserPreferences? userPrefs,
    required List<Review> userOwnReviews,
  }) async {
    // Limit reviews to stay within token budget
    final reviewsToSend = communityReviews.length > _maxReviewsToSend
        ? communityReviews.take(_maxReviewsToSend).toList()
        : communityReviews;

    final prompt = _buildPrompt(
      reviewsToSend: reviewsToSend,
      userPrefs: userPrefs,
      userOwnReviews: userOwnReviews,
    );

    final response = await http
        .post(
          Uri.parse(_openAiEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $openAIKey',
          },
          body: jsonEncode({
            'model': _model,
            'temperature': 0.3,
            'max_tokens': 2000,
            'messages': [
              {
                'role': 'system',
                'content': 'You are a music review recommendation engine. Given a list of community music reviews and a user\'s preferences and review history, return the indices of the most relevant reviews for that user. Respond ONLY with a valid JSON array of integers (0-based indices), ordered from most to least relevant. Example: [3, 12, 0, 45]. Do not include any other text, markdown, or explanation.',
              },
              {'role': 'user', 'content': prompt},
            ],
          }),
        )
        .timeout(_timeoutDuration);

    if (response.statusCode != 200) {
      throw Exception('OpenAI API error: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body);
    final content = (data['choices'] as List?)?.firstOrNull?['message']?['content']?.toString().trim();
    if (content == null || content.isEmpty) {
      throw Exception('Empty OpenAI response');
    }

    final indices = _parseIndicesResponse(content);
    if (indices.isEmpty) return [];

    final results = <ScoredReview>[];
    final seen = <int>{};
    for (final idx in indices) {
      if (idx >= 0 && idx < reviewsToSend.length && seen.add(idx)) {
        results.add(ScoredReview(reviewWithDocId: reviewsToSend[idx]));
        if (results.length >= _maxTopN) break;
      }
    }

    return results;
  }

  static String _buildPrompt({
    required List<ReviewWithDocId> reviewsToSend,
    required EnhancedUserPreferences? userPrefs,
    required List<Review> userOwnReviews,
  }) {
    final prefsSection = userPrefs != null
        ? '''
USER PREFERENCES:
- Favorite Genres: ${userPrefs.favoriteGenres}
- Genre Weights: ${userPrefs.genreWeights}
- Favorite Artists: ${userPrefs.favoriteArtists}
- Disliked Genres: ${userPrefs.dislikedGenres}
'''
        : 'USER PREFERENCES: None set.';

    final userReviewsSection = userOwnReviews.isNotEmpty
        ? '''
USER'S OWN REVIEWS (to understand their taste):
${userOwnReviews.take(10).map((r) => '- "${r.title}" by ${r.artist}: ${r.score}/5 — ${_truncate(r.review, 80)}').join('\n')}
'''
        : "USER'S OWN REVIEWS: None yet.";

    final reviewsList = reviewsToSend.asMap().entries.map((e) {
      final r = e.value.review;
      return '${e.key}: "${r.title}" by ${r.artist} | ${r.score}/5 | genres: ${r.genres ?? []} | review: ${_truncate(r.review, _reviewSnippetLength)}';
    }).join('\n');

    return '''
$prefsSection

$userReviewsSection

COMMUNITY REVIEWS (index: "title" by artist | score | genres | review snippet):
$reviewsList

TASK: Based on the user's preferences and their own review history, return a JSON array of the indices (0-based) of the most relevant reviews for this user. Order from most to least relevant. Return up to $_maxTopN indices. Consider: genre match, artist similarity, review sentiment, and rating patterns.
''';
  }

  static String _truncate(String s, int maxLen) {
    if (s.length <= maxLen) return s;
    return '${s.substring(0, maxLen)}...';
  }

  static List<int> _parseIndicesResponse(String content) {
    try {
      var clean = content
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      // Extract first JSON array
      final start = clean.indexOf('[');
      final end = clean.lastIndexOf(']');
      if (start >= 0 && end > start) {
        clean = clean.substring(start, end + 1);
      }
      final decoded = jsonDecode(clean);
      if (decoded is! List) return [];
      return decoded
          .map((e) => e is int ? e : (e is num ? e.toInt() : null))
          .whereType<int>()
          .toList();
    } catch (e) {
      debugPrint('[REC] Failed to parse OpenAI indices: $e');
      return [];
    }
  }

  static List<ScoredReview> _fallbackGenreFilter(
    List<ReviewWithDocId> allReviews,
    EnhancedUserPreferences? userPrefs,
  ) {
    const minRating = 3.5;
    final likedGenres = _extractLikedGenres(userPrefs);
    if (likedGenres.isEmpty) return allReviews.take(50).map((rw) => ScoredReview(reviewWithDocId: rw)).toList();

    final results = <ScoredReview>[];
    for (final rw in allReviews) {
      final r = rw.review;
      if (r.score >= minRating && _hasGenreMatch(r, likedGenres)) {
        results.add(ScoredReview(reviewWithDocId: rw));
      }
    }
    results.sort((a, b) {
      final da = a.reviewWithDocId.review.date;
      final db = b.reviewWithDocId.review.date;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });
    return results.take(50).toList();
  }

  static Set<String> _extractLikedGenres(EnhancedUserPreferences? prefs) {
    if (prefs == null) return {};
    final genres = <String>{};
    for (final g in prefs.favoriteGenres) {
      final k = g.toLowerCase().trim();
      if (k.isNotEmpty) genres.add(k);
    }
    for (final k in prefs.genreWeights.keys) {
      final key = k.toLowerCase().trim();
      if (key.isNotEmpty && (prefs.genreWeights[k] ?? 0) > 0) genres.add(key);
    }
    return genres;
  }

  static bool _hasGenreMatch(Review review, Set<String> likedGenres) {
    final rg = (review.genres ?? <String>[])
        .map((g) => g.toLowerCase().trim())
        .where((g) => g.isNotEmpty)
        .toSet();
    for (final r in rg) {
      for (final l in likedGenres) {
        if (r == l || r.contains(l) || l.contains(r)) return true;
      }
    }
    return false;
  }

  static Future<List<ReviewWithDocId>> _fetchAllReviews(String userId, int limit) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collectionGroup('reviews')
          .orderBy('date', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) {
            try {
              final review = Review.fromFirestore(doc.data());
              if (review.userId == userId) return null;
              return ReviewWithDocId(
                review: review,
                docId: doc.id,
                fullReviewId: doc.reference.path,
              );
            } catch (e) {
              debugPrint('[REC] Error parsing review ${doc.id}: $e');
              return null;
            }
          })
          .where((r) => r != null)
          .cast<ReviewWithDocId>()
          .toList();
    } catch (e) {
      debugPrint('[REC] Error fetching reviews: $e');
      return [];
    }
  }

  static Future<List<Review>> _fetchUserOwnReviews(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reviews')
          .orderBy('date', descending: true)
          .limit(20)
          .get();

      return snapshot.docs
          .map((doc) => Review.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('[REC] Error fetching user reviews: $e');
      return [];
    }
  }

  static Future<EnhancedUserPreferences?> _fetchUserPreferences(String userId) async {
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
      debugPrint('[REC] Error fetching preferences: $e');
      return null;
    }
  }

  /// No-op: caching removed. Kept for API compatibility (e.g. MusicTaste).
  static Future<void> clearRecommendationsCache(String userId) async {}
}
