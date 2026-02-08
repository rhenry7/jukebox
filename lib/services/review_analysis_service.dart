import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/services/embedding_service.dart';
import 'package:flutter_test_project/utils/scoring_utils.dart';

/// Service to analyze user reviews and extract preferences for personalized recommendations
class ReviewAnalysisService {
  /// Analyze user reviews with caching and incremental updates
  static Future<UserReviewProfile> analyzeUserReviews(String userId, {
    bool forceRefresh = false,
  }) async {
    // Try to get cached profile first (unless force refresh)
    if (!forceRefresh) {
      final cachedProfile = await _getCachedProfile(userId);
      if (cachedProfile != null) {
        final reviewCount = await _getReviewCount(userId);
        final cachedCount = cachedProfile.cachedReviewCount;
        
        // If no new reviews, return cached profile
        if (reviewCount == cachedCount) {
          debugPrint('Using cached review profile ($cachedCount reviews)');
          return cachedProfile.profile;
        }
        
        // If only a few new reviews, do incremental update
        if (reviewCount > cachedCount && (reviewCount - cachedCount) <= 10) {
          debugPrint('Incremental update: ${reviewCount - cachedCount} new reviews');
          return _incrementalUpdate(userId, cachedProfile.profile, cachedCount);
        }
      }
    }
    
    // Full analysis (cache miss or many new reviews)
    debugPrint('Performing full review analysis...');
    final reviews = await _fetchAllUserReviews(userId);
    final profile = UserReviewProfile(
      ratingPattern: _analyzeRatingPattern(reviews),
      genrePreferences: _analyzeGenrePreferences(reviews),
      artistPreferences: _analyzeArtistPreferences(reviews),
      reviewSentiment: _analyzeReviewSentiment(reviews),
      temporalPatterns: _analyzeTemporalPatterns(reviews),
    );
    
    // Cache the profile
    await _cacheProfile(userId, profile, reviews.length);

    // Trigger taste vector refresh in background (Phase 3 — embeddings)
    _refreshTasteVectorInBackground(userId, reviews);
    
    return profile;
  }
  
  /// Fetch all user reviews (with limit for performance)
  static Future<List<Review>> _fetchAllUserReviews(String userId) async {
    // First, get count to check if we need to limit
    final countSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('reviews')
        .count()
        .get();
    
    final totalCount = countSnapshot.count ?? 0;
    
    // For users with 1000+ reviews, use recent 500 for performance
    final limit = totalCount > 1000 ? 500 : null;
    
    var query = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('reviews')
        .orderBy('date', descending: true);
    
    if (limit != null) {
      query = query.limit(limit);
      debugPrint('Limiting to recent $limit reviews (user has $totalCount total)');
    }
    
    final snapshot = await query.get();
    
    return snapshot.docs
        .map((doc) => Review.fromFirestore(doc.data()))
        .toList();
  }
  
  /// Get current review count
  static Future<int> _getReviewCount(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('reviews')
        .count()
        .get();
    return snapshot.count ?? 0;
  }
  
  /// Get cached profile from Firestore
  static Future<CachedReviewProfile?> _getCachedProfile(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reviewAnalysis')
          .doc('profile')
          .get();
      
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      
      final data = doc.data()!;
      final profile = _profileFromJson(data['profile'] as Map<String, dynamic>);
      final cachedCount = data['reviewCount'] as int? ?? 0;
      final lastUpdated = (data['lastUpdated'] as Timestamp?)?.toDate();
      
      // Check if cache is too old (older than 7 days, force refresh)
      if (lastUpdated != null) {
        final daysSinceUpdate = DateTime.now().difference(lastUpdated).inDays;
        if (daysSinceUpdate > 7) {
          debugPrint('Cache is $daysSinceUpdate days old, refreshing...');
          return null;
        }
      }
      
      return CachedReviewProfile(
        profile: profile,
        cachedReviewCount: cachedCount,
        lastUpdated: lastUpdated,
      );
    } catch (e) {
      debugPrint('Error getting cached profile: $e');
      return null;
    }
  }
  
  /// Cache profile to Firestore
  static Future<void> _cacheProfile(
    String userId,
    UserReviewProfile profile,
    int reviewCount,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reviewAnalysis')
          .doc('profile')
          .set({
        'profile': _profileToJson(profile),
        'reviewCount': reviewCount,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      debugPrint('Cached review profile ($reviewCount reviews)');
    } catch (e) {
      debugPrint('Error caching profile: $e');
    }
  }
  
  /// Incrementally update profile (only analyze new reviews)
  static Future<UserReviewProfile> _incrementalUpdate(
    String userId,
    UserReviewProfile cachedProfile,
    int cachedReviewCount,
  ) async {
    // Get only new reviews (since last analysis)
    final newReviews = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('reviews')
        .orderBy('date', descending: true)
        .limit(20) // Get recent reviews
        .get()
        .then((snapshot) => snapshot.docs
            .map((doc) => Review.fromFirestore(doc.data()))
            .toList());
    
    // For incremental update, we'll do a lightweight merge
    // In a production system, you'd want more sophisticated incremental logic
    // For now, we'll do a full re-analysis but cache it
    final allReviews = await _fetchAllUserReviews(userId);
    final updatedProfile = UserReviewProfile(
      ratingPattern: _analyzeRatingPattern(allReviews),
      genrePreferences: _analyzeGenrePreferences(allReviews),
      artistPreferences: _analyzeArtistPreferences(allReviews),
      reviewSentiment: _analyzeReviewSentiment(allReviews),
      temporalPatterns: _analyzeTemporalPatterns(allReviews),
    );
    
    // Update cache
    await _cacheProfile(userId, updatedProfile, allReviews.length);
    
    return updatedProfile;
  }
  
  /// Convert UserReviewProfile to JSON for Firestore
  static Map<String, dynamic> _profileToJson(UserReviewProfile profile) {
    return {
      'ratingPattern': {
        'averageRating': profile.ratingPattern.averageRating,
        'recentAverageRating': profile.ratingPattern.recentAverageRating,
        'ratingDistribution': profile.ratingPattern.ratingDistribution.map(
          (k, v) => MapEntry(k.toString(), v),
        ),
        'ratingVolatility': profile.ratingPattern.ratingVolatility,
        'highlyRatedArtists': profile.ratingPattern.highlyRatedArtists,
        'lowRatedArtists': profile.ratingPattern.lowRatedArtists,
      },
      'genrePreferences': profile.genrePreferences.map((key, value) => MapEntry(
        key,
        {
          'genre': value.genre,
          'averageRating': value.averageRating,
          'reviewCount': value.reviewCount,
          'preferenceStrength': value.preferenceStrength,
          'favoriteArtists': value.favoriteArtists,
        },
      )),
      'artistPreferences': profile.artistPreferences.map((key, value) => MapEntry(
        key,
        {
          'artist': value.artist,
          'averageRating': value.averageRating,
          'reviewCount': value.reviewCount,
          'consistency': value.consistency,
          'lastReviewed': value.lastReviewed?.toIso8601String(),
          'preferenceScore': value.preferenceScore,
        },
      )),
      'reviewSentiment': {
        'sentimentScore': profile.reviewSentiment.sentimentScore,
        'keywords': profile.reviewSentiment.keywords,
        'mentionedArtists': profile.reviewSentiment.mentionedArtists,
        'mentionedGenres': profile.reviewSentiment.mentionedGenres,
        'wordFrequency': profile.reviewSentiment.wordFrequency.map(
          MapEntry.new,
        ),
      },
      'temporalPatterns': {
        'tasteEvolution': profile.temporalPatterns.tasteEvolution,
        'recentTrends': profile.temporalPatterns.recentTrends,
        'seasonalPatterns': profile.temporalPatterns.seasonalPatterns,
      },
    };
  }
  
  /// Convert JSON from Firestore to UserReviewProfile
  static UserReviewProfile _profileFromJson(Map<String, dynamic> json) {
    final ratingPatternData = json['ratingPattern'] as Map<String, dynamic>;
    final ratingDistribution = (ratingPatternData['ratingDistribution'] as Map<String, dynamic>?)
        ?.map((k, v) => MapEntry(int.parse(k), v as int)) ?? {};
    
    return UserReviewProfile(
      ratingPattern: RatingPattern(
        averageRating: (ratingPatternData['averageRating'] as num?)?.toDouble() ?? 0.0,
        recentAverageRating: (ratingPatternData['recentAverageRating'] as num?)?.toDouble() ?? 0.0,
        ratingDistribution: ratingDistribution,
        ratingVolatility: (ratingPatternData['ratingVolatility'] as num?)?.toDouble() ?? 0.0,
        highlyRatedArtists: (ratingPatternData['highlyRatedArtists'] as List<dynamic>?)
            ?.map((e) => e.toString()).toList() ?? [],
        lowRatedArtists: (ratingPatternData['lowRatedArtists'] as List<dynamic>?)
            ?.map((e) => e.toString()).toList() ?? [],
      ),
      genrePreferences: _parseGenrePreferences(json['genrePreferences'] as Map<String, dynamic>?),
      artistPreferences: _parseArtistPreferences(json['artistPreferences'] as Map<String, dynamic>?),
      reviewSentiment: _parseReviewSentiment(json['reviewSentiment'] as Map<String, dynamic>?),
      temporalPatterns: _parseTemporalPatterns(json['temporalPatterns'] as Map<String, dynamic>?),
    );
  }
  
  static Map<String, GenrePreference> _parseGenrePreferences(Map<String, dynamic>? data) {
    if (data == null) return {};
    return data.map((key, value) {
      final prefData = value as Map<String, dynamic>;
      return MapEntry(key, GenrePreference(
        genre: prefData['genre'] as String? ?? key,
        averageRating: (prefData['averageRating'] as num?)?.toDouble() ?? 0.0,
        reviewCount: prefData['reviewCount'] as int? ?? 0,
        preferenceStrength: (prefData['preferenceStrength'] as num?)?.toDouble() ?? 0.0,
        favoriteArtists: (prefData['favoriteArtists'] as List<dynamic>?)
            ?.map((e) => e.toString()).toList() ?? [],
      ));
    });
  }
  
  static Map<String, ArtistPreference> _parseArtistPreferences(Map<String, dynamic>? data) {
    if (data == null) return {};
    return data.map((key, value) {
      final prefData = value as Map<String, dynamic>;
      return MapEntry(key, ArtistPreference(
        artist: prefData['artist'] as String? ?? key,
        averageRating: (prefData['averageRating'] as num?)?.toDouble() ?? 0.0,
        reviewCount: prefData['reviewCount'] as int? ?? 0,
        consistency: (prefData['consistency'] as num?)?.toDouble() ?? 0.0,
        lastReviewed: prefData['lastReviewed'] != null
            ? DateTime.parse(prefData['lastReviewed'] as String)
            : null,
        preferenceScore: (prefData['preferenceScore'] as num?)?.toDouble() ?? 0.0,
      ));
    });
  }
  
  static ReviewSentiment _parseReviewSentiment(Map<String, dynamic>? data) {
    if (data == null) {
      return ReviewSentiment(
        sentimentScore: 0.5,
        keywords: [],
        mentionedArtists: [],
        mentionedGenres: [],
        wordFrequency: {},
      );
    }
    return ReviewSentiment(
      sentimentScore: (data['sentimentScore'] as num?)?.toDouble() ?? 0.5,
      keywords: (data['keywords'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      mentionedArtists: (data['mentionedArtists'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      mentionedGenres: (data['mentionedGenres'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      wordFrequency: (data['wordFrequency'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, v as int),
      ) ?? {},
    );
  }
  
  static TemporalPatterns _parseTemporalPatterns(Map<String, dynamic>? data) {
    if (data == null) {
      return TemporalPatterns(
        tasteEvolution: {},
        recentTrends: [],
        seasonalPatterns: {},
      );
    }
    return TemporalPatterns(
      tasteEvolution: (data['tasteEvolution'] as Map<String, dynamic>?) ?? {},
      recentTrends: (data['recentTrends'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      seasonalPatterns: (data['seasonalPatterns'] as Map<String, dynamic>?) ?? {},
    );
  }
  
  /// Refresh the user's taste vector in the background (non-blocking).
  ///
  /// Triggered when review analysis detects new reviews. This ensures
  /// the embedding-based taste vector stays in sync with the latest reviews.
  static void _refreshTasteVectorInBackground(
    String userId,
    List<Review> reviews,
  ) {
    Future(() async {
      try {
        await EmbeddingService.getTasteVector(userId, reviews);
        debugPrint('[EMBED] Background taste vector refresh complete');
      } catch (e) {
        debugPrint('[EMBED] Background taste vector refresh failed: $e');
      }
    });
  }

  /// Clear cached profile (useful for testing or forced refresh)
  static Future<void> clearCache(String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reviewAnalysis')
          .doc('profile')
          .delete();
      debugPrint('Cleared review analysis cache');
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }
  
  /// Analyze rating patterns
  static RatingPattern _analyzeRatingPattern(List<Review> reviews) {
    if (reviews.isEmpty) {
      return RatingPattern(
        averageRating: 0.0,
        recentAverageRating: 0.0,
        ratingDistribution: {},
        ratingVolatility: 0.0,
        highlyRatedArtists: [],
        lowRatedArtists: [],
      );
    }
    
    // Calculate overall average
    final totalRating = reviews.fold<double>(
      0.0,
      (sum, review) => sum + review.score,
    );
    final averageRating = totalRating / reviews.length;
    
    // Recent average (last 10 reviews)
    final recentReviews = reviews.take(10).toList();
    final recentAverage = recentReviews.isEmpty
        ? averageRating
        : recentReviews.fold<double>(0.0, (sum, r) => sum + r.score) /
            recentReviews.length;
    
    // Rating distribution
    final distribution = <int, int>{};
    for (final review in reviews) {
      final rating = review.score.round();
      distribution[rating] = (distribution[rating] ?? 0) + 1;
    }
    
    // Rating volatility (standard deviation)
    final variance = reviews.fold<double>(
      0.0,
      (sum, review) => sum + (review.score - averageRating) * (review.score - averageRating),
    ) / reviews.length;
    final volatility = variance > 0 ? variance : 0.0;
    
    // Highly rated artists (4.5+)
    final artistRatings = <String, List<double>>{};
    for (final review in reviews) {
      artistRatings.putIfAbsent(review.artist, () => []).add(review.score);
    }
    
    final highlyRated = <String>[];
    final lowRated = <String>[];
    
    artistRatings.forEach((artist, ratings) {
      final avg = ratings.fold<double>(0.0, (sum, r) => sum + r) / ratings.length;
      if (avg >= 4.5 && ratings.length >= 2) {
        highlyRated.add(artist);
      } else if (avg <= 2.5 && ratings.length >= 2) {
        lowRated.add(artist);
      }
    });
    
    return RatingPattern(
      averageRating: averageRating,
      recentAverageRating: recentAverage,
      ratingDistribution: distribution,
      ratingVolatility: volatility,
      highlyRatedArtists: highlyRated,
      lowRatedArtists: lowRated,
    );
  }
  
  /// Analyze genre preferences from reviews (with temporal decay — Grainger Ch. 5).
  ///
  /// Recent reviews are weighted exponentially higher than old ones when computing
  /// preference strength, so the user's evolving taste is reflected.
  static Map<String, GenrePreference> _analyzeGenrePreferences(
    List<Review> reviews,
  ) {
    final genreData = <String, List<Review>>{};

    // Group reviews by genre
    for (final review in reviews) {
      if (review.genres != null && review.genres!.isNotEmpty) {
        for (final genre in review.genres!) {
          genreData.putIfAbsent(genre, () => []).add(review);
        }
      }
    }

    final preferences = <String, GenrePreference>{};
    final totalReviews = reviews.length;

    if (totalReviews == 0) return preferences;

    genreData.forEach((genre, genreReviews) {
      // Weighted average rating using temporal decay
      double weightedRatingSum = 0.0;
      double decayWeightSum = 0.0;

      for (final review in genreReviews) {
        final decay = review.date != null
            ? ScoringUtils.temporalDecay(review.date!, halfLifeDays: 30.0)
            : 0.5; // Default weight for reviews without a date
        weightedRatingSum += review.score * decay;
        decayWeightSum += decay;
      }

      final avgRating = decayWeightSum > 0
          ? weightedRatingSum / decayWeightSum
          : genreReviews.fold<double>(0.0, (s, r) => s + r.score) /
              genreReviews.length;

      final reviewCount = genreReviews.length;

      // Preference strength now incorporates temporal decay
      final preferenceStrength =
          (avgRating / 5.0) * (reviewCount / totalReviews) * 2.0;

      // Get favorite artists in this genre
      final artistRatings = <String, List<double>>{};
      for (final review in genreReviews) {
        artistRatings.putIfAbsent(review.artist, () => []).add(review.score);
      }

      final favoriteArtists = artistRatings.entries
          .where((e) {
            final avg =
                e.value.fold<double>(0.0, (sum, r) => sum + r) / e.value.length;
            return avg >= 4.0;
          })
          .map((e) => e.key)
          .take(5)
          .toList();

      preferences[genre] = GenrePreference(
        genre: genre,
        averageRating: avgRating,
        reviewCount: reviewCount,
        preferenceStrength: preferenceStrength.clamp(0.0, 1.0),
        favoriteArtists: favoriteArtists,
      );
    });

    return preferences;
  }
  
  /// Analyze artist preferences (with temporal decay — Grainger Ch. 5).
  static Map<String, ArtistPreference> _analyzeArtistPreferences(
    List<Review> reviews,
  ) {
    final artistData = <String, List<Review>>{};

    // Group reviews by artist
    for (final review in reviews) {
      artistData.putIfAbsent(review.artist, () => []).add(review);
    }

    final preferences = <String, ArtistPreference>{};

    artistData.forEach((artist, artistReviews) {
      // Weighted average rating using temporal decay
      double weightedRatingSum = 0.0;
      double decayWeightSum = 0.0;

      for (final review in artistReviews) {
        final decay = review.date != null
            ? ScoringUtils.temporalDecay(review.date!, halfLifeDays: 30.0)
            : 0.5;
        weightedRatingSum += review.score * decay;
        decayWeightSum += decay;
      }

      final avgRating = decayWeightSum > 0
          ? weightedRatingSum / decayWeightSum
          : artistReviews.fold<double>(0.0, (s, r) => s + r.score) /
              artistReviews.length;

      // Calculate consistency (lower std dev = more consistent)
      final ratings = artistReviews.map((r) => r.score).toList();
      final rawAvg =
          ratings.fold<double>(0.0, (sum, r) => sum + r) / ratings.length;
      final variance = ratings.fold<double>(
            0.0,
            (sum, r) => sum + (r - rawAvg) * (r - rawAvg),
          ) /
          ratings.length;
      final consistency = 1.0 - (variance / 5.0).clamp(0.0, 1.0);

      // Temporal-decay based recency bonus (replaces binary 30-day check)
      double recencyBonus = 0.0;
      for (final review in artistReviews) {
        if (review.date != null) {
          recencyBonus +=
              ScoringUtils.temporalDecay(review.date!, halfLifeDays: 30.0);
        }
      }
      recencyBonus = artistReviews.isEmpty
          ? 0.0
          : (recencyBonus / artistReviews.length) * 0.3;

      // Preference score
      final preferenceScore = (avgRating / 5.0) *
              (artistReviews.length / 10.0).clamp(0.0, 1.0) *
              (1.0 + consistency * 0.2) +
          recencyBonus;

      DateTime? lastReviewed;
      final reviewsWithDates =
          artistReviews.where((r) => r.date != null).toList();
      if (reviewsWithDates.isNotEmpty) {
        lastReviewed = reviewsWithDates
            .map((r) => r.date!)
            .reduce((a, b) => a.isAfter(b) ? a : b);
      }

      preferences[artist] = ArtistPreference(
        artist: artist,
        averageRating: avgRating,
        reviewCount: artistReviews.length,
        consistency: consistency,
        lastReviewed: lastReviewed,
        preferenceScore: preferenceScore.clamp(0.0, 1.0),
      );
    });

    return preferences;
  }
  
  /// Analyze review text sentiment and keywords
  static ReviewSentiment _analyzeReviewSentiment(List<Review> reviews) {
    final positiveWords = <String>['love', 'amazing', 'perfect', 'beautiful', 
                                   'great', 'excellent', 'incredible', 'best',
                                   'fantastic', 'wonderful', 'brilliant', 'masterpiece'];
    final negativeWords = <String>['boring', 'overrated', 'disappointing', 
                                    'bad', 'terrible', 'awful', 'worst',
                                    'hate', 'dislike', 'mediocre', 'weak'];
    
    double totalSentiment = 0.0;
    final wordFrequency = <String, int>{};
    final mentionedArtists = <String>{};
    final mentionedGenres = <String>{};
    
    for (final review in reviews) {
      final text = review.review.toLowerCase();
      
      // Calculate sentiment
      int positiveCount = 0;
      int negativeCount = 0;
      
      for (final word in positiveWords) {
        if (text.contains(word)) positiveCount++;
      }
      for (final word in negativeWords) {
        if (text.contains(word)) negativeCount++;
      }
      
      final sentiment = positiveCount > negativeCount 
          ? 0.5 + (positiveCount * 0.1).clamp(0.0, 0.5)
          : 0.5 - (negativeCount * 0.1).clamp(0.0, 0.5);
      
      totalSentiment += sentiment;
      
      // Extract keywords (simple approach - can be enhanced with NLP)
      final words = text.split(RegExp(r'[^\w]+'));
      for (final word in words) {
        if (word.length > 4) { // Ignore short words
          wordFrequency[word] = (wordFrequency[word] ?? 0) + 1;
        }
      }
    }
    
    final avgSentiment = reviews.isEmpty 
        ? 0.5 
        : totalSentiment / reviews.length;
    
    // Get top keywords
    final topKeywords = wordFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return ReviewSentiment(
      sentimentScore: avgSentiment,
      keywords: topKeywords.take(20).map((e) => e.key).toList(),
      mentionedArtists: mentionedArtists.toList(),
      mentionedGenres: mentionedGenres.toList(),
      wordFrequency: wordFrequency,
    );
  }
  
  /// Analyze temporal patterns (taste evolution)
  static TemporalPatterns _analyzeTemporalPatterns(List<Review> reviews) {
    if (reviews.length < 10) {
      return TemporalPatterns(
        tasteEvolution: {},
        recentTrends: [],
        seasonalPatterns: {},
      );
    }
    
    // Group by time periods
    final now = DateTime.now();
    final last30Days = reviews.where((r) {
      if (r.date == null) return false;
      return now.difference(r.date!).inDays <= 30;
    }).toList();
    
    final last90Days = reviews.where((r) {
      if (r.date == null) return false;
      return now.difference(r.date!).inDays <= 90;
    }).toList();
    
    // Calculate average ratings by period
    final recentAvg = last30Days.isEmpty
        ? 0.0
        : last30Days.fold<double>(0.0, (sum, r) => sum + r.score) / 
          last30Days.length;
    
    final olderReviews = reviews.length > last90Days.length
        ? reviews.skip(last90Days.length).take(10).toList()
        : <Review>[];
    
    final olderAvg = olderReviews.isEmpty
        ? 0.0
        : olderReviews.fold<double>(
            0.0,
            (sum, r) => sum + r.score,
          ) / olderReviews.length;
    
    // Genre trends
    final recentGenres = <String, int>{};
    for (final review in last30Days) {
      if (review.genres != null) {
        for (final genre in review.genres!) {
          recentGenres[genre] = (recentGenres[genre] ?? 0) + 1;
        }
      }
    }
    
    final topRecentGenres = recentGenres.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return TemporalPatterns(
      tasteEvolution: {
        'recent_avg': recentAvg,
        'older_avg': olderAvg,
        'trend': recentAvg > olderAvg ? 'increasing' : 'decreasing',
      },
      recentTrends: topRecentGenres.take(5).map((e) => e.key).toList(),
      seasonalPatterns: {}, // Can be enhanced with month-based analysis
    );
  }
}

// Data models
class UserReviewProfile {
  final RatingPattern ratingPattern;
  final Map<String, GenrePreference> genrePreferences;
  final Map<String, ArtistPreference> artistPreferences;
  final ReviewSentiment reviewSentiment;
  final TemporalPatterns temporalPatterns;
  
  UserReviewProfile({
    required this.ratingPattern,
    required this.genrePreferences,
    required this.artistPreferences,
    required this.reviewSentiment,
    required this.temporalPatterns,
  });
}

class RatingPattern {
  final double averageRating;
  final double recentAverageRating;
  final Map<int, int> ratingDistribution;
  final double ratingVolatility;
  final List<String> highlyRatedArtists;
  final List<String> lowRatedArtists;
  
  RatingPattern({
    required this.averageRating,
    required this.recentAverageRating,
    required this.ratingDistribution,
    required this.ratingVolatility,
    required this.highlyRatedArtists,
    required this.lowRatedArtists,
  });
}

class GenrePreference {
  final String genre;
  final double averageRating;
  final int reviewCount;
  final double preferenceStrength;
  final List<String> favoriteArtists;
  
  GenrePreference({
    required this.genre,
    required this.averageRating,
    required this.reviewCount,
    required this.preferenceStrength,
    required this.favoriteArtists,
  });
}

class ArtistPreference {
  final String artist;
  final double averageRating;
  final int reviewCount;
  final double consistency;
  final DateTime? lastReviewed;
  final double preferenceScore;
  
  ArtistPreference({
    required this.artist,
    required this.averageRating,
    required this.reviewCount,
    required this.consistency,
    this.lastReviewed,
    required this.preferenceScore,
  });
}

class ReviewSentiment {
  final double sentimentScore;
  final List<String> keywords;
  final List<String> mentionedArtists;
  final List<String> mentionedGenres;
  final Map<String, int> wordFrequency;
  
  ReviewSentiment({
    required this.sentimentScore,
    required this.keywords,
    required this.mentionedArtists,
    required this.mentionedGenres,
    required this.wordFrequency,
  });
}

class TemporalPatterns {
  final Map<String, dynamic> tasteEvolution;
  final List<String> recentTrends;
  final Map<String, dynamic> seasonalPatterns;
  
  TemporalPatterns({
    required this.tasteEvolution,
    required this.recentTrends,
    required this.seasonalPatterns,
  });
}

/// Cached review profile with metadata
class CachedReviewProfile {
  final UserReviewProfile profile;
  final int cachedReviewCount;
  final DateTime? lastUpdated;
  
  CachedReviewProfile({
    required this.profile,
    required this.cachedReviewCount,
    this.lastUpdated,
  });
}
