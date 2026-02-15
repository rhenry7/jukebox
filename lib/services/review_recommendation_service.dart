import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test_project/models/enhanced_user_preferences.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/providers/reviews_provider.dart';
import 'package:flutter_test_project/services/embedding_service.dart';
import 'package:flutter_test_project/services/recommendation_outcome_service.dart';
import 'package:flutter_test_project/services/review_analysis_service.dart';
import 'package:flutter_test_project/utils/scoring_utils.dart';

/// A review paired with its recommendation scoring breakdown.
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
    required this.finalScore,
    this.genreScore = 0.0,
    this.semanticScore = 0.0,
    this.sentimentScore = 0.0,
    this.artistScore = 0.0,
    this.recencyBonus = 0.0,
  });
}

/// Core recommendation engine that surfaces community reviews
/// semantically matched to the user's taste profile.
class ReviewRecommendationService {
  static const _cacheTtl = Duration(hours: 1);

  // Sentiment word lists (same as ReviewAnalysisService._analyzeReviewSentiment)
  static const _positiveWords = [
    'love',
    'amazing',
    'perfect',
    'beautiful',
    'loved',
    'great',
    'excellent',
    'incredible',
    'best',
    'fantastic',
    'wonderful',
    'brilliant',
    'masterpiece',
  ];
  static const _negativeWords = [
    'boring',
    'overrated',
    'disappointing',
    'hated'
        'bad',
    'terrible',
    'awful',
    'worst',
    'hate',
    'dislike',
    'mediocre',
    'weak',
  ];

  /// Get personalized review recommendations for a user.
  ///
  /// 1. Checks Firestore cache (1-hour TTL).
  /// 2. Fetches user taste profile + taste vector (both already cached).
  /// 3. Fetches candidate pool via collectionGroup query.
  /// 4. Scores each candidate across 5 dimensions.
  /// 5. Returns top-N sorted by final score.
  static Future<List<ScoredReview>> getRecommendedReviews(
    String userId, {
    int candidatePoolSize = 100,
    int topN = 20,
    bool forceRefresh = true,
  }) async {
    // 1. Check cache
    if (!forceRefresh) {
      final cached = await _getCachedRecommendations(userId);
      if (cached != null) {
        debugPrint(
            '[REC] Using cached recommendations (${cached.length} items)');
        return cached;
      }
    }

    // 2. Fetch user taste profile
    final profile = await ReviewAnalysisService.analyzeUserReviews(userId);

    // 2b. Fetch user genre interest preferences
    final userPrefs = await _fetchUserPreferences(userId);

    // 3. Fetch user taste vector (may be null if no API key or no reviews)
    final userReviews = await _fetchUserReviews(userId);
    List<double>? tasteVector;
    if (userReviews.isNotEmpty) {
      tasteVector = await EmbeddingService.getTasteVector(userId, userReviews);
    }

    // 4. Fetch candidate pool
    final candidates = await _fetchCandidateReviews(userId, candidatePoolSize);
    if (candidates.isEmpty) {
      debugPrint('[REC] No candidate reviews found');
      return [];
    }

    // 5. Get feedback-calibrated weights
    final weights = await RecommendationOutcomeService.getAdjustedWeights();

    // 6. Compute semantic scores in batch
    final userSentiment = profile.reviewSentiment.sentimentScore;

    List<double> semanticScores;
    if (tasteVector != null) {
      final tv = tasteVector; // Local non-null capture for closure
      final candidateTexts = candidates.map((c) {
        final r = c.review;
        return '${r.artist} - ${r.title}. ${r.review}'.trim();
      }).toList();

      final embeddings =
          await EmbeddingService.generateBatchEmbeddings(candidateTexts);

      semanticScores = embeddings.map((embedding) {
        if (embedding == null) return 0.5;
        final cosine = ScoringUtils.cosineSimilarity(tv, embedding);
        return ((cosine + 1.0) / 2.0).clamp(0.0, 1.0);
      }).toList();
    } else {
      semanticScores = List.filled(candidates.length, 0.5);
    }

    // 7. Score each candidate
    final scored = <ScoredReview>[];
    for (int i = 0; i < candidates.length; i++) {
      final candidate = candidates[i];
      final review = candidate.review;

      // Genre overlap (rating-weighted + active interest)
      final candidateGenres = (review.genres ?? []).toSet();
      final genreScore = _computeWeightedGenreScore(
        candidateGenres: candidateGenres,
        genrePreferences: profile.genrePreferences,
        userPrefs: userPrefs,
        candidateReviewScore: review.score,
      );

      // Semantic similarity (already computed)
      final semanticScore = semanticScores[i];

      // Sentiment alignment
      final candidateSentiment = _computeSentiment(review.review);
      final sentimentScore = 1.0 - (userSentiment - candidateSentiment).abs();

      // Artist preference
      final artistScore =
          profile.artistPreferences[review.artist]?.preferenceScore ?? 0.0;

      // Recency bonus
      final recencyBonus = review.date != null
          ? ScoringUtils.temporalDecay(review.date!, halfLifeDays: 30)
          : 0.0;

      // Combine via finalRelevanceScore
      final finalScore = ScoringUtils.finalRelevanceScore(
        signalScore: artistScore,
        collaborativeScore: genreScore,
        semanticScore: semanticScore,
        noveltyScore: recencyBonus,
        diversityBonus: sentimentScore * 0.5,
        componentWeights: weights,
      );

      scored.add(ScoredReview(
        reviewWithDocId: candidate,
        finalScore: finalScore,
        genreScore: genreScore,
        semanticScore: semanticScore,
        sentimentScore: sentimentScore,
        artistScore: artistScore,
        recencyBonus: recencyBonus,
      ));
    }

    // 8. Sort and filter: prioritize genre match to user's genreWeights
    final List<ScoredReview> results;
    final hasGenreWeights = userPrefs?.genreWeights.isNotEmpty ?? false;
    if (hasGenreWeights) {
      // Primary sort by genreScore (user's preferred genres), then by finalScore
      scored.sort((a, b) {
        final genreCmp = b.genreScore.compareTo(a.genreScore);
        if (genreCmp != 0) return genreCmp;
        return b.finalScore.compareTo(a.finalScore);
      });
      // Filter: prefer candidates that match at least one preferred genre
      final topGenres = (userPrefs!.genreWeights.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .take(5)
          .map((e) => e.key.toLowerCase())
          .toSet();
      final genreMatches = scored.where((s) {
        final candidateGenres = (s.reviewWithDocId.review.genres ?? [])
            .map((g) => g.toLowerCase())
            .toSet();
        return candidateGenres.any((g) => topGenres.contains(g));
      }).toList();
      final nonMatches = scored.where((s) {
        final candidateGenres = (s.reviewWithDocId.review.genres ?? [])
            .map((g) => g.toLowerCase())
            .toSet();
        return !candidateGenres.any((g) => topGenres.contains(g));
      }).toList();
      // Genre matches first (sorted by genreScore then finalScore), then others
      final ordered = [...genreMatches, ...nonMatches];
      results = ordered.take(topN).toList();
    } else {
      scored.sort((a, b) => b.finalScore.compareTo(a.finalScore));
      results = scored.take(topN).toList();
    }

    // 9. Cache results
    await _cacheRecommendations(userId, results);

    debugPrint('[REC] Generated ${results.length} recommendations '
        '(from ${candidates.length} candidates)');

    return results;
  }

  /// Fetch candidate reviews from the community (excluding the user's own).
  static Future<List<ReviewWithDocId>> _fetchCandidateReviews(
    String userId,
    int limit,
  ) async {
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
              // Filter out user's own reviews
              if (review.userId == userId) return null;

              final fullReviewId = doc.reference.path;
              return ReviewWithDocId(
                review: review,
                docId: doc.id,
                fullReviewId: fullReviewId,
              );
            } catch (e) {
              debugPrint('[REC] Error parsing candidate review ${doc.id}: $e');
              return null;
            }
          })
          .where((r) => r != null)
          .cast<ReviewWithDocId>()
          .toList();
    } catch (e) {
      debugPrint('[REC] Error fetching candidate reviews: $e');
      return [];
    }
  }

  /// Fetch the user's own reviews for taste vector generation.
  static Future<List<Review>> _fetchUserReviews(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reviews')
          .orderBy('date', descending: true)
          .limit(100)
          .get();

      return snapshot.docs
          .map((doc) => Review.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('[REC] Error fetching user reviews: $e');
      return [];
    }
  }

  /// Keyword-based sentiment score for a single review text.
  ///
  /// Uses the same word lists as ReviewAnalysisService._analyzeReviewSentiment.
  static double _computeSentiment(String text) {
    final lower = text.toLowerCase();
    int positiveCount = 0;
    int negativeCount = 0;

    for (final word in _positiveWords) {
      if (lower.contains(word)) positiveCount++;
    }
    for (final word in _negativeWords) {
      if (lower.contains(word)) negativeCount++;
    }

    if (positiveCount > negativeCount) {
      return 0.5 + (positiveCount * 0.1).clamp(0.0, 0.5);
    }
    return 0.5 - (negativeCount * 0.1).clamp(0.0, 0.5);
  }

  /// Fetch user genre interest preferences from Firestore.
  ///
  /// Returns `null` if the user has not set any preferences.
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
      debugPrint('[REC] Error fetching user preferences: $e');
      return null;
    }
  }

  /// Compute a rating-weighted genre score blended with active interest.
  ///
  /// 1. For each candidate genre that the user has reviewed, weight by
  ///    the user's average rating and preference strength for that genre.
  /// 2. Blend with the user's explicit genre interest weights (if set).
  ///    When the user has set genre weights in Profile/Preferences, we
  ///    prioritize them more strongly (75% vs 25%) so highest-weighted
  ///    preferences drive the ranking.
  /// 3. Top-genre bonus: if the candidate matches one of the user's top 3
  ///    highest-weighted genres, add extra boost.
  /// 4. Scale by the candidate review's own quality score.
  static double _computeWeightedGenreScore({
    required Set<String> candidateGenres,
    required Map<String, GenrePreference> genrePreferences,
    required EnhancedUserPreferences? userPrefs,
    required double candidateReviewScore,
  }) {
    // Step 1: Rating-weighted genre score from review history
    final overlapping = candidateGenres.where(
      (g) => genrePreferences.containsKey(g),
    );

    double genreScore = 0.0;
    if (overlapping.isNotEmpty) {
      double weightSum = 0.0;
      for (final g in overlapping) {
        final pref = genrePreferences[g]!;
        weightSum +=
            (pref.averageRating / 5.0) * 0.7 + pref.preferenceStrength * 0.7;
      }
      genreScore = weightSum / overlapping.length;
    }

    // Step 2: Blend with active genre interest from user preferences
    // When user has explicit genre weights, prioritize them (highest-weighted)
    double blendedGenreScore = genreScore;
    final genreWeights = userPrefs?.genreWeights ?? {};
    if (genreWeights.isNotEmpty) {
      double interestScore = 0.0;
      for (final g in candidateGenres) {
        final w = genreWeights[g];
        if (w != null && w > interestScore) {
          interestScore = w;
        }
      }
      // Prioritize explicit preferences: 25% review-based, 75% profile weights
      blendedGenreScore = genreScore * 0.15 + interestScore * 0.85;

      // Step 2b: Top-genre bonus — if candidate matches user's top 3 genres by weight
      final topGenresByWeight = genreWeights.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top3Genres = topGenresByWeight.take(3).map((e) => e.key).toSet();
      final hasTopGenre = candidateGenres.any((g) => top3Genres.contains(g));
      if (hasTopGenre && interestScore >= 0.6) {
        blendedGenreScore = (blendedGenreScore * 0.85 + 0.15).clamp(0.0, 1.0);
      }
    }

    // Step 3: Factor in candidate review quality
    if (candidateReviewScore >= 3.5) {
      final candidateQuality = (candidateReviewScore - 3.5) / 1.5;
      return blendedGenreScore * (0.6 + candidateQuality * 0.4);
    } else {
      return blendedGenreScore * 0.2;
    }
  }

  /// Load cached recommendations from Firestore (1-hour TTL).
  static Future<List<ScoredReview>?> _getCachedRecommendations(
    String userId,
  ) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reviewAnalysis')
          .doc('recommendations')
          .get();

      if (!doc.exists || doc.data() == null) return null;

      final data = doc.data()!;
      final lastUpdated = (data['lastUpdated'] as Timestamp?)?.toDate();
      if (lastUpdated == null ||
          DateTime.now().difference(lastUpdated) > _cacheTtl) {
        return null; // Cache expired
      }

      final items = data['items'] as List<dynamic>?;
      if (items == null) return null;

      return items.map((item) {
        final map = item as Map<String, dynamic>;
        final reviewData = map['review'] as Map<String, dynamic>;
        final review = Review.fromFirestore(reviewData);

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
      debugPrint('[REC] Error loading cached recommendations: $e');
      return null;
    }
  }

  /// Clear the recommendations cache for a user.
  ///
  /// Call this when the user updates their preferences so the next
  /// fetch returns fresh recommendations based on the new preferences.
  static Future<void> clearRecommendationsCache(String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reviewAnalysis')
          .doc('recommendations')
          .delete();
      debugPrint('[REC] Cleared recommendations cache for user=$userId');
    } catch (e) {
      debugPrint('[REC] Error clearing recommendations cache: $e');
    }
  }

  /// Cache scored recommendations to Firestore.
  static Future<void> _cacheRecommendations(
    String userId,
    List<ScoredReview> results,
  ) async {
    try {
      final items = results.map((sr) {
        final r = sr.reviewWithDocId.review;
        return {
          'review': {
            'displayName': r.displayName,
            'userId': r.userId,
            'artist': r.artist,
            'title': r.title,
            'review': r.review,
            'score': r.score,
            'date': r.date != null ? Timestamp.fromDate(r.date!) : null,
            'albumImageUrl': r.albumImageUrl,
            'userImageUrl': r.userImageUrl,
            'likes': r.likes,
            'replies': r.replies,
            'reposts': r.reposts,
            'genres': r.genres,
            'tags': r.tags,
          },
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

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reviewAnalysis')
          .doc('recommendations')
          .set({
        'items': items,
        'lastUpdated': FieldValue.serverTimestamp(),
        'count': results.length,
      });

      debugPrint('[REC] Cached ${results.length} recommendations');
    } catch (e) {
      debugPrint('[REC] Error caching recommendations: $e');
    }
  }
}
