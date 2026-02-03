import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/models/enhanced_user_preferences.dart';

/// Service to analyze reviews and preferences to extract key music profile insights
class MusicProfileInsightsService {
  /// Get music profile insights from reviews and preferences
  /// Returns: { favoriteArtists: [], favoriteGenres: [], mostCommonAlbum: String? }
  static Future<MusicProfileInsights> getProfileInsights(String userId) async {
    try {
      // Fetch user reviews
      final reviewsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reviews')
          .orderBy('date', descending: true)
          .get();

      final reviews = reviewsSnapshot.docs
          .map((doc) => Review.fromFirestore(doc.data()))
          .toList();

      // Fetch user preferences
      final prefsDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('musicPreferences')
          .doc('profile')
          .get();

      EnhancedUserPreferences? preferences;
      if (prefsDoc.exists && prefsDoc.data() != null) {
        preferences = EnhancedUserPreferences.fromJson(prefsDoc.data()!);
      }

      // Analyze reviews to extract insights
      final favoriteArtists = _extractFavoriteArtists(reviews, preferences);
      final favoriteGenres = _extractFavoriteGenres(reviews, preferences);
      final mostCommonAlbum = _extractMostCommonAlbum(reviews);

      return MusicProfileInsights(
        favoriteArtists: favoriteArtists,
        favoriteGenres: favoriteGenres,
        mostCommonAlbum: mostCommonAlbum,
      );
    } catch (e) {
      print('Error getting profile insights: $e');
      return MusicProfileInsights(
        favoriteArtists: [],
        favoriteGenres: [],
        mostCommonAlbum: null,
      );
    }
  }

  /// Extract favorite artists from reviews and preferences
  static List<String> _extractFavoriteArtists(
    List<Review> reviews,
    EnhancedUserPreferences? preferences,
  ) {
    // Combine artists from preferences and reviews
    final artistScores = <String, ArtistScore>{};

    // Add artists from preferences (if they exist)
    if (preferences != null && preferences.favoriteArtists.isNotEmpty) {
      for (var artist in preferences.favoriteArtists) {
        artistScores[artist] = ArtistScore(
          name: artist,
          reviewCount: 0,
          averageRating: 0.0,
          fromPreferences: true,
        );
      }
    }

    // Analyze reviews to score artists
    final artistReviews = <String, List<Review>>{};
    for (var review in reviews) {
      artistReviews.putIfAbsent(review.artist, () => []).add(review);
    }

    // Calculate scores for each artist
    artistReviews.forEach((artist, artistReviewList) {
      final avgRating = artistReviewList.fold<double>(
            0.0,
            (sum, r) => sum + r.score,
          ) /
          artistReviewList.length;

      // Score based on: average rating, number of reviews, and recency
      final reviewCount = artistReviewList.length;
      final recencyBonus = _calculateRecencyBonus(artistReviewList);

      final score = (avgRating / 5.0) * 
                   (reviewCount / 10.0).clamp(0.0, 1.0) * 
                   1.5 + // Boost for multiple reviews
                   recencyBonus;

      final existingScore = artistScores[artist];
      if (existingScore != null) {
        // Merge with preference-based entry
        artistScores[artist] = ArtistScore(
          name: artist,
          reviewCount: reviewCount,
          averageRating: avgRating,
          fromPreferences: true,
          score: score + 0.5, // Bonus for being in preferences
        );
      } else {
        artistScores[artist] = ArtistScore(
          name: artist,
          reviewCount: reviewCount,
          averageRating: avgRating,
          fromPreferences: false,
          score: score,
        );
      }
    });

    // Sort by score and return top artists
    final sortedArtists = artistScores.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    // Return top 10 artists, but only if they have at least 1 review or are in preferences
    return sortedArtists
        .where((a) => a.reviewCount > 0 || a.fromPreferences)
        .take(10)
        .map((a) => a.name)
        .toList();
  }

  /// Extract favorite genres from reviews and preferences
  static List<String> _extractFavoriteGenres(
    List<Review> reviews,
    EnhancedUserPreferences? preferences,
  ) {
    final genreScores = <String, GenreScore>{};

    // Add genres from preferences with their weights
    if (preferences != null) {
      // Add favorite genres from preferences
      for (var genre in preferences.favoriteGenres) {
        final weight = preferences.genreWeights[genre] ?? 0.5;
        genreScores[genre] = GenreScore(
          name: genre,
          reviewCount: 0,
          averageRating: 0.0,
          fromPreferences: true,
          preferenceWeight: weight,
        );
      }

      // Also consider genres with high weights
      preferences.genreWeights.forEach((genre, weight) {
        if (weight >= 0.7 && !genreScores.containsKey(genre)) {
          genreScores[genre] = GenreScore(
            name: genre,
            reviewCount: 0,
            averageRating: 0.0,
            fromPreferences: true,
            preferenceWeight: weight,
          );
        }
      });
    }

    // Analyze reviews to score genres
    final genreReviews = <String, List<Review>>{};
    for (var review in reviews) {
      if (review.genres != null && review.genres!.isNotEmpty) {
        for (var genre in review.genres!) {
          genreReviews.putIfAbsent(genre, () => []).add(review);
        }
      }
    }

    // Calculate scores for each genre
    genreReviews.forEach((genre, genreReviewList) {
      final avgRating = genreReviewList.fold<double>(
            0.0,
            (sum, r) => sum + r.score,
          ) /
          genreReviewList.length;

      final reviewCount = genreReviewList.length;
      final recencyBonus = _calculateRecencyBonus(genreReviewList);

      final score = (avgRating / 5.0) * 
                   (reviewCount / 5.0).clamp(0.0, 1.0) * 
                   1.5 +
                   recencyBonus;

      final existingScore = genreScores[genre];
      if (existingScore != null) {
        // Merge with preference-based entry
        final prefWeight = existingScore.preferenceWeight;
        genreScores[genre] = GenreScore(
          name: genre,
          reviewCount: reviewCount,
          averageRating: avgRating,
          fromPreferences: true,
          preferenceWeight: prefWeight,
          score: score + (prefWeight * 0.5), // Bonus from preferences
        );
      } else {
        genreScores[genre] = GenreScore(
          name: genre,
          reviewCount: reviewCount,
          averageRating: avgRating,
          fromPreferences: false,
          preferenceWeight: 0.0,
          score: score,
        );
      }
    });

    // Sort by score and return top genres
    final sortedGenres = genreScores.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    // Return top 10 genres
    return sortedGenres
        .where((g) => g.reviewCount > 0 || g.fromPreferences)
        .take(10)
        .map((g) => g.name)
        .toList();
  }

  /// Extract most common album from reviews
  /// Note: Since reviews have title (song) and artist, we'll use artist as album proxy
  /// or find the most reviewed artist-title combination
  static String? _extractMostCommonAlbum(List<Review> reviews) {
    if (reviews.isEmpty) return null;

    // Group by artist-title combination (treating as album)
    final albumCounts = <String, int>{};
    for (var review in reviews) {
      // Use "Artist - Title" as album identifier
      final albumKey = '${review.artist} - ${review.title}';
      albumCounts[albumKey] = (albumCounts[albumKey] ?? 0) + 1;
    }

    if (albumCounts.isEmpty) return null;

    // Find the most common album
    final sortedAlbums = albumCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final mostCommon = sortedAlbums.first;

    // Only return if it appears at least 2 times (to avoid single-review albums)
    if (mostCommon.value >= 2) {
      return mostCommon.key;
    }

    // If no album appears multiple times, return the artist of the most reviewed song
    if (reviews.isNotEmpty) {
      final artistCounts = <String, int>{};
      for (var review in reviews) {
        artistCounts[review.artist] = (artistCounts[review.artist] ?? 0) + 1;
      }
      final topArtist = artistCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      if (topArtist.isNotEmpty) {
        return topArtist.first.key;
      }
    }

    return null;
  }

  /// Calculate recency bonus for reviews (recent reviews weighted more)
  static double _calculateRecencyBonus(List<Review> reviews) {
    if (reviews.isEmpty) return 0.0;

    final now = DateTime.now();
    double bonus = 0.0;
    int recentCount = 0;

    for (var review in reviews) {
      if (review.date != null) {
        final daysAgo = now.difference(review.date!).inDays;
        if (daysAgo <= 30) {
          recentCount++;
          bonus += 0.1 * (1.0 - (daysAgo / 30.0)); // Decay over 30 days
        }
      }
    }

    // Normalize by review count
    return bonus / reviews.length;
  }

  /// Get insights for current user
  static Future<MusicProfileInsights> getCurrentUserInsights() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return MusicProfileInsights(
        favoriteArtists: [],
        favoriteGenres: [],
        mostCommonAlbum: null,
      );
    }
    return getProfileInsights(user.uid);
  }

  /// Update music profile with insights (can be called to sync insights to profile)
  static Future<void> updateMusicProfileWithInsights(String userId) async {
    try {
      final insights = await getProfileInsights(userId);

      // Get current preferences
      final prefsDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('musicPreferences')
          .doc('profile')
          .get();

      if (!prefsDoc.exists) {
        // Create new preferences document
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('musicPreferences')
            .doc('profile')
            .set({
          'favoriteArtists': insights.favoriteArtists,
          'favoriteGenres': insights.favoriteGenres,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      } else {
        // Update existing preferences
        final currentData = prefsDoc.data()!;
        final updatedData = Map<String, dynamic>.from(currentData);

        // Merge favorite artists (keep existing, add new)
        final existingArtists = List<String>.from(
          currentData['favoriteArtists'] ?? [],
        );
        for (var artist in insights.favoriteArtists) {
          if (!existingArtists.contains(artist)) {
            existingArtists.add(artist);
          }
        }
        updatedData['favoriteArtists'] = existingArtists.take(20).toList();

        // Merge favorite genres (keep existing, add new)
        final existingGenres = List<String>.from(
          currentData['favoriteGenres'] ?? [],
        );
        for (var genre in insights.favoriteGenres) {
          if (!existingGenres.contains(genre)) {
            existingGenres.add(genre);
          }
        }
        updatedData['favoriteGenres'] = existingGenres.take(20).toList();

        // Add mostCommonAlbum if available
        if (insights.mostCommonAlbum != null) {
          updatedData['mostCommonAlbum'] = insights.mostCommonAlbum;
        }

        updatedData['lastUpdated'] = FieldValue.serverTimestamp();

        await prefsDoc.reference.update(updatedData);
      }

      print('✅ Updated music profile with insights');
    } catch (e) {
      print('Error updating music profile: $e');
    }
  }
}

/// Data model for music profile insights
class MusicProfileInsights {
  final List<String> favoriteArtists;
  final List<String> favoriteGenres;
  final String? mostCommonAlbum;

  MusicProfileInsights({
    required this.favoriteArtists,
    required this.favoriteGenres,
    this.mostCommonAlbum,
  });

  /// Convert to JSON format matching the music profile structure
  Map<String, dynamic> toJson() {
    return {
      'favoriteArtists': favoriteArtists,
      'favoriteGenres': favoriteGenres,
      if (mostCommonAlbum != null) 'mostCommonAlbum': mostCommonAlbum,
    };
  }

  @override
  String toString() {
    return 'MusicProfileInsights('
        'favoriteArtists: $favoriteArtists, '
        'favoriteGenres: $favoriteGenres, '
        'mostCommonAlbum: $mostCommonAlbum)';
  }
}

/// Helper class for artist scoring
class ArtistScore {
  final String name;
  final int reviewCount;
  final double averageRating;
  final bool fromPreferences;
  final double score;

  ArtistScore({
    required this.name,
    required this.reviewCount,
    required this.averageRating,
    required this.fromPreferences,
    this.score = 0.0,
  });
}

/// Helper class for genre scoring
class GenreScore {
  final String name;
  final int reviewCount;
  final double averageRating;
  final bool fromPreferences;
  final double preferenceWeight;
  final double score;

  GenreScore({
    required this.name,
    required this.reviewCount,
    required this.averageRating,
    required this.fromPreferences,
    required this.preferenceWeight,
    this.score = 0.0,
  });
}
