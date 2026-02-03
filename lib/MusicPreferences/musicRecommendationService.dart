import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test_project/Api/api_key.dart';
import 'package:flutter_test_project/models/enhanced_user_preferences.dart';
import 'package:flutter_test_project/models/music_recommendation.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/utils/reviews/review_helpers.dart';
import 'package:flutter_test_project/MusicPreferences/recommendation_enhancements.dart';
import 'package:flutter_test_project/services/get_album_service.dart';
import 'package:flutter_test_project/services/genre_cache_service.dart';
import 'package:flutter_test_project/services/review_analysis_service.dart';
import 'package:http/http.dart' as http;
import 'package:spotify/spotify.dart';

class MusicRecommendationService {
  static const _openAiEndpoint = 'https://api.openai.com/v1/chat/completions';
  static const _model = 'gpt-3.5-turbo';
  static const _maxRetries = 3;
  static const _timeoutDuration = Duration(seconds: 30);

  // Cache for recent recommendations to avoid duplicates
  static final Set<String> _recentRecommendations = <String>{};
  static const int _maxRecentRecommendations = 50;
  
  // Cache for validation results to avoid re-validating the same tracks
  static final Map<String, bool> _validationCache = <String, bool>{};
  static const int _maxValidationCacheSize = 200;

  static Future<List<MusicRecommendation>> getRecommendations(
    EnhancedUserPreferences preferencesJson, {
    int count = 10,
    List<String>? excludeSongs,
    bool useEnhancedAlgorithm = true, // Enable enhanced discovery algorithm
    bool skipValidation = false, // OPTIMIZATION: Skip validation for faster results (use with caution)
    String validationMode = 'spotify-only', // 'spotify-only' (fast, no MusicBrainz), 'hybrid' (MusicBrainz+Spotify), 'none' (skip)
    int validateTopN = 0, // OPTIMIZATION: Only validate top N (0 = validate all)
    bool skipMetadataEnrichment = false, // OPTIMIZATION: Skip Spotify metadata (images, etc.) for speed
  }) async {
    try {
      final userId = FirebaseAuth.instance.currentUser != null
          ? FirebaseAuth.instance.currentUser!.uid
          : '';
      
      if (userId.isEmpty) {
        throw const MusicRecommendationException('User not logged in');
      }

      // NEW: Analyze all user reviews for deep personalization (with caching)
      UserReviewProfile? reviewProfile;
      try {
        print('Analyzing user reviews for personalized recommendations...');
        // Use cached version if available (faster)
        reviewProfile = await ReviewAnalysisService.analyzeUserReviews(userId, forceRefresh: false);
        print('Review analysis complete: ${reviewProfile.ratingPattern.averageRating.toStringAsFixed(1)} avg rating');
      } catch (e) {
        print('Error analyzing reviews (will use basic method): $e');
      }

      // Get recent reviews for AI prompt (still include some recent context)
      final List<Review> reviews = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reviews')
          .orderBy('date', descending: true)
          .limit(10)
          .get()
          .then((snapshot) => snapshot.docs
              .map((doc) => Review.fromFirestore(doc.data()))
              .toList());

      final List<dynamic> reviewList = [];
      for (final review in reviews.take(5)) {
        reviewList.add({
          'song': review.title,
          'artist': review.artist,
          'review': review.review,
          'rating': review.score,
        });
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('musicPreferences')
          .doc('profile')
          .get();

      if (!doc.exists) {
        throw const MusicRecommendationException('User preferences not found');
      }

      final EnhancedUserPreferences preferences =
          EnhancedUserPreferences.fromJson(doc.data()!);

      final List<MusicRecommendation> allRecommendations = [];

      // 1. Get AI-based recommendations (improved prompt with review analysis)
      try {
        final prompt = _buildEnhancedPrompt(
          preferences, 
          count, 
          excludeSongs, 
          reviewList,
          reviewProfile,  // Pass review analysis
        );
        print('Fetching AI recommendations with review analysis...');
        final response = await _makeApiRequest(prompt);
        final aiRecommendations = _parseRecommendations(response);
        
        // OPTIMIZATION: Only validate AI recommendations (Spotify recs are already validated)
        if (skipValidation || validationMode == 'none') {
          // Skip validation for faster results
          print('Skipping validation for faster results (${aiRecommendations.length} AI recommendations)');
          allRecommendations.addAll(aiRecommendations);
        } else {
          // Determine which recommendations to validate
          final recsToValidate = validateTopN > 0 && validateTopN < aiRecommendations.length
              ? aiRecommendations.take(validateTopN).toList()
              : aiRecommendations;
          
          final recsToSkip = validateTopN > 0 && validateTopN < aiRecommendations.length
              ? aiRecommendations.skip(validateTopN).toList()
              : <MusicRecommendation>[];
          
          if (recsToValidate.isNotEmpty) {
            print('Validating ${recsToValidate.length} AI recommendations (mode: $validationMode)...');
            final validatedRecommendations = await _validateRecommendationsOptimized(
              recsToValidate,
              validationMode: validationMode,
              skipMetadataEnrichment: skipMetadataEnrichment,
            );
            allRecommendations.addAll(validatedRecommendations);
            print('Got ${validatedRecommendations.length} validated AI recommendations (${recsToValidate.length - validatedRecommendations.length} filtered out)');
          }
          
          // Add unvalidated recommendations if validating only top N
          if (recsToSkip.isNotEmpty) {
            print('Skipping validation for ${recsToSkip.length} lower-priority recommendations');
            allRecommendations.addAll(recsToSkip);
          }
        }
      } catch (e) {
        print('Error getting AI recommendations: $e');
      }

      // 2. Get collaborative filtering recommendations (if enabled)
      if (useEnhancedAlgorithm) {
        try {
          print('Finding similar users...');
          final similarUsers = await RecommendationEnhancements.findSimilarUsers(userId);
          if (similarUsers.isNotEmpty) {
            print('Found ${similarUsers.length} similar users');
            final collaborativeRecs = await RecommendationEnhancements
                .getCollaborativeRecommendations(userId, similarUsers);
            allRecommendations.addAll(collaborativeRecs);
            print('Got ${collaborativeRecs.length} collaborative recommendations');
          }
        } catch (e) {
          print('Error getting collaborative recommendations: $e');
        }

        // 3. Get Spotify API recommendations (if user has saved tracks/artists)
        try {
          if (preferences.savedTracks.isNotEmpty || preferences.favoriteArtists.isNotEmpty) {
            print('Fetching Spotify recommendations...');
            final spotifyRecs = await RecommendationEnhancements
                .getSpotifyRecommendations(preferences, count ~/ 2);
            allRecommendations.addAll(spotifyRecs);
            print('Got ${spotifyRecs.length} Spotify recommendations');
          }
        } catch (e) {
          print('Error getting Spotify recommendations: $e');
        }
      }

      // Remove duplicates and saved tracks
      var filteredRecs = removeDuplication(allRecommendations, preferences);
      
      // Remove excluded songs
      if (excludeSongs != null && excludeSongs.isNotEmpty) {
        final excludeSet = excludeSongs.map((s) => s.toLowerCase().trim()).toSet();
        filteredRecs = filteredRecs.where((rec) {
          final key = '${rec.artist}|${rec.song}'.toLowerCase();
          return !excludeSet.contains(key);
        }).toList();
      }

      // 4. Score recommendations based on review analysis (if available)
      if (reviewProfile != null && filteredRecs.isNotEmpty) {
        final scoredRecs = filteredRecs.map((rec) {
          final score = _scoreRecommendationFromReviews(rec, reviewProfile!);
          return {'rec': rec, 'score': score};
        }).toList();
        
        // Sort by review-based score
        scoredRecs.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
        
        // Take top scored recommendations
        filteredRecs = scoredRecs
            .take((count * 1.5).round())  // Take more for diversity filtering
            .map((e) => e['rec'] as MusicRecommendation)
            .toList();
      }

      // 5. Apply enhanced algorithm: balance discovery vs safe bets, ensure diversity
      if (useEnhancedAlgorithm && filteredRecs.length > count) {
        // Adjust discovery ratio based on rating pattern
        double discoveryRatio = 0.7; // Default
        if (reviewProfile != null) {
          // If user rates highly, they're more open to discovery
          if (reviewProfile.ratingPattern.averageRating >= 4.0) {
            discoveryRatio = 0.8; // More discovery
          } else if (reviewProfile.ratingPattern.averageRating <= 2.5) {
            discoveryRatio = 0.5; // More safe bets
          }
        }
        
        filteredRecs = RecommendationEnhancements.balanceRecommendations(
          filteredRecs,
          preferences,
          discoveryRatio: discoveryRatio,
        );
        
        // Ensure diversity in final selection
        filteredRecs = RecommendationEnhancements.ensureDiversity(
          filteredRecs,
          minGenres: 3,
          minArtists: (count * 0.6).round(),
        );
      }

      // Take requested count
      filteredRecs = filteredRecs.take(count).toList();
      
      // 5. Enrich recommendations with MusicBrainz genres (hybrid approach)
      print('Enriching recommendations with MusicBrainz genres...');
      filteredRecs = await _enrichRecommendationsWithGenres(filteredRecs);
      
      // Start fetching album images in the background (non-blocking)
      _fetchAlbumImagesInBackground(filteredRecs);

      print('Returning ${filteredRecs.length} final recommendations with genres');
      return filteredRecs;
    } catch (e) {
      throw MusicRecommendationException('Failed to get recommendations: $e');
    }
  }

  /// Build enhanced prompt with review analysis
  static String _buildEnhancedPrompt(
    EnhancedUserPreferences preferences,
    int count,
    List<String>? excludeSongs,
    List<dynamic> reviews,
    UserReviewProfile? reviewProfile,
  ) {
    final excludeList = [
      ..._recentRecommendations,
      ...excludeSongs ?? [],
    ];
    
    // Build review analysis insights
    String reviewAnalysisSection = '';
    if (reviewProfile != null) {
      final ratingInsight = reviewProfile.ratingPattern.averageRating >= 4.0
          ? 'User tends to rate highly - recommend more experimental/discovery music'
          : reviewProfile.ratingPattern.averageRating <= 2.5
              ? 'User is critical - recommend safer, highly-regarded albums'
              : 'User has balanced ratings - mix of safe and discovery';
      
      final topGenres = reviewProfile.genrePreferences.entries.toList()
        ..sort((a, b) => b.value.preferenceStrength.compareTo(a.value.preferenceStrength));
      
      final topArtists = reviewProfile.artistPreferences.entries.toList()
        ..sort((a, b) => b.value.preferenceScore.compareTo(a.value.preferenceScore));
      
      reviewAnalysisSection = '''

DEEP REVIEW ANALYSIS (from ${reviewProfile.ratingPattern.ratingDistribution.values.fold<int>(0, (sum, count) => sum + count)} total reviews):
- Rating Pattern: ${reviewProfile.ratingPattern.averageRating.toStringAsFixed(1)} average rating
  $ratingInsight
- Top Genres from Reviews: ${topGenres.take(5).map((e) => '${e.key} (strength: ${e.value.preferenceStrength.toStringAsFixed(2)})').join(', ')}
- Top Artists from Reviews: ${topArtists.take(5).map((e) => '${e.key} (score: ${e.value.preferenceScore.toStringAsFixed(2)})').join(', ')}
- Recent Trends: ${reviewProfile.temporalPatterns.recentTrends.isNotEmpty ? reviewProfile.temporalPatterns.recentTrends.join(', ') : 'None'}
- Review Sentiment: ${reviewProfile.reviewSentiment.sentimentScore > 0.6 ? 'Generally positive' : reviewProfile.reviewSentiment.sentimentScore < 0.4 ? 'Generally negative' : 'Mixed'}
- Highly Rated Artists: ${reviewProfile.ratingPattern.highlyRatedArtists.take(5).join(', ')}

RECOMMENDATION STRATEGY:
1. PRIORITIZE genres with high preference strength from reviews: ${topGenres.take(3).map((e) => e.key).join(', ')}
2. EXPLORE artists similar to top-rated artists: ${topArtists.take(3).map((e) => e.key).join(', ')}
3. CONSIDER recent trends: ${reviewProfile.temporalPatterns.recentTrends.isNotEmpty ? reviewProfile.temporalPatterns.recentTrends.join(', ') : 'No strong trends'}
4. BALANCE: $ratingInsight
''';
    }

    return '''
You are a music discovery engine. Your goal is to help users discover NEW music they haven't heard before, while still being relevant to their taste.

USER PREFERENCES:
- Favorite Genres: ${jsonEncode(preferences.favoriteGenres)}
- Genre Weights (preference strength): ${jsonEncode(preferences.genreWeights)}
- Favorite Artists: ${jsonEncode(preferences.favoriteArtists)}
- Mood Preferences: ${jsonEncode(preferences.moodPreferences)}
- Tempo Preferences: ${jsonEncode(preferences.tempoPreferences)}
- Saved Tracks (DO NOT recommend these): ${jsonEncode(preferences.savedTracks)}
- Disliked Tracks (AVOID similar): ${jsonEncode(preferences.dislikedTracks)}

RECENT USER REVIEWS (to understand taste):
${jsonEncode(reviews)}
$reviewAnalysisSection

DISCOVERY REQUIREMENTS:
1. PRIORITIZE DISCOVERY: Recommend songs the user likely hasn't heard before
   - Focus on newer releases (2020-2024) when possible
   - Include artists NOT in their favorite artists list
   - Explore genres they like but haven't fully explored (lower genre weights)
   
2. ENSURE DIVERSITY:
   - Include at least 3-4 different genres
   - Don't recommend multiple songs from the same artist
   - Mix different eras (some new, some classic)
   - Balance familiar sounds with surprising discoveries

3. MAINTAIN RELEVANCE:
   - Songs should align with genre preferences (use genre weights)
   - Match mood and tempo preferences when possible
   - Consider patterns from their reviews (what they liked/disliked)

4. AVOID:
   - Songs in savedTracks list
   - Songs in dislikedTracks list
   - Recently recommended songs: ${excludeList.take(10).join(", ")}
   - Songs from artists they've already saved (unless it's a new release)

5. DISCOVERY BALANCE:
   - 60%: New discoveries (artists/genres they haven't explored much)
   - 30%: Safe bets (similar to what they like but new songs)
   - 10%: Serendipitous picks (slightly outside their comfort zone but still relevant)

CRITICAL REQUIREMENTS:
- Return EXACTLY $count recommendations as a JSON array
- ONLY recommend songs that you KNOW exist on Spotify
- DO NOT invent, guess, or create song titles, artist names, or album names
- If you cannot find $count real songs that match the criteria, return fewer (but still valid JSON)
- All recommendations will be validated against Spotify - fake songs will be rejected
- Return ONLY valid JSON, no markdown, no commentary, no explanations

Format:
[{"song":"Title","artist":"Artist","album":"Album","imageUrl":"","genres":["Genre1","Genre2"]}]
''';
  }

  /// Legacy method for backward compatibility
  static String _buildPrompt(EnhancedUserPreferences preferences, int count,
      List<String>? excludeSongs, List<dynamic> reviews) {
    return _buildEnhancedPrompt(preferences, count, excludeSongs, reviews, null);
  }
  
  /// Score recommendation based on review analysis
  static double _scoreRecommendationFromReviews(
    MusicRecommendation recommendation,
    UserReviewProfile reviewProfile,
  ) {
    double score = 0.5; // Base score
    
    // Genre match from reviews (weighted by preference strength)
    for (final genre in recommendation.genres) {
      final genrePref = reviewProfile.genrePreferences[genre];
      if (genrePref != null) {
        score += genrePref.preferenceStrength * 0.3;
      }
    }
    
    // Artist similarity (if similar to highly-rated artists)
    final artist = recommendation.artist.toLowerCase();
    for (final topArtist in reviewProfile.ratingPattern.highlyRatedArtists) {
      final topArtistLower = topArtist.toLowerCase();
      if (artist.contains(topArtistLower) || topArtistLower.contains(artist)) {
        score += 0.2;
        break;
      }
    }
    
    // Check if artist is in user's top artist preferences
    final artistPref = reviewProfile.artistPreferences[recommendation.artist];
    if (artistPref != null && artistPref.preferenceScore > 0.7) {
      score += 0.15;
    }
    
    // Recent trends match
    if (reviewProfile.temporalPatterns.recentTrends.isNotEmpty) {
      final hasTrendGenre = recommendation.genres.any((genre) => 
        reviewProfile.temporalPatterns.recentTrends.contains(genre));
      if (hasTrendGenre) {
        score += 0.1;
      }
    }
    
    return score.clamp(0.0, 1.0);
  }

  static Future<String> _makeApiRequest(String prompt) async {
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $openAIKey',
    };

    final body = jsonEncode({
      'model': _model,
      'temperature': 0.9,
      'max_tokens': 1500,
      // 'top_p': 1.0,
      // 'frequency_penalty': 0.0,
      // 'presence_penalty': 0.0,
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a music recommendation engine. CRITICAL: Only recommend songs that you KNOW exist on Spotify. Do NOT invent, guess, or create song titles, artist names, or album names. All recommendations will be validated against Spotify\'s API - any fake or non-existent songs will be automatically rejected. If you cannot find enough real songs, return fewer valid recommendations rather than inventing fake ones. Respond only with valid JSON arrays.'
        },
        {'role': 'user', 'content': prompt}
      ]
    });

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final response = await http
            .post(Uri.parse(_openAiEndpoint), headers: headers, body: body)
            .timeout(_timeoutDuration);
        print('Response status: ${response.body}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['choices'][0]['message']['content'].trim();
        } else if (response.statusCode == 429 && attempt < _maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 2));
          continue;
        } else {
          throw HttpException(
              'API request failed: ${response.statusCode} ${response.body}');
        }
      } catch (e) {
        if (attempt == _maxRetries) rethrow;
        await Future.delayed(Duration(seconds: attempt));
      }
    }

    throw Exception('Max retries exceeded');
  }

  static List<MusicRecommendation> _parseRecommendations(String response) {
    try {
      // Clean response - remove markdown code blocks if present
      final cleanResponse =
          response.replaceAll('```json', '').replaceAll('```', '').trim();

      final dynamic decoded = jsonDecode(cleanResponse);
      
      // Handle both array and single object responses
      List<dynamic> parsed;
      if (decoded is List) {
        parsed = decoded;
      } else if (decoded is Map) {
        parsed = [decoded];
      } else {
        throw ParseException('Unexpected response format: ${decoded.runtimeType}');
      }

      final recommendations = parsed
          .map((item) {
            try {
              if (item is Map<String, dynamic>) {
                return MusicRecommendation.fromJson(item);
              } else {
                print('Skipping invalid item: $item');
                return null;
              }
            } catch (e) {
              print('Error parsing item $item: $e');
              return null;
            }
          })
          .whereType<MusicRecommendation>()
          .where((rec) => rec.isValid)
          .toList();

      // Update recent recommendations cache
      _updateRecentRecommendations(recommendations);

      return recommendations;
    } catch (e) {
      throw ParseException('Failed to parse recommendations: $e');
    }
  }

  static void _updateRecentRecommendations(
      List<MusicRecommendation> recommendations) {
    for (final rec in recommendations) {
      _recentRecommendations.add('${rec.song} - ${rec.artist}');
    }

    // Keep cache size manageable
    while (_recentRecommendations.length > _maxRecentRecommendations) {
      _recentRecommendations.remove(_recentRecommendations.first);
    }
  }

  static void clearRecentRecommendations() {
    _recentRecommendations.clear();
  }

  /// Optimized validation with caching - faster for repeated requests
  static Future<List<MusicRecommendation>> _validateRecommendationsOptimized(
    List<MusicRecommendation> recommendations, {
    String validationMode = 'hybrid', // 'hybrid' or 'spotify-only'
    bool skipMetadataEnrichment = false,
  }) async {
    if (recommendations.isEmpty) return [];

    try {
      final credentials = SpotifyApiCredentials(clientId, clientSecret);
      final spotify = SpotifyApi(credentials);

      // Check cache first and separate cached vs uncached recommendations
      final uncachedRecs = <MusicRecommendation>[];
      final cachedResults = <MusicRecommendation?>[];
      
      for (final rec in recommendations) {
        final cacheKey = '${rec.song.toLowerCase().trim()}|${rec.artist.toLowerCase().trim()}';
        if (_validationCache.containsKey(cacheKey)) {
          // Use cached result
          if (_validationCache[cacheKey] == true) {
            cachedResults.add(rec);
          } else {
            cachedResults.add(null); // Invalid, filtered out
          }
        } else {
          uncachedRecs.add(rec);
          cachedResults.add(null); // Placeholder, will be filled by validation
        }
      }
      
      print('Validation cache hit: ${recommendations.length - uncachedRecs.length}/${recommendations.length}');
      
      // Only validate uncached recommendations
      if (uncachedRecs.isNotEmpty) {
        // Validate uncached recommendations (with rate limiting for MusicBrainz if needed)
        final validationResults = validationMode == 'spotify-only'
            ? await _validateBatchSpotifyOnly(uncachedRecs, spotify, skipMetadataEnrichment)
            : await _validateBatchWithRateLimit(uncachedRecs, spotify, skipMetadataEnrichment);
        
        // Update cache and results
        int uncachedIndex = 0;
        for (int i = 0; i < recommendations.length; i++) {
          if (cachedResults[i] == null && uncachedIndex < uncachedRecs.length) {
            final rec = uncachedRecs[uncachedIndex];
            final cacheKey = '${rec.song.toLowerCase().trim()}|${rec.artist.toLowerCase().trim()}';
            final validated = validationResults[uncachedIndex];
            
            // Cache the result
            _validationCache[cacheKey] = validated != null;
            _updateValidationCacheSize();
            
            cachedResults[i] = validated;
            uncachedIndex++;
          }
        }
      }

      // Filter to only include validated recommendations
      final validatedRecs = <MusicRecommendation>[];
      for (int i = 0; i < recommendations.length; i++) {
        if (cachedResults[i] != null) {
          validatedRecs.add(cachedResults[i]!);
        }
      }

      return validatedRecs;
    } catch (e) {
      print('Error validating recommendations: $e');
      return [];
    }
  }
  
  /// Validates a batch of recommendations with rate limiting for MusicBrainz
  static Future<List<MusicRecommendation?>> _validateBatchWithRateLimit(
    List<MusicRecommendation> recommendations,
    SpotifyApi spotify,
    bool skipMetadataEnrichment,
  ) async {
    final results = <MusicRecommendation?>[];
    
    // Process in smaller batches to respect MusicBrainz rate limits (1 req/sec)
    for (int i = 0; i < recommendations.length; i++) {
      final rec = recommendations[i];
      final result = await _validateSingleRecommendation(spotify, rec, skipMetadataEnrichment: skipMetadataEnrichment);
      results.add(result);
      
      // Small delay between MusicBrainz requests (rate limit: 1 req/sec)
      if (i < recommendations.length - 1) {
        await Future.delayed(const Duration(milliseconds: 1100));
      }
    }
    
    return results;
  }
  
  /// Fast validation using Spotify only (no MusicBrainz rate limiting)
  static Future<List<MusicRecommendation?>> _validateBatchSpotifyOnly(
    List<MusicRecommendation> recommendations,
    SpotifyApi spotify,
    bool skipMetadataEnrichment,
  ) async {
    // Validate all in parallel (Spotify has no rate limit for search)
    return Future.wait(
      recommendations.map((rec) => _validateSingleRecommendationSpotifyOnly(spotify, rec, skipMetadataEnrichment)),
    );
  }
  
  /// Fast Spotify-only validation (no MusicBrainz check)
  static Future<MusicRecommendation?> _validateSingleRecommendationSpotifyOnly(
    SpotifyApi spotify,
    MusicRecommendation recommendation,
    bool skipMetadataEnrichment,
  ) async {
    try {
      // Only check Spotify (much faster, no rate limits)
      final trackQuery = 'track:"${recommendation.song}" artist:"${recommendation.artist.split(',').first.trim()}"';
      final trackSearchResults = await spotify.search
          .get(trackQuery, types: [SearchType.track])
          .first(1);

      for (final page in trackSearchResults) {
        if (page.items != null) {
          for (final item in page.items!) {
            if (item is Track) {
              // Found on Spotify!
              if (skipMetadataEnrichment) {
                // Just return the original (validated existence)
                return recommendation;
              }
              
              // Extract metadata
              final artistName = item.artists?.isNotEmpty == true
                  ? item.artists!.map((a) => a.name).join(', ')
                  : recommendation.artist;
              
              final albumName = item.album?.name ?? recommendation.album;
              
              final imageUrl = item.album?.images?.isNotEmpty == true
                  ? (item.album!.images!.first.url ?? recommendation.imageUrl)
                  : recommendation.imageUrl;

              return MusicRecommendation(
                song: item.name ?? recommendation.song,
                artist: artistName,
                album: albumName,
                imageUrl: imageUrl,
                genres: recommendation.genres,
              );
            }
          }
        }
      }
      
      // Not found on Spotify - reject (might be hallucination)
      print('⚠️  Track not found on Spotify: "${recommendation.song}" by "${recommendation.artist}"');
      return null;
    } catch (e) {
      print('Error validating with Spotify: $e');
      return null;
    }
  }
  
  /// Maintains validation cache size
  static void _updateValidationCacheSize() {
    if (_validationCache.length > _maxValidationCacheSize) {
      // Remove oldest entries (simple FIFO - remove first 20%)
      final keysToRemove = _validationCache.keys.take(_maxValidationCacheSize ~/ 5).toList();
      for (final key in keysToRemove) {
        _validationCache.remove(key);
      }
    }
  }

  /// Validates AI recommendations using a hybrid approach:
  /// 1. First checks MusicBrainz (broader coverage, free, no rate limits)
  /// 2. Then checks Spotify (to get metadata like images, ensures track is playable)
  /// Returns only recommendations that exist in MusicBrainz (Spotify is optional for metadata)
  static Future<List<MusicRecommendation>> _validateRecommendationsAgainstSpotify(
    List<MusicRecommendation> recommendations,
  ) async {
    // Use optimized version
    return _validateRecommendationsOptimized(recommendations);
  }

  /// Validates a single recommendation against MusicBrainz first, then Spotify
  /// Returns the validated recommendation with corrected data if found, null if not found
  static Future<MusicRecommendation?> _validateSingleRecommendation(
    SpotifyApi spotify,
    MusicRecommendation recommendation, {
    bool skipMetadataEnrichment = false,
  }) async {
    try {
      // Step 1: Check MusicBrainz first (broader coverage, free, no rate limits)
      print('Checking MusicBrainz for "${recommendation.song}" by "${recommendation.artist}"...');
      final existsInMusicBrainz = await MusicBrainzService.validateTrackExists(
        recommendation.song,
        recommendation.artist,
      );
      
      if (!existsInMusicBrainz) {
        // Track doesn't exist in MusicBrainz - likely a hallucination
        print('⚠️  AI hallucination detected: "${recommendation.song}" by "${recommendation.artist}" not found in MusicBrainz');
        return null;
      }
      
      // Step 2: Track exists in MusicBrainz, now try Spotify to get metadata (images, etc.)
      print('Track found in MusicBrainz, checking Spotify for metadata...');
      try {
        // Try searching for the track on Spotify (most accurate)
        final trackQuery = 'track:"${recommendation.song}" artist:"${recommendation.artist.split(',').first.trim()}"';
        final trackSearchResults = await spotify.search
            .get(trackQuery, types: [SearchType.track])
            .first(1);

        for (final page in trackSearchResults) {
          if (page.items != null) {
            for (final item in page.items!) {
              if (item is Track) {
                // Found on Spotify! Return with full metadata
                final artistName = item.artists?.isNotEmpty == true
                    ? item.artists!.map((a) => a.name).join(', ')
                    : recommendation.artist;
                
                final albumName = item.album?.name ?? recommendation.album;
                
                final imageUrl = item.album?.images?.isNotEmpty == true
                    ? (item.album!.images!.first.url ?? recommendation.imageUrl)
                    : recommendation.imageUrl;

                print('✓ Track found on Spotify with metadata: "${recommendation.song}" by "${recommendation.artist}"');
                
                if (skipMetadataEnrichment) {
                  // Just return original (validated existence, skip metadata)
                  return recommendation;
                }
                
                return MusicRecommendation(
                  song: item.name ?? recommendation.song,
                  artist: artistName,
                  album: albumName,
                  imageUrl: imageUrl,
                  genres: recommendation.genres, // Keep existing genres, will be enriched later
                );
              }
            }
          }
        }

        // If exact search didn't find it, try a more lenient search (without quotes for fuzzy matching)
        final lenientQuery = '${recommendation.song} ${recommendation.artist.split(',').first.trim()}';
        final lenientSearchResults = await spotify.search
            .get(lenientQuery, types: [SearchType.track])
            .first(1);

        for (final page in lenientSearchResults) {
          if (page.items != null) {
            for (final item in page.items!) {
              if (item is Track) {
                // Fuzzy match: check if track name and artist are similar
                final trackNameLower = (item.name ?? '').toLowerCase();
                final recNameLower = recommendation.song.toLowerCase();
                final trackArtistLower = item.artists?.isNotEmpty == true
                    ? (item.artists!.first.name?.toLowerCase() ?? '')
                    : '';
                final recArtistLower = recommendation.artist.split(',').first.trim().toLowerCase();
                
                // Check if names are similar (contains or is contained)
                final nameMatch = trackNameLower.contains(recNameLower) || 
                                 recNameLower.contains(trackNameLower) ||
                                 trackNameLower == recNameLower;
                final artistMatch = trackArtistLower.contains(recArtistLower) ||
                                   recArtistLower.contains(trackArtistLower) ||
                                   trackArtistLower == recArtistLower;
                
                if (nameMatch && artistMatch) {
                  // Found a matching track on Spotify with fuzzy matching
                  final artistName = item.artists?.isNotEmpty == true
                      ? item.artists!.map((a) => a.name).join(', ')
                      : recommendation.artist;
                  
                  final albumName = item.album?.name ?? recommendation.album;
                  
                  final imageUrl = item.album?.images?.isNotEmpty == true
                      ? (item.album!.images!.first.url ?? recommendation.imageUrl)
                      : recommendation.imageUrl;

                  print('✓ Track found on Spotify (fuzzy match) with metadata: "${recommendation.song}" by "${recommendation.artist}"');
                  
                  if (skipMetadataEnrichment) {
                    // Just return original (validated existence, skip metadata)
                    return recommendation;
                  }
                  
                  return MusicRecommendation(
                    song: item.name ?? recommendation.song,
                    artist: artistName,
                    album: albumName,
                    imageUrl: imageUrl,
                    genres: recommendation.genres,
                  );
                }
              }
            }
          }
        }
        
        // Track exists in MusicBrainz but not on Spotify - still valid, return as-is
        print('✓ Track exists in MusicBrainz but not on Spotify (may not be playable): "${recommendation.song}" by "${recommendation.artist}"');
        return recommendation; // Return as-is since we can't get Spotify metadata
      } catch (e) {
        print('Error checking Spotify (but track exists in MusicBrainz): $e');
        // Track exists in MusicBrainz, so it's valid even if Spotify check fails
        print('✓ Track validated in MusicBrainz (Spotify check failed): "${recommendation.song}" by "${recommendation.artist}"');
        return recommendation;
      }
    } catch (e) {
      print('Error validating "${recommendation.song}" by "${recommendation.artist}": $e');
      // If validation fails for this specific track, exclude it to be safe
      return null;
    }
  }

  /// Enrich recommendations with MusicBrainz genres (hybrid Spotify + MusicBrainz approach)
  static Future<List<MusicRecommendation>> _enrichRecommendationsWithGenres(
    List<MusicRecommendation> recommendations,
  ) async {
    final enrichedRecs = <MusicRecommendation>[];
    
    for (final rec in recommendations) {
      // If already has genres, keep them but try to enrich
      List<String> genres = List.from(rec.genres);
      
      // Only fetch from cache/API if we don't have genres or have very few
      if (genres.isEmpty || genres.length < 2) {
        try {
          // Use cache service: checks Firestore cache first, then MusicBrainz API
          final cachedGenres = await GenreCacheService.getGenresWithCache(
            rec.song,
            rec.artist.split(',').first.trim(), // Use first artist if multiple
          );
          
          if (cachedGenres.isNotEmpty) {
            // Combine existing genres with cached genres (avoid duplicates)
            final cachedGenresSet = cachedGenres.map((g) => g.toLowerCase().trim()).toSet();
            final existingGenresSet = genres.map((g) => g.toLowerCase().trim()).toSet();
            
            // Merge genres
            genres = cachedGenres.toList();
            // Add any existing genres that weren't in cached genres
            for (final existing in rec.genres) {
              if (!cachedGenresSet.contains(existing.toLowerCase().trim())) {
                genres.add(existing);
              }
            }
            
            print('Enriched ${rec.song} with ${genres.length} genres (from cache/API)');
          }
        } catch (e) {
          print('Error enriching ${rec.song} with genres: $e');
          // Continue with existing genres if enrichment fails
        }
      }
      
      // If still no genres, try to get from Spotify artist
      if (genres.isEmpty) {
        try {
          final credentials = SpotifyApiCredentials(clientId, clientSecret);
          final spotify = SpotifyApi(credentials);
          
          // Search for artist to get artist-level genres
          final artistName = rec.artist.split(',').first.trim();
          final searchResults = await spotify.search
              .get(artistName, types: [SearchType.artist])
              .first(1);
          
          for (final page in searchResults) {
            if (page.items != null) {
              for (final item in page.items!) {
                if (item is Artist && item.genres != null && item.genres!.isNotEmpty) {
                  genres = item.genres!.toList();
                  print('Got ${genres.length} artist genres from Spotify for ${rec.song}');
                  break;
                }
              }
            }
            if (genres.isNotEmpty) break;
          }
        } catch (e) {
          print('Error getting Spotify artist genres for ${rec.song}: $e');
        }
      }
      
      // Create enriched recommendation
      enrichedRecs.add(MusicRecommendation(
        song: rec.song,
        artist: rec.artist,
        album: rec.album,
        imageUrl: rec.imageUrl,
        genres: genres,
      ));
    }
    
    return enrichedRecs;
  }

  /// Fetches album images from Spotify in parallel (non-blocking background task)
  static void _fetchAlbumImagesInBackground(
      List<MusicRecommendation> recommendations) {
    // Run in background without blocking
    Future(() async {
      try {
        final credentials = SpotifyApiCredentials(clientId, clientSecret);
        final spotify = SpotifyApi(credentials);

        // Fetch all images in parallel
        final futures = recommendations.map((rec) async {
          // Skip if imageUrl is already populated
          if (rec.imageUrl.isNotEmpty) {
            return rec;
          }

          try {
            String? imageUrl;

            // Search for the track on Spotify
            final query = 'track:"${rec.song}" artist:"${rec.artist}"';
            final searchResults = await spotify.search
                .get(query, types: [SearchType.track])
                .first(1);

            // Extract album image from search results
            for (final page in searchResults) {
              if (page.items != null) {
                for (final item in page.items!) {
                  if (item is Track && item.album != null) {
                    final images = item.album!.images;
                    if (images != null && images.isNotEmpty) {
                      // Use the first (largest) image
                      imageUrl = images.first.url;
                      break;
                    }
                  }
                }
              }
              if (imageUrl != null) break;
            }

            // If no image found, try searching by album name
            if (imageUrl == null && rec.album.isNotEmpty) {
              final albumQuery = 'album:"${rec.album}" artist:"${rec.artist}"';
              final albumSearchResults = await spotify.search
                  .get(albumQuery, types: [SearchType.album])
                  .first(1);

              for (final page in albumSearchResults) {
                if (page.items != null) {
                  for (final item in page.items!) {
                    if (item is AlbumSimple &&
                        item.images != null &&
                        item.images!.isNotEmpty) {
                      imageUrl = item.images!.first.url;
                      break;
                    }
                  }
                }
                if (imageUrl != null) break;
              }
            }

            // Return updated recommendation with image URL
            return MusicRecommendation(
              song: rec.song,
              artist: rec.artist,
              album: rec.album,
              imageUrl: imageUrl ?? '',
              genres: rec.genres,
            );
          } catch (e) {
            print('Error fetching image for ${rec.song} by ${rec.artist}: $e');
            // Return original recommendation if fetch fails
            return rec;
          }
        });

        // Wait for all images to be fetched in parallel
        final updatedRecommendations = await Future.wait(futures);

        // Update cache with images (this would require modifying the cache structure)
        // For now, images will be fetched on next load or we could emit an event
        print('Fetched ${updatedRecommendations.length} album images');
      } catch (e) {
        print('Error in _fetchAlbumImagesInBackground: $e');
      }
    });
  }

  /// Fetches album image for a single recommendation (used for on-demand loading)
  static Future<String> fetchAlbumImageForRecommendation(
      MusicRecommendation recommendation) async {
    if (recommendation.imageUrl.isNotEmpty) {
      return recommendation.imageUrl;
    }

    try {
      final credentials = SpotifyApiCredentials(clientId, clientSecret);
      final spotify = SpotifyApi(credentials);

      String? imageUrl;

      // Search for the track on Spotify
      final query = 'track:"${recommendation.song}" artist:"${recommendation.artist}"';
      final searchResults = await spotify.search
          .get(query, types: [SearchType.track])
          .first(1);

      // Extract album image from search results
      for (final page in searchResults) {
        if (page.items != null) {
          for (final item in page.items!) {
            if (item is Track && item.album != null) {
              final images = item.album!.images;
              if (images != null && images.isNotEmpty) {
                imageUrl = images.first.url;
                break;
              }
            }
          }
        }
        if (imageUrl != null) break;
      }

      // If no image found, try searching by album name
      if (imageUrl == null && recommendation.album.isNotEmpty) {
        final albumQuery =
            'album:"${recommendation.album}" artist:"${recommendation.artist}"';
        final albumSearchResults = await spotify.search
            .get(albumQuery, types: [SearchType.album])
            .first(1);

        for (final page in albumSearchResults) {
          if (page.items != null) {
            for (final item in page.items!) {
              if (item is AlbumSimple &&
                  item.images != null &&
                  item.images!.isNotEmpty) {
                imageUrl = item.images!.first.url;
                break;
              }
            }
          }
          if (imageUrl != null) break;
        }
      }

      return imageUrl ?? '';
    } catch (e) {
      print('Error fetching image for ${recommendation.song}: $e');
      return '';
    }
  }
}

class MusicRecommendationException implements Exception {
  final String message;
  const MusicRecommendationException(this.message);

  @override
  String toString() => 'MusicRecommendationException: $message';
}

class HttpException implements Exception {
  final String message;
  const HttpException(this.message);

  @override
  String toString() => 'HttpException: $message';
}

class ParseException implements Exception {
  final String message;
  const ParseException(this.message);

  @override
  String toString() => 'ParseException: $message';
}
