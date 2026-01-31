import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test_project/models/enhanced_user_preferences.dart';
import 'package:flutter_test_project/models/music_recommendation.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:spotify/spotify.dart';
import 'package:flutter_test_project/Api/api_key.dart';

/// Enhanced recommendation algorithm focused on discovery
class RecommendationEnhancements {
  /// Calculate diversity score for a list of recommendations
  /// Higher score = more diverse (different genres, artists, eras)
  static double calculateDiversityScore(List<MusicRecommendation> recommendations) {
    if (recommendations.isEmpty) return 0.0;

    // Genre diversity
    final genreSet = <String>{};
    for (var rec in recommendations) {
      genreSet.addAll(rec.genres);
    }
    final genreDiversity = genreSet.length / recommendations.length;

    // Artist diversity
    final artistSet = <String>{};
    for (var rec in recommendations) {
      artistSet.add(rec.artist.toLowerCase().trim());
    }
    final artistDiversity = artistSet.length / recommendations.length;

    // Combined diversity score (weighted)
    return (genreDiversity * 0.6) + (artistDiversity * 0.4);
  }

  /// Find similar users based on review patterns (collaborative filtering)
  static Future<List<String>> findSimilarUsers(String currentUserId) async {
    try {
      // Get current user's top rated artists
      final currentUserReviews = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('reviews')
          .where('score', isGreaterThan: 3.5)
          .get();

      final currentUserArtists = <String>{};
      for (var doc in currentUserReviews.docs) {
        final review = Review.fromFirestore(doc.data());
        currentUserArtists.add(review.artist.toLowerCase().trim());
      }

      if (currentUserArtists.isEmpty) return [];

      // Find users who reviewed similar artists
      final similarUsers = <String, int>{};
      
      // Get all reviews from community
      final allReviews = await FirebaseFirestore.instance
          .collectionGroup('reviews')
          .where('score', isGreaterThan: 3.5)
          .limit(500) // Limit for performance
          .get();

      for (var doc in allReviews.docs) {
        final review = Review.fromFirestore(doc.data());
        final userId = review.userId;
        
        if (userId == currentUserId) continue;
        
        final artist = review.artist.toLowerCase().trim();
        if (currentUserArtists.contains(artist)) {
          similarUsers[userId] = (similarUsers[userId] ?? 0) + 1;
        }
      }

      // Sort by similarity score and return top 10
      final sortedUsers = similarUsers.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      return sortedUsers.take(10).map((e) => e.key).toList();
    } catch (e) {
      print('Error finding similar users: $e');
      return [];
    }
  }

  /// Get recommendations from similar users (collaborative filtering)
  static Future<List<MusicRecommendation>> getCollaborativeRecommendations(
    String currentUserId,
    List<String> similarUserIds,
  ) async {
    try {
      final recommendations = <MusicRecommendation, int>{};
      
      // Get highly rated tracks from similar users that current user hasn't reviewed
      final currentUserReviews = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('reviews')
          .get();

      final reviewedTracks = <String>{};
      for (var doc in currentUserReviews.docs) {
        final review = Review.fromFirestore(doc.data());
        reviewedTracks.add('${review.artist}|${review.title}'.toLowerCase());
      }

      // Collect recommendations from similar users
      for (var userId in similarUserIds.take(5)) { // Limit to top 5 similar users
        final userReviews = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('reviews')
            .where('score', isGreaterThan: 4.0)
            .limit(10)
            .get();

        for (var doc in userReviews.docs) {
          final review = Review.fromFirestore(doc.data());
          final trackKey = '${review.artist}|${review.title}'.toLowerCase();
          
          if (!reviewedTracks.contains(trackKey)) {
            final rec = MusicRecommendation(
              song: review.title,
              artist: review.artist,
              album: '',
              imageUrl: review.albumImageUrl ?? '',
              genres: [],
            );
            
            recommendations[rec] = (recommendations[rec] ?? 0) + 1;
          }
        }
      }

      // Sort by popularity among similar users
      final sortedRecs = recommendations.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sortedRecs.take(5).map((e) => e.key).toList();
    } catch (e) {
      print('Error getting collaborative recommendations: $e');
      return [];
    }
  }

  /// Get Spotify-based recommendations using seed tracks/artists
  static Future<List<MusicRecommendation>> getSpotifyRecommendations(
    EnhancedUserPreferences preferences,
    int count,
  ) async {
    try {
      final credentials = SpotifyApiCredentials(clientId, clientSecret);
      final spotify = SpotifyApi(credentials);

      // Get seed tracks from user's saved tracks
      final seedTracks = <String>[];
      final seedArtists = <String>{};
      
      // Extract artist names from saved tracks
      for (var saved in preferences.savedTracks.take(10)) {
        // Parse "artist: ArtistName, song: SongName" format
        if (saved.contains('artist:')) {
          final parts = saved.split('artist:')[1].split(',');
          if (parts.isNotEmpty) {
            seedArtists.add(parts[0].trim());
          }
        }
      }

      // If we have favorite artists, use them as seeds
      if (preferences.favoriteArtists.isNotEmpty) {
        seedArtists.addAll(preferences.favoriteArtists.take(5));
      }

      if (seedArtists.isEmpty) {
        return []; // Can't make recommendations without seeds
      }

      // Use Spotify's search to find similar tracks based on favorite artists
      // Since the recommendations API may not be available, we'll use search-based discovery
      final musicRecs = <MusicRecommendation>[];
      
      // Search for recent releases from similar artists or in similar genres
      for (var artistName in seedArtists.take(3)) {
        try {
          // Search for tracks by this artist from recent years (discovery focus)
          final currentYear = DateTime.now().year;
          final searchQuery = 'artist:"$artistName" year:$currentYear-${currentYear - 2}';
          
          final searchResults = await spotify.search
              .get(searchQuery, types: [SearchType.track])
              .first(2); // Get 2 tracks per artist
          
          for (var page in searchResults) {
            if (page.items != null) {
              for (var item in page.items!) {
                if (item is Track && item.name != null && item.artists != null && item.artists!.isNotEmpty) {
                  // Get genres from artist
                  final genres = <String>[];
                  try {
                    if (item.artists!.isNotEmpty && item.artists!.first.id != null) {
                      final artist = await spotify.artists.get(item.artists!.first.id!);
                      genres.addAll(artist.genres ?? []);
                    }
                  } catch (e) {
                    // If we can't get artist details, continue without genres
                  }

                  final imageUrl = item.album?.images?.isNotEmpty == true
                      ? item.album!.images!.first.url ?? ''
                      : '';

                  musicRecs.add(MusicRecommendation(
                    song: item.name!,
                    artist: item.artists!.map((a) => a.name ?? '').where((n) => n.isNotEmpty).join(', '),
                    album: item.album?.name ?? '',
                    imageUrl: imageUrl,
                    genres: genres,
                  ));
                  
                  if (musicRecs.length >= count) break;
                }
              }
            }
            if (musicRecs.length >= count) break;
          }
          
          if (musicRecs.length >= count) break;
          
          // Small delay to avoid rate limiting
          await Future.delayed(const Duration(milliseconds: 200));
        } catch (e) {
          print('Error searching for artist $artistName: $e');
          continue;
        }
      }

      return musicRecs;
    } catch (e) {
      print('Error getting Spotify recommendations: $e');
      return [];
    }
  }

  /// Post-process recommendations to ensure diversity
  static List<MusicRecommendation> ensureDiversity(
    List<MusicRecommendation> recommendations,
    {int minGenres = 3, int minArtists = 5}
  ) {
    if (recommendations.length <= minArtists) {
      return recommendations;
    }

    final selected = <MusicRecommendation>[];
    final usedGenres = <String>{};
    final usedArtists = <String>{};

    // First pass: prioritize diverse recommendations
    for (var rec in recommendations) {
      final artist = rec.artist.toLowerCase().trim();
      final hasNewGenre = rec.genres.any((g) => !usedGenres.contains(g.toLowerCase()));
      final hasNewArtist = !usedArtists.contains(artist);

      // Prefer recommendations that add diversity
      if (hasNewGenre || hasNewArtist) {
        selected.add(rec);
        usedArtists.add(artist);
        usedGenres.addAll(rec.genres.map((g) => g.toLowerCase()));
      }

      if (selected.length >= recommendations.length) break;
    }

    // Second pass: fill remaining slots
    for (var rec in recommendations) {
      if (selected.length >= recommendations.length) break;
      if (!selected.contains(rec)) {
        selected.add(rec);
      }
    }

    return selected;
  }

  /// Calculate novelty score (how "new" or "undiscovered" a track is for the user)
  static double calculateNoveltyScore(
    MusicRecommendation recommendation,
    EnhancedUserPreferences preferences,
  ) {
    double score = 1.0; // Start with full novelty

    final artist = recommendation.artist.toLowerCase().trim();
    final song = recommendation.song.toLowerCase().trim();

    // Reduce novelty if artist is in favorites
    if (preferences.favoriteArtists.any((a) => a.toLowerCase().trim() == artist)) {
      score *= 0.5;
    }

    // Reduce novelty if track is similar to saved tracks
    for (var saved in preferences.savedTracks) {
      if (saved.toLowerCase().contains(artist) || saved.toLowerCase().contains(song)) {
        score *= 0.3;
        break;
      }
    }

    // Increase novelty if genres are less explored
    final genreNovelty = recommendation.genres.where((g) {
      final genreWeight = preferences.genreWeights[g] ?? 0.0;
      return genreWeight < 0.5; // Less explored genres
    }).length / (recommendation.genres.length + 1);

    score *= (1.0 + genreNovelty * 0.5);

    return score.clamp(0.0, 1.0);
  }

  /// Balance recommendations: mix safe bets with discoveries
  static List<MusicRecommendation> balanceRecommendations(
    List<MusicRecommendation> allRecommendations,
    EnhancedUserPreferences preferences,
    {double discoveryRatio = 0.6} // 60% discovery, 40% safe
  ) {
    if (allRecommendations.isEmpty) return [];

    // Score each recommendation
    final scored = allRecommendations.map((rec) {
      final novelty = calculateNoveltyScore(rec, preferences);
      final genreMatch = rec.genres.fold<double>(
        0.0,
        (sum, genre) => sum + (preferences.genreWeights[genre] ?? 0.0),
      ) / (rec.genres.length + 1);

      // Discovery score: high novelty + some genre relevance
      final discoveryScore = (novelty * 0.7) + (genreMatch * 0.3);
      
      // Safe score: high genre match + lower novelty
      final safeScore = (genreMatch * 0.8) + (novelty * 0.2);

      return {
        'rec': rec,
        'discoveryScore': discoveryScore,
        'safeScore': safeScore,
      };
    }).toList();

    // Sort by discovery and safe scores
    scored.sort((a, b) => (b['discoveryScore'] as double).compareTo(a['discoveryScore'] as double));
    final discoveryRecs = scored.take((allRecommendations.length * discoveryRatio).round())
        .map((e) => e['rec'] as MusicRecommendation).toList();

    scored.sort((a, b) => (b['safeScore'] as double).compareTo(a['safeScore'] as double));
    final safeRecs = scored.take((allRecommendations.length * (1 - discoveryRatio)).round())
        .map((e) => e['rec'] as MusicRecommendation).toList();

    // Combine and ensure diversity
    final combined = [...discoveryRecs, ...safeRecs];
    return ensureDiversity(combined.take(allRecommendations.length).toList());
  }
}
