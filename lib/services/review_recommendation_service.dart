import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test_project/models/enhanced_user_preferences.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/providers/reviews_provider.dart';

// ─── Scoring weights ──────────────────────────────────────────────────────────
//
//  Stage 1 (deterministic local scoring):
//    genre  40% — tag overlap weighted by genreWeights
//    artist 25% — match against favoriteArtists + user's own reviewed artists
//    album  10% — match against favoriteAlbums + user's own reviewed albums
//    rating 15% — community review quality (review.score / 5)
//    recency 10% — exponential decay over 90 days
//
//  Stage 2: discard disliked-genre reviews; sort by local score; take top 30.
//
//  This is the on-device FALLBACK. The primary For You list is built
//  server-side (functions/, CF-RAG over the whole corpus) and read from
//  users/{uid}/forYou/current. No AI runs on the client.
// ─────────────────────────────────────────────────────────────────────────────

const _wGenre = 0.40;
const _wArtist = 0.25;
const _wAlbum = 0.10;
const _wRating = 0.15;
const _wRecency = 0.10;

/// Longer reviews rank higher; under [_minReviewLength] chars is penalised.
const _wDepth = 0.15;
const _minReviewLength = 100;
const _fullDepthLength = 500;

/// A review paired with its recommendation scores (kept for UI compatibility).
class ScoredReview {
  final ReviewWithDocId reviewWithDocId;
  final double finalScore;
  final double genreScore;
  final double semanticScore;
  final double sentimentScore;
  final double artistScore;
  final double recencyBonus;

  /// Why this was recommended (server-built lists only).
  final String? reason;

  const ScoredReview({
    required this.reviewWithDocId,
    this.finalScore = 0.0,
    this.genreScore = 0.0,
    this.semanticScore = 0.0,
    this.sentimentScore = 0.0,
    this.artistScore = 0.0,
    this.recencyBonus = 0.0,
    this.reason,
  });
}

/// On-device fallback recommender, used until the server-built For You list
/// exists (see `ForYouService`):
///  1. Deterministic local scoring (genre/artist/album/rating/recency)
///  2. Discard disliked genres and reposts; sort; take top 30
class ReviewRecommendationService {
  /// Max community reviews fetched from Firestore.
  static const _fetchLimit = 300;

  /// Reviews passed to stage-1 scoring (after low-quality filter).
  static const _minReviewScore = 3.0;

  /// Results returned after local ranking.
  static const _resultSize = 50;

  /// Own reviews at or above this many stars count as liking the artist/album.
  static const _likedOwnReviewScore = 3.5;

  /// Cache TTL.
  static const _cacheTtl = Duration(minutes: 15);

  static final Map<String, _CachedResult> _cache = {};

  /// Set when a review is submitted or preferences are updated so the For You
  /// tab knows to re-fetch on next focus.
  static bool _needsRefresh = false;

  /// Called after a user writes a review or saves preferences.
  /// Clears the cached result and marks the feed as stale.
  static void markNeedsRefresh(String userId) {
    clearCache(userId);
    _needsRefresh = true;
    debugPrint('[REC] Marked needs-refresh for $userId');
  }

  /// Returns true (and resets the flag) if a refresh has been requested.
  /// Designed to be called once per tab-focus check.
  static bool consumeNeedsRefresh() {
    if (_needsRefresh) {
      _needsRefresh = false;
      return true;
    }
    return false;
  }

  // ─── Public API ─────────────────────────────────────────────────────────────

  static Future<List<ScoredReview>> getRecommendedReviews(
    String userId, {
    int limit = _fetchLimit,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _cache[userId];
      if (cached != null && !cached.isExpired) {
        debugPrint('[REC] Returning ${cached.results.length} cached recs');
        return cached.results;
      }
    }

    // Fetch all three sources in parallel.
    final results = await Future.wait([
      _fetchUserPreferences(userId),
      _fetchUserOwnReviews(userId),
      _fetchAllReviews(userId, limit),
    ]);

    final userPrefs = results[0] as EnhancedUserPreferences?;
    final userOwnReviews = results[1] as List<Review>;
    final allReviews = results[2] as List<ReviewWithDocId>;

    if (allReviews.isEmpty) {
      debugPrint('[REC] No community reviews found');
      return [];
    }

    // ── Stage 1: deterministic local scoring ──────────────────────────────────
    final likedGenres = _buildLikedGenreWeights(userPrefs);
    final dislikedGenres = _buildDislikedSet(userPrefs);
    final likedArtists = _buildLikedArtistSet(userPrefs, userOwnReviews);
    final reviewedArtists = _buildReviewedArtistSet(userOwnReviews);
    final likedAlbums = _buildLikedAlbumSet(userPrefs, userOwnReviews);
    final reviewedAlbums = _buildReviewedAlbumSet(userOwnReviews);

    final scored = <_LocallyScoredReview>[];
    for (final rw in allReviews) {
      final r = rw.review;

      // Hard filter: skip low-quality reviews.
      if (r.score < _minReviewScore) continue;

      // Hard filter: skip reviews that overlap with disliked genres.
      if (_hasDislikedGenre(r, dislikedGenres)) continue;

      final gs = _computeGenreScore(r, likedGenres);
      final as_ = _computeArtistScore(r, likedArtists, reviewedArtists);
      final albs = _computeAlbumScore(r, likedAlbums, reviewedAlbums);
      final rs = r.score / 5.0;
      final rec = _computeRecency(r.date);

      final local = gs * _wGenre +
          as_ * _wArtist +
          albs * _wAlbum +
          rs * _wRating +
          rec * _wRecency +
          _computeDepth(r.review) * _wDepth;

      scored.add(_LocallyScoredReview(
        rw: rw,
        localScore: local,
        genreScore: gs,
        artistScore: as_,
        recencyScore: rec,
      ));
    }

    // ── Stage 2: sort by local score, take the top results ──────────────────
    scored.sort((a, b) => b.localScore.compareTo(a.localScore));

    if (scored.isEmpty) {
      // Nothing passed filters — fall back to top-N by recency/rating.
      final fallback = allReviews
          .take(50)
          .map((rw) => ScoredReview(reviewWithDocId: rw))
          .toList();
      _cache[userId] = _CachedResult(fallback);
      return fallback;
    }

    final finalResults = scored
        .take(_resultSize)
        .map((ls) => ScoredReview(
              reviewWithDocId: ls.rw,
              finalScore: ls.localScore,
              genreScore: ls.genreScore,
              artistScore: ls.artistScore,
              recencyBonus: ls.recencyScore,
            ))
        .toList();

    debugPrint('[REC] Local ranking: ${scored.length} scored → ${finalResults.length}');
    _cache[userId] = _CachedResult(finalResults);
    return finalResults;
  }

  static void clearCache([String? userId]) {
    if (userId != null) {
      _cache.remove(userId);
    } else {
      _cache.clear();
    }
  }

  static Future<void> clearRecommendationsCache(String userId) async {
    clearCache(userId);
  }

  // ─── Stage 1: Local scoring helpers ──────────────────────────────────────────

  /// Map genre → weight (0.0–1.0). Favorites not in genreWeights get 1.0.
  static Map<String, double> _buildLikedGenreWeights(
      EnhancedUserPreferences? prefs) {
    if (prefs == null) return {};
    final out = <String, double>{};
    for (final g in prefs.favoriteGenres) {
      final k = g.toLowerCase().trim();
      if (k.isNotEmpty) out[k] = 1.0;
    }
    for (final entry in prefs.genreWeights.entries) {
      final k = entry.key.toLowerCase().trim();
      if (k.isNotEmpty && entry.value > 0) {
        // Keep the higher of the two if already set.
        out[k] = math.max(out[k] ?? 0.0, entry.value);
      }
    }
    return out;
  }

  static Set<String> _buildDislikedSet(EnhancedUserPreferences? prefs) {
    if (prefs == null) return {};
    return prefs.dislikedGenres
        .map((g) => g.toLowerCase().trim())
        .where((g) => g.isNotEmpty)
        .toSet();
  }

  static Set<String> _buildLikedArtistSet(
      EnhancedUserPreferences? prefs, List<Review> ownReviews) {
    final out = <String>{};
    if (prefs != null) {
      for (final a in prefs.favoriteArtists) {
        final k = a.toLowerCase().trim();
        if (k.isNotEmpty) out.add(k);
      }
    }
    return out;
  }

  /// Artists from the user's own reviews they actually liked — a 1-star
  /// review must not boost that artist.
  static Set<String> _buildReviewedArtistSet(List<Review> ownReviews) {
    return ownReviews
        .where((r) => r.score >= _likedOwnReviewScore)
        .map((r) => r.artist.toLowerCase().trim())
        .where((a) => a.isNotEmpty)
        .toSet();
  }

  static Set<String> _buildLikedAlbumSet(
      EnhancedUserPreferences? prefs, List<Review> ownReviews) {
    final out = <String>{};
    if (prefs != null) {
      for (final a in prefs.favoriteAlbums) {
        final k = a.toLowerCase().trim();
        if (k.isNotEmpty) out.add(k);
      }
    }
    return out;
  }

  static Set<String> _buildReviewedAlbumSet(List<Review> ownReviews) {
    return ownReviews
        .where((r) => r.score >= _likedOwnReviewScore)
        .map((r) => r.title.toLowerCase().trim())
        .where((t) => t.isNotEmpty)
        .toSet();
  }

  /// Genre score: sum of weights for overlapping genres, normalized to [0,1].
  static double _computeGenreScore(
      Review r, Map<String, double> likedGenres) {
    if (likedGenres.isEmpty) return 0.0;
    final genres = (r.genres ?? [])
        .map((g) => g.toLowerCase().trim())
        .where((g) => g.isNotEmpty)
        .toList();
    if (genres.isEmpty) return 0.0;

    double sum = 0.0;
    for (final g in genres) {
      // Exact match.
      if (likedGenres.containsKey(g)) {
        sum += likedGenres[g]!;
        continue;
      }
      // Partial match (e.g. "indie rock" overlaps with "rock").
      for (final entry in likedGenres.entries) {
        if (g.contains(entry.key) || entry.key.contains(g)) {
          sum += entry.value * 0.6; // partial credit
          break;
        }
      }
    }
    // Normalize: cap at 1 even if multiple genres match.
    return math.min(sum / likedGenres.values.fold(0.0, math.max), 1.0);
  }

  static bool _hasDislikedGenre(Review r, Set<String> disliked) {
    if (disliked.isEmpty) return false;
    final genres = (r.genres ?? [])
        .map((g) => g.toLowerCase().trim())
        .where((g) => g.isNotEmpty);
    for (final g in genres) {
      for (final d in disliked) {
        if (g == d || g.contains(d) || d.contains(g)) return true;
      }
    }
    return false;
  }

  /// Artist score: 1.0 for liked artist, 0.5 for previously reviewed artist.
  static double _computeArtistScore(
    Review r,
    Set<String> likedArtists,
    Set<String> reviewedArtists,
  ) {
    final artist = r.artist.toLowerCase().trim();
    if (artist.isEmpty) return 0.0;

    // Exact match in liked.
    if (likedArtists.contains(artist)) return 1.0;

    // Partial match in liked (e.g. "The Beatles" vs "Beatles").
    for (final la in likedArtists) {
      if (artist.contains(la) || la.contains(artist)) return 0.8;
    }

    // Appeared in user's own review history.
    if (reviewedArtists.contains(artist)) return 0.5;
    for (final ra in reviewedArtists) {
      if (artist.contains(ra) || ra.contains(artist)) return 0.3;
    }

    return 0.0;
  }

  /// Album score: 1.0 if album in favorites, 0.5 if in own review history.
  static double _computeAlbumScore(
    Review r,
    Set<String> likedAlbums,
    Set<String> reviewedAlbums,
  ) {
    final title = r.title.toLowerCase().trim();
    if (title.isEmpty) return 0.0;

    if (likedAlbums.contains(title)) return 1.0;
    for (final la in likedAlbums) {
      if (title.contains(la) || la.contains(title)) return 0.7;
    }
    if (reviewedAlbums.contains(title)) return 0.5;
    return 0.0;
  }

  /// Depth: -1 under [_minReviewLength] chars, 0 at it, 1 at [_fullDepthLength].
  static double _computeDepth(String text) {
    final length = text.trim().length;
    if (length < _minReviewLength) return -1.0;
    return ((length - _minReviewLength) / (_fullDepthLength - _minReviewLength))
        .clamp(0.0, 1.0);
  }

  /// Recency: 1.0 today → 0.0 at 90 days (exponential decay).
  static double _computeRecency(DateTime? date) {
    if (date == null) return 0.1;
    final age = DateTime.now().difference(date).inDays.clamp(0, 90);
    return math.exp(-age / 30.0); // half-life ~30 days
  }

  // ─── Firestore fetches ────────────────────────────────────────────────────────

  static Future<List<ReviewWithDocId>> _fetchAllReviews(
      String userId, int limit) async {
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
              // Skip own reviews and repost copies (duplicates of originals).
              if (review.userId == userId || review.isRepost) return null;
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
          .whereType<ReviewWithDocId>()
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

  static Future<EnhancedUserPreferences?> _fetchUserPreferences(
      String userId) async {
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
}

// ─── Internal types ───────────────────────────────────────────────────────────

class _LocallyScoredReview {
  final ReviewWithDocId rw;
  final double localScore;
  final double genreScore;
  final double artistScore;
  final double recencyScore;

  const _LocallyScoredReview({
    required this.rw,
    required this.localScore,
    required this.genreScore,
    required this.artistScore,
    required this.recencyScore,
  });
}

class _CachedResult {
  final List<ScoredReview> results;
  final DateTime _createdAt;

  _CachedResult(this.results) : _createdAt = DateTime.now();

  bool get isExpired =>
      DateTime.now().difference(_createdAt) >
      ReviewRecommendationService._cacheTtl;
}
