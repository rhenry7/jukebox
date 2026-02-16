import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test_project/models/enhanced_user_preferences.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/providers/reviews_provider.dart';

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

/// Simplified recommendation engine:
/// - Use the user's liked genres.
/// - Return only high-rated community reviews that share those genres.
class ReviewRecommendationService {
  static const _cacheTtl = Duration(hours: 1);
  static const double _highRatingThreshold = 3.5;
  static const double _fallbackRatingThreshold = 3.0;

  /// Get personalized review recommendations for a user.
  ///
  /// Intended behavior:
  /// - If the user likes genre X, return community reviews that are
  ///   highly rated and tagged with genre X.
  static Future<List<ScoredReview>> getRecommendedReviews(
    String userId, {
    int candidatePoolSize = 400,
    int topN = 20,
    bool forceRefresh = true,
  }) async {
    final userPrefs = await _fetchUserPreferences(userId);
    final preferencesSignature = _buildPreferencesSignature(userPrefs);

    if (!forceRefresh) {
      final cached = await _getCachedRecommendations(
        userId,
        preferencesSignature: preferencesSignature,
      );
      if (cached != null) {
        debugPrint('[REC] Using cached recommendations (${cached.length} items)');
        return cached;
      }
    }

    final likedGenreWeights = _extractLikedGenreWeights(userPrefs);
    final dislikedGenres = _extractDislikedGenres(userPrefs);
    final likedGenres = likedGenreWeights.keys.toSet();

    if (likedGenres.isEmpty) {
      debugPrint('[REC] No liked genres found for user=$userId');
      return [];
    }

    final candidates = await _fetchCandidateReviews(userId, candidatePoolSize);
    if (candidates.isEmpty) {
      debugPrint('[REC] No candidate reviews found');
      return [];
    }

    final primaryMatches = <ScoredReview>[];
    final secondaryMatches = <ScoredReview>[];

    for (final candidate in candidates) {
      final review = candidate.review;
      if (_matchesDislikedGenre(review: review, dislikedGenres: dislikedGenres)) {
        continue;
      }

      final match = _genreMatchForReview(
        review: review,
        likedGenreWeights: likedGenreWeights,
      );
      if (!match.hasMatch) continue;

      // Rank by user's genre preference weight first, then overlap, then rating.
      final genreMatchStrength = ((match.weightScore * 0.75) +
              ((match.matchCount / likedGenres.length).clamp(0.0, 1.0) * 0.25))
          .clamp(0.0, 1.0);
      final normalizedRating = (review.score / 5.0).clamp(0.0, 1.0);
      final finalScore = (genreMatchStrength * 0.8) + (normalizedRating * 0.2);

      final scored = ScoredReview(
        reviewWithDocId: candidate,
        finalScore: finalScore,
        genreScore: genreMatchStrength,
      );

      if (review.score >= _highRatingThreshold) {
        primaryMatches.add(scored);
      } else if (review.score >= _fallbackRatingThreshold) {
        secondaryMatches.add(scored);
      }
    }

    primaryMatches.sort((a, b) => b.finalScore.compareTo(a.finalScore));
    secondaryMatches.sort((a, b) => b.finalScore.compareTo(a.finalScore));

    final merged = <ScoredReview>[];
    final seenReviewIds = <String>{};

    for (final item in [...primaryMatches, ...secondaryMatches]) {
      final key = item.reviewWithDocId.fullReviewId ?? item.reviewWithDocId.docId;
      if (seenReviewIds.add(key)) {
        merged.add(item);
      }
      if (merged.length >= topN) break;
    }

    // Final fallback: if still not enough, include high-rated community reviews
    // even without a genre match so the list does not collapse to 1-2 items.
    if (merged.length < topN) {
      for (final candidate in candidates) {
        final review = candidate.review;
        if (_matchesDislikedGenre(
          review: review,
          dislikedGenres: dislikedGenres,
        )) {
          continue;
        }
        if (review.score < _highRatingThreshold) continue;

        final key = candidate.fullReviewId ?? candidate.docId;
        if (!seenReviewIds.add(key)) continue;

        merged.add(
          ScoredReview(
            reviewWithDocId: candidate,
            finalScore: (review.score / 5.0).clamp(0.0, 1.0),
            genreScore: 0.0,
          ),
        );
        if (merged.length >= topN) break;
      }
    }

    final results = merged.take(topN).toList();

    await _cacheRecommendations(
      userId,
      results,
      preferencesSignature: preferencesSignature,
    );

    debugPrint('[REC] Generated ${results.length} recommendations '
        '(from ${candidates.length} candidates, likedGenres=${likedGenres.length}, '
        'dislikedGenres=${dislikedGenres.length}, primary=${primaryMatches.length}, '
        'secondary=${secondaryMatches.length})');

    return results;
  }

  static Map<String, double> _extractLikedGenreWeights(
      EnhancedUserPreferences? userPrefs) {
    if (userPrefs == null) return <String, double>{};

    final weights = <String, double>{};

    for (final genre in userPrefs.favoriteGenres) {
      final key = genre.toLowerCase().trim();
      if (key.isEmpty) continue;
      final existing = weights[key] ?? 0.0;
      if (existing < 0.7) {
        weights[key] = 0.7;
      }
    }

    for (final entry in userPrefs.genreWeights.entries) {
      final key = entry.key.toLowerCase().trim();
      if (key.isEmpty) continue;
      final normalizedWeight = entry.value.clamp(0.0, 1.0);
      final existing = weights[key] ?? 0.0;
      if (normalizedWeight > existing) {
        weights[key] = normalizedWeight;
      }
    }

    return weights;
  }

  static Set<String> _extractDislikedGenres(
      EnhancedUserPreferences? userPrefs) {
    if (userPrefs == null) return <String>{};

    return userPrefs.dislikedGenres
        .map((g) => g.toLowerCase().trim())
        .where((g) => g.isNotEmpty)
        .toSet();
  }

  static bool _matchesDislikedGenre({
    required Review review,
    required Set<String> dislikedGenres,
  }) {
    if (dislikedGenres.isEmpty) return false;

    final reviewGenres = <String>{
      ...(review.genres ?? const <String>[])
          .map((g) => g.toLowerCase().trim())
          .where((g) => g.isNotEmpty),
      ...(review.tags ?? const <String>[])
          .map((g) => g.toLowerCase().trim())
          .where((g) => g.isNotEmpty),
    };

    for (final disliked in dislikedGenres) {
      for (final candidateGenre in reviewGenres) {
        final isMatch = candidateGenre == disliked ||
            candidateGenre.contains(disliked) ||
            disliked.contains(candidateGenre);
        if (isMatch) return true;
      }
    }

    return false;
  }

  static _GenreMatchResult _genreMatchForReview({
    required Review review,
    required Map<String, double> likedGenreWeights,
  }) {
    final reviewGenres = <String>{
      ...(review.genres ?? const <String>[])
          .map((g) => g.toLowerCase().trim())
          .where((g) => g.isNotEmpty),
      ...(review.tags ?? const <String>[])
          .map((g) => g.toLowerCase().trim())
          .where((g) => g.isNotEmpty),
    };

    if (reviewGenres.isEmpty || likedGenreWeights.isEmpty) {
      return const _GenreMatchResult.empty();
    }

    final matchedLikedGenres = <String>{};
    double topMatchedWeight = 0.0;

    for (final liked in likedGenreWeights.entries) {
      for (final candidateGenre in reviewGenres) {
        final isMatch = candidateGenre == liked.key ||
            candidateGenre.contains(liked.key) ||
            liked.key.contains(candidateGenre);
        if (!isMatch) continue;

        matchedLikedGenres.add(liked.key);
        if (liked.value > topMatchedWeight) {
          topMatchedWeight = liked.value;
        }
      }
    }

    if (matchedLikedGenres.isEmpty) {
      return const _GenreMatchResult.empty();
    }

    return _GenreMatchResult(
      hasMatch: true,
      matchCount: matchedLikedGenres.length,
      weightScore: topMatchedWeight.clamp(0.0, 1.0),
    );
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

  /// Load cached recommendations from Firestore (1-hour TTL).
  static Future<List<ScoredReview>?> _getCachedRecommendations(
    String userId,
    {String? preferencesSignature}
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
      if (preferencesSignature != null &&
          (data['preferencesSignature'] as String?) != preferencesSignature) {
        return null;
      }

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
    {String? preferencesSignature}
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
        'preferencesSignature': preferencesSignature,
      });

      debugPrint('[REC] Cached ${results.length} recommendations');
    } catch (e) {
      debugPrint('[REC] Error caching recommendations: $e');
    }
  }

  static String _buildPreferencesSignature(EnhancedUserPreferences? userPrefs) {
    if (userPrefs == null) return 'none';

    final likedEntries = _extractLikedGenreWeights(userPrefs).entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final liked = likedEntries
        .map((e) => '${e.key}:${e.value.toStringAsFixed(3)}')
        .join('|');

    final disliked = _extractDislikedGenres(userPrefs).toList()..sort();
    final dislikedPart = disliked.join('|');

    return 'liked=$liked;disliked=$dislikedPart';
  }
}

class _GenreMatchResult {
  final bool hasMatch;
  final int matchCount;
  final double weightScore;

  const _GenreMatchResult({
    required this.hasMatch,
    required this.matchCount,
    required this.weightScore,
  });

  const _GenreMatchResult.empty()
      : hasMatch = false,
        matchCount = 0,
        weightScore = 0.0;
}
