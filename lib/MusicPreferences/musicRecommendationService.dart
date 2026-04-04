import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test_project/Api/api_key.dart';
import 'package:flutter_test_project/models/enhanced_user_preferences.dart';
import 'package:flutter_test_project/models/music_recommendation.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/utils/reviews/review_helpers.dart';
import 'package:flutter_test_project/utils/scoring_utils.dart';
import 'package:flutter_test_project/MusicPreferences/recommendation_enhancements.dart';
import 'package:flutter_test_project/services/get_album_service.dart';
import 'package:flutter_test_project/services/genre_cache_service.dart';
import 'package:flutter_test_project/services/review_analysis_service.dart';
import 'package:flutter_test_project/services/signal_collection_service.dart';
import 'package:flutter_test_project/services/embedding_service.dart';
import 'package:flutter_test_project/services/recommendation_outcome_service.dart';
import 'package:flutter_test_project/services/discogs_service.dart';
import 'package:http/http.dart' as http;
import 'package:spotify/spotify.dart';

class MusicRecommendationService {
  static const _openAiEndpoint = 'https://api.openai.com/v1/chat/completions';
  static const _model = 'gpt-4o-mini';
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
    bool skipValidation =
        false, // OPTIMIZATION: Skip validation for faster results (use with caution)
    String validationMode =
        'spotify-only', // 'spotify-only' (fast, no MusicBrainz), 'hybrid' (MusicBrainz+Spotify), 'none' (skip)
    int validateTopN =
        0, // OPTIMIZATION: Only validate top N (0 = validate all)
    bool skipMetadataEnrichment =
        false, // OPTIMIZATION: Skip Spotify metadata (images, etc.) for speed
  }) async {
    try {
      final userId = FirebaseAuth.instance.currentUser != null
          ? FirebaseAuth.instance.currentUser!.uid
          : '';

      if (userId.isEmpty) {
        throw const MusicRecommendationException('User not logged in');
      }

      final preferences = preferencesJson;

      // Run independent read-heavy tasks in parallel.
      final reviewProfileFuture = () async {
        try {
          debugPrint(
              'Analyzing user reviews for personalized recommendations...');
          final profile = await ReviewAnalysisService.analyzeUserReviews(
            userId,
            forceRefresh: false,
          );
          debugPrint(
              'Review analysis complete: ${profile.ratingPattern.averageRating.toStringAsFixed(1)} avg rating');
          return profile;
        } catch (e) {
          debugPrint('Error analyzing reviews (will use basic method): $e');
          return null;
        }
      }();

      final reviewsFuture = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reviews')
          .orderBy('date', descending: true)
          .limit(60)
          .get()
          .then((snapshot) => snapshot.docs
              .map((doc) => Review.fromFirestore(doc.data()))
              .toList());

      final collaborativeFuture = useEnhancedAlgorithm
          ? () async {
              try {
                debugPrint('Finding similar users...');
                final similarUsers =
                    await RecommendationEnhancements.findSimilarUsers(userId);
                if (similarUsers.isEmpty) return <MusicRecommendation>[];
                debugPrint('Found ${similarUsers.length} similar users');
                final collaborativeRecs = await RecommendationEnhancements
                    .getCollaborativeRecommendations(userId, similarUsers);
                debugPrint(
                    'Got ${collaborativeRecs.length} collaborative recommendations');
                return collaborativeRecs;
              } catch (e) {
                debugPrint('Error getting collaborative recommendations: $e');
                return <MusicRecommendation>[];
              }
            }()
          : Future.value(<MusicRecommendation>[]);

      final spotifyFuture = useEnhancedAlgorithm &&
              (preferences.savedTracks.isNotEmpty ||
                  preferences.favoriteArtists.isNotEmpty)
          ? () async {
              try {
                debugPrint('Fetching Spotify recommendations...');
                final spotifyRecs =
                    await RecommendationEnhancements.getSpotifyRecommendations(
                  preferences,
                  count ~/ 2,
                );
                debugPrint('Got ${spotifyRecs.length} Spotify recommendations');
                return spotifyRecs;
              } catch (e) {
                debugPrint('Error getting Spotify recommendations: $e');
                return <MusicRecommendation>[];
              }
            }()
          : Future.value(<MusicRecommendation>[]);

      final embeddingMetadataFuture =
          _buildTasteEmbeddingMetadata(userId, preferences);

      final reviews = await reviewsFuture;
      final reviewProfile = await reviewProfileFuture;

      final List<dynamic> reviewList = [];
      for (final review in reviews.take(5)) {
        reviewList.add({
          'song': review.title,
          'artist': review.artist,
          'rating': review.score,
          'review': review.review,
          if (review.genres != null && review.genres!.isNotEmpty)
            'genres': review.genres,
        });
      }

      // Collect styles/genres from positively-rated recent reviews for Discogs lookup.
      // Use up to 15 reviews (was 5) to get a richer style signal, and always
      // include favorite genres as a safety net so Discogs never gets empty input.
      final positiveStyles = <String>{};
      final positiveGenres = <String>{};
      for (final review in reviews.take(15)) {
        if (review.score >= 3.5 && review.genres != null) {
          positiveStyles.addAll(review.genres!);
        }
      }
      // Always add favorite genres — they're the highest-confidence signal.
      positiveGenres.addAll(preferences.favoriteGenres.take(3));

      final discogsCandidatesFuture = DiscogsService.searchByStyles(
        styles: positiveStyles.toList(),
        genres: positiveGenres.toList(),
      );

      final List<MusicRecommendation> allRecommendations = [];
      final Map<String, Set<String>> recommendationSources =
          <String, Set<String>>{};

      void addRecommendationsWithSource(
        Iterable<MusicRecommendation> recommendations,
        String source,
      ) {
        for (final recommendation in recommendations) {
          allRecommendations.add(recommendation);
          final key = _recommendationKey(recommendation);
          recommendationSources.putIfAbsent(key, () => <String>{}).add(source);
        }
      }

      Future<List<UserSignal>> userSignalsFuture = Future.value(<UserSignal>[]);
      Future<Map<String, double>?> componentWeightsFuture = Future.value(null);
      if (reviewProfile != null) {
        userSignalsFuture = () async {
          try {
            final signals =
                await SignalCollectionService.getRecentSignals(limit: 200);
            debugPrint('Fetched ${signals.length} user signals for scoring');
            return signals;
          } catch (e) {
            debugPrint(
                'Error fetching signals (will use review-only scoring): $e');
            return <UserSignal>[];
          }
        }();

        componentWeightsFuture = () async {
          try {
            return await RecommendationOutcomeService.getAdjustedWeights();
          } catch (e) {
            debugPrint('Error fetching adjusted weights: $e');
            return null;
          }
        }();
      }

      // 1. Get AI-based recommendations (improved prompt with review analysis)
      try {
        final discogsCandidates = await discogsCandidatesFuture;
        debugPrint('[Discogs] ${discogsCandidates.length} candidates fetched');

        final prompt = _buildEnhancedPrompt(
          preferences,
          count,
          excludeSongs,
          reviewList,
          reviewProfile,
          discogsCandidates,
        );
        debugPrint('Fetching AI recommendations with review analysis...');
        final response = await _makeApiRequest(prompt);
        debugPrint('[AI raw response] $response');
        final rawRecommendations = _parseRecommendations(response);
        debugPrint('[Parsed reasons] ${rawRecommendations.map((r) => '"${r.song}": "${r.reason}"').join(', ')}');

        // Enrich each recommendation with Discogs styles by matching on artist name
        final discogsStyleMap = <String, List<String>>{};
        for (final d in discogsCandidates) {
          final key = d.artist.toLowerCase();
          if (d.styles.isNotEmpty) discogsStyleMap[key] = d.styles;
        }
        final aiRecommendations = rawRecommendations.map((rec) {
          final styles = discogsStyleMap[rec.artist.toLowerCase()] ?? [];
          if (styles.isEmpty) return rec;
          return MusicRecommendation(
            song: rec.song,
            artist: rec.artist,
            album: rec.album,
            imageUrl: rec.imageUrl,
            genres: rec.genres,
            styles: styles,
            reason: rec.reason,
          );
        }).toList();

        // OPTIMIZATION: Only validate AI recommendations (Spotify recs are already validated)
        if (skipValidation || validationMode == 'none') {
          // Skip validation for faster results
          debugPrint(
              'Skipping validation for faster results (${aiRecommendations.length} AI recommendations)');
          addRecommendationsWithSource(aiRecommendations, 'ai');
        } else {
          // Determine which recommendations to validate
          final recsToValidate =
              validateTopN > 0 && validateTopN < aiRecommendations.length
                  ? aiRecommendations.take(validateTopN).toList()
                  : aiRecommendations;

          final recsToSkip =
              validateTopN > 0 && validateTopN < aiRecommendations.length
                  ? aiRecommendations.skip(validateTopN).toList()
                  : <MusicRecommendation>[];

          if (recsToValidate.isNotEmpty) {
            debugPrint(
                'Validating ${recsToValidate.length} AI recommendations (mode: $validationMode)...');
            final validatedRecommendations =
                await _validateRecommendationsOptimized(
              recsToValidate,
              validationMode: validationMode,
              skipMetadataEnrichment: skipMetadataEnrichment,
            );
            addRecommendationsWithSource(validatedRecommendations, 'ai');
            debugPrint(
                'Got ${validatedRecommendations.length} validated AI recommendations (${recsToValidate.length - validatedRecommendations.length} filtered out)');
          }

          // Add unvalidated recommendations if validating only top N
          if (recsToSkip.isNotEmpty) {
            debugPrint(
                'Skipping validation for ${recsToSkip.length} lower-priority recommendations');
            addRecommendationsWithSource(recsToSkip, 'ai');
          }
        }
      } catch (e) {
        debugPrint('Error getting AI recommendations: $e');
      }

      // 2/3. Consume source futures that ran in parallel with AI generation.
      final sourceResults = await Future.wait<List<MusicRecommendation>>([
        collaborativeFuture,
        spotifyFuture,
      ]);
      final collaborativeRecs = sourceResults[0];
      final spotifyRecs = sourceResults[1];
      if (collaborativeRecs.isNotEmpty) {
        addRecommendationsWithSource(collaborativeRecs, 'collaborative');
      }
      if (spotifyRecs.isNotEmpty) {
        addRecommendationsWithSource(spotifyRecs, 'spotify');
      }

      // Remove duplicates and saved tracks
      var filteredRecs = removeDuplication(allRecommendations, preferences);

      // Remove excluded songs
      if (excludeSongs != null && excludeSongs.isNotEmpty) {
        final excludeSet =
            excludeSongs.map((s) => s.toLowerCase().trim()).toSet();
        filteredRecs = filteredRecs.where((rec) {
          final key = '${rec.artist}|${rec.song}'.toLowerCase();
          return !excludeSet.contains(key);
        }).toList();
      }

      // 4. Score recommendations based on review analysis + signals + feedback weights
      if (reviewProfile != null && filteredRecs.isNotEmpty) {
        final userSignals = await userSignalsFuture;
        final componentWeights = await componentWeightsFuture;

        Map<String, double>? adjustedSignalWeights;
        if (componentWeights != null &&
            componentWeights !=
                RecommendationOutcomeService.defaultComponentWeights) {
          adjustedSignalWeights = null; // signal weights remain default for now
          debugPrint(
              'Using feedback-calibrated component weights: $componentWeights');
        }

        final scoredRecs = filteredRecs.map((rec) {
          final sourceHints =
              recommendationSources[_recommendationKey(rec)] ?? <String>{};
          final score = _scoreRecommendationFromReviews(
            rec,
            reviewProfile,
            signals: userSignals,
            adjustedWeights: adjustedSignalWeights,
            sourceHints: sourceHints,
          );
          return {'rec': rec, 'score': score, 'sources': sourceHints};
        }).toList();

        // Sort by combined score
        scoredRecs.sort(
            (a, b) => (b['score'] as double).compareTo(a['score'] as double));
        final strictMatchThreshold = 0.58;
        final strongMatches = scoredRecs
            .where(
                (entry) => (entry['score'] as double) >= strictMatchThreshold)
            .toList();

        // Prefer strongly profile-aligned songs first, then backfill if needed.
        final sortedForSelection =
            strongMatches.length >= count ? strongMatches : scoredRecs;
        filteredRecs = sortedForSelection
            .take((count * 1.5)
                .round()) // Keep headroom for later diversity filters
            .map((e) => e['rec'] as MusicRecommendation)
            .toList();
      }

      // 4b. Semantic scoring via taste vector embeddings (Phase 3)
      if (filteredRecs.isNotEmpty) {
        try {
          final embeddingMetadata = await embeddingMetadataFuture;
          final candidates = filteredRecs
              .map((r) => CandidateInfo(
                    artist: r.artist,
                    track: r.song,
                    album: r.album,
                    genres: r.genres,
                  ))
              .toList();
          final semanticScores =
              await EmbeddingService.scoreCandidatesWithUserTaste(
            userId: userId,
            reviews: reviews,
            candidates: candidates,
            metadata: embeddingMetadata,
          );

          if (semanticScores.isNotEmpty) {
            debugPrint(
                '[SEMANTIC] Scored ${filteredRecs.length} candidates with taste embeddings');
            final reRanked = <Map<String, dynamic>>[];
            for (int i = 0; i < filteredRecs.length; i++) {
              final score = i < semanticScores.length ? semanticScores[i] : 0.5;
              reRanked.add({'rec': filteredRecs[i], 'semanticScore': score});
            }
            reRanked.sort((a, b) => (b['semanticScore'] as double)
                .compareTo(a['semanticScore'] as double));

            final semanticOrder =
                reRanked.map((e) => e['rec'] as MusicRecommendation).toList();
            final blended = <MusicRecommendation>[];
            final seen = <String>{};
            int sIdx = 0, oIdx = 0;
            while (blended.length < filteredRecs.length) {
              MusicRecommendation? next;
              if (blended.length % 2 == 0 && sIdx < semanticOrder.length) {
                next = semanticOrder[sIdx++];
              } else if (oIdx < filteredRecs.length) {
                next = filteredRecs[oIdx++];
              } else if (sIdx < semanticOrder.length) {
                next = semanticOrder[sIdx++];
              } else {
                break;
              }
              final key = '${next.artist}|${next.song}'.toLowerCase();
              if (seen.add(key)) {
                blended.add(next);
              }
            }
            filteredRecs = blended;
            debugPrint('[SEMANTIC] Re-ranked with semantic scoring');
          }

          filteredRecs = await _rerankWithTasteProfileLlm(
            recommendations: filteredRecs,
            preferences: preferences,
            reviews: reviews,
            reviewProfile: reviewProfile,
            targetCount: count,
          );
        } catch (e) {
          debugPrint(
              '[SEMANTIC] Error in semantic scoring (continuing without): $e');
        }
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

      // 6. Keep critical path fast: use cache-only enrichment now and warm the
      // rate-limited MusicBrainz cache in the background.
      filteredRecs = await _enrichRecommendationsWithGenres(
        filteredRecs,
        allowMusicBrainzNetwork: false,
        allowSpotifyFallback: false,
      );
      _warmGenreCacheInBackground(filteredRecs);

      // Start fetching album images in the background (non-blocking)
      _fetchAlbumImagesInBackground(filteredRecs);

      // 7. Log shown recommendations for outcome tracking (Phase 4)
      _logShownRecommendationsInBackground(filteredRecs);

      // 8. Resolve stale outcomes in background (Phase 4)
      unawaited(RecommendationOutcomeService.resolveStaleOutcomes());

      debugPrint(
          'Returning ${filteredRecs.length} final recommendations with genres');
      return filteredRecs;
    } catch (e) {
      throw MusicRecommendationException('Failed to get recommendations: $e');
    }
  }

  /// Build prompt using recent reviews as primary signal and Discogs
  /// community-rated candidates as a curated pool for discovery.
  static String _buildEnhancedPrompt(
    EnhancedUserPreferences preferences,
    int count,
    List<String>? excludeSongs,
    List<dynamic> reviews,
    UserReviewProfile? reviewProfile, [
    List<DiscogsRelease> discogsCandidates = const [],
  ]) {
    final excludeList = [
      ..._recentRecommendations,
      ...excludeSongs ?? [],
    ];

    // Format recent reviews as readable bullets
    final reviewBlock = reviews.map((r) {
      final rating = (r['rating'] as num?)?.toDouble() ?? 0;
      final sentiment = rating >= 4.0
          ? 'loved'
          : rating <= 2.0
              ? 'disliked'
              : 'felt neutral about';
      final genreStr = (r['genres'] is List && (r['genres'] as List).isNotEmpty)
          ? ' [${(r['genres'] as List).join(', ')}]'
          : '';
      return '• "${r['song']}" by ${r['artist']}$genreStr — $sentiment (${rating.toStringAsFixed(1)}/5): "${r['review']}"';
    }).join('\n');

    // Scored artist sentiment from reviews
    final recentArtistScores = <String, double>{};
    final recentGenres = <String>{};
    for (final r in reviews) {
      final artist = r['artist']?.toString() ?? '';
      final rating = (r['rating'] as num?)?.toDouble() ?? 3.0;
      final sentiment = (rating - 3.0) / 2.0;
      if (artist.isNotEmpty) recentArtistScores[artist] = sentiment;
      if (r['genres'] is List) {
        for (final g in r['genres'] as List) {
          if (g != null && g.toString().isNotEmpty)
            recentGenres.add(g.toString());
        }
      }
    }

    final positiveArtists = recentArtistScores.entries
        .where((e) => e.value > 0)
        .map((e) => '${e.key} (+${e.value.toStringAsFixed(1)})')
        .join(', ');
    final negativeArtists = recentArtistScores.entries
        .where((e) => e.value <= 0)
        .map((e) => '${e.key} (${e.value.toStringAsFixed(1)})')
        .join(', ');

    // Discogs candidate block — community-vetted releases matching user's genres
    final discogsCandidateBlock = discogsCandidates.isNotEmpty
        ? '''

DISCOGS COMMUNITY PICKS (prioritise songs from these artists/albums — they match the user's genres and are highly rated or underrated by the community):
${DiscogsService.formatCandidatesForPrompt(discogsCandidates)}

Prefer recommending specific tracks from the artists and albums listed above. These have been filtered to match the user's taste profile and have strong community ratings on Discogs. Songs marked [cult/underrated] are hidden gems — prioritise these for discovery.'''
        : '';

    return '''
You are a music discovery engine. Recommend songs based primarily on the user's recent reviews. Use the Discogs community picks as your main candidate pool for discovery.

USER PREFERENCES:
- Saved Tracks (DO NOT recommend these), but recommend tracks similar to them: ${jsonEncode(preferences.savedTracks)}
- Disliked Tracks (AVOID similar): ${jsonEncode(preferences.dislikedTracks)}
- Favorite Genres: ${jsonEncode(preferences.favoriteGenres)}
- Genre Weights (preference strength): ${jsonEncode(preferences.genreWeights)}
- Favorite Artists: ${jsonEncode(preferences.favoriteArtists)}
- Mood Preferences: ${jsonEncode(preferences.moodPreferences)}
- Tempo Preferences: ${jsonEncode(preferences.tempoPreferences)}
- Saved Tracks (DO NOT recommend these): ${jsonEncode(preferences.savedTracks)}

RECENT USER REVIEWS (to understand taste):
read ${jsonEncode(reviews)} to get a sense of the user's taste, what they like/dislike, and their rating patterns. Use this to inform your recommendations.
use the genre/tags in the most recent reviews to identify their preferences.
base recommendations on insights from these reviews, such as preferred genres, artists, and any recent shifts in taste.
suggest songs that align with the positive reviews and avoid songs similar to negative reviews.

DISCOVERY REQUIREMENTS:
1. PRIORITIZE DISCOVERY: Recommend songs the user likely hasn't heard before, even if they're in genres they like. Use review analysis to identify underexplored genres/artists.
   - Include artists NOT in their favorite artists list
   - Prioritize songs in genres similar to those theyve recently reviewed positively
   - Recommend songs that are popular in the genres they like but not from artists they've already saved
   - Recommend new releases in genres they like, even if they haven't listened to that artist before
   
2. ENSURE DIVERSITY:
   - Don't recommend multiple songs from the same artist
   - Mix different eras (some new, some classic)
   - Balance familiar sounds with surprising discoveries

3. MAINTAIN RELEVANCE:
   - Songs should align with artists and genres theyve recently reviewed positively
   - avoid songs that they have recently reviewed negatively or are similar to those
   - Match mood and tempo preferences when possible
   - Consider patterns from their reviews (what they liked/disliked)

4. AVOID:
   - Songs in savedTracks list
   - Songs in dislikedTracks list
   - Recently recommended songs: ${excludeList.take(10).join(", ")}
   - Songs from artists they've already saved (unless it's a new release)
   - Generic chart/top-50 picks UNLESS they strongly match top review-derived genres/artists

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

RECENT REVIEWS (primary signal):
$reviewBlock

RECENT ARTIST SENTIMENT:
${positiveArtists.isNotEmpty ? '- Enjoyed: $positiveArtists' : ''}
${negativeArtists.isNotEmpty ? '- Did not enjoy: $negativeArtists' : ''}
${recentGenres.isNotEmpty ? '- Genres from recent reviews: ${recentGenres.join(', ')}' : ''}
$discogsCandidateBlock

SAVED PREFERENCES (supplementary only):
- Genres: ${preferences.favoriteGenres.take(5).join(', ')}
- Saved artists: ${preferences.favoriteArtists.take(5).join(', ')}
- Do not recommend: ${([
      ...preferences.savedTracks,
      ...excludeList.take(10).map((e) => e.toString())
    ]).take(15).join(', ')}
- Avoid similar to: ${preferences.dislikedTracks.take(5).join(', ')}

INSTRUCTIONS:
- Draw candidates primarily from the Discogs community picks above
- Use reviews to infer current mood and sound — match it
- Avoid artists the user recently disliked; lean into artists they loved
- No two songs from the same artist
- At least 3 different genres
- Prioritise [cult/underrated] picks for discovery
- Return EXACTLY $count recommendations
- ONLY recommend songs that exist on Spotify — do not invent titles, artists, or albums
- Every object MUST include a "reason" field — a single sentence explaining why this track matches the user's taste based on their reviews (e.g. "You loved Kendrick's jazz-influenced production on your last review — this has a similar feel")
- Return ONLY valid JSON, no markdown, no commentary

Format (every field required, including reason):
[{"song":"Title","artist":"Artist","album":"Album","imageUrl":"","genres":["Genre1","Genre2"],"reason":"Why this matches their taste based on their reviews."}]
''';
  }

  /// Legacy method for backward compatibility
  static String _buildPrompt(EnhancedUserPreferences preferences, int count,
      List<String>? excludeSongs, List<dynamic> reviews) {
    return _buildEnhancedPrompt(
        preferences, count, excludeSongs, reviews, null);
  }

  /// Score recommendation based on review analysis and user signals.
  ///
  /// Upgraded from pure hand-tuned weights to a hybrid approach:
  ///   1. Review-analysis score (genre/artist preference from reviews)
  ///   2. Signal-aggregated score (from actual user interactions)
  ///   3. Temporal decay on both (Grainger Ch. 5)
  static double _scoreRecommendationFromReviews(
    MusicRecommendation recommendation,
    UserReviewProfile reviewProfile, {
    List<UserSignal> signals = const [],
    Map<String, double>? adjustedWeights,
    Set<String> sourceHints = const <String>{},
  }) {
    final normalizedCandidateGenres = recommendation.genres
        .map((genre) => genre.toLowerCase().trim())
        .where((genre) => genre.isNotEmpty)
        .toSet();
    final normalizedGenrePreferences = <String, double>{};
    for (final entry in reviewProfile.genrePreferences.entries) {
      final normalizedGenre = entry.key.toLowerCase().trim();
      if (normalizedGenre.isEmpty) continue;
      final existing = normalizedGenrePreferences[normalizedGenre] ?? 0.0;
      final next = entry.value.preferenceStrength.clamp(0.0, 1.0);
      if (next > existing) {
        normalizedGenrePreferences[normalizedGenre] = next;
      }
    }

    final normalizedArtistPreferences = <String, double>{};
    for (final entry in reviewProfile.artistPreferences.entries) {
      final normalizedArtist = entry.key.toLowerCase().trim();
      if (normalizedArtist.isEmpty) continue;
      final existing = normalizedArtistPreferences[normalizedArtist] ?? 0.0;
      final next = entry.value.preferenceScore.clamp(0.0, 1.0);
      if (next > existing) {
        normalizedArtistPreferences[normalizedArtist] = next;
      }
    }

    final candidateArtist = recommendation.artist.toLowerCase().trim();
    double reviewScore = 0.12; // Low base to force explicit profile matching.

    // Genre relevance (primary signal)
    double genreScore = 0.0;
    if (normalizedCandidateGenres.isNotEmpty) {
      double aggregateGenreScore = 0.0;
      for (final genre in normalizedCandidateGenres) {
        aggregateGenreScore +=
            _bestGenrePreferenceScore(genre, normalizedGenrePreferences);
      }
      genreScore = (aggregateGenreScore / normalizedCandidateGenres.length)
          .clamp(0.0, 1.0);
      reviewScore += genreScore * 0.45;
    } else {
      // Missing genre metadata makes a recommendation less trustworthy.
      reviewScore -= 0.08;
    }

    // Artist relevance (primary signal)
    double artistScore = 0.0;
    for (final entry in normalizedArtistPreferences.entries) {
      if (_artistMatches(candidateArtist, entry.key)) {
        final directArtistScore = entry.value;
        if (directArtistScore > artistScore) {
          artistScore = directArtistScore;
        }
      }
    }
    for (final topArtist in reviewProfile.ratingPattern.highlyRatedArtists) {
      if (_artistMatches(candidateArtist, topArtist)) {
        if (artistScore < 0.75) {
          artistScore = 0.75;
        }
        break;
      }
    }
    reviewScore += artistScore * 0.42;

    // Recency trends
    if (reviewProfile.temporalPatterns.recentTrends.isNotEmpty &&
        normalizedCandidateGenres.isNotEmpty) {
      final trendGenres = reviewProfile.temporalPatterns.recentTrends
          .map((genre) => genre.toLowerCase().trim())
          .where((genre) => genre.isNotEmpty)
          .toSet();
      final hasTrendGenre =
          normalizedCandidateGenres.any((genre) => trendGenres.contains(genre));
      if (hasTrendGenre) {
        reviewScore += 0.08;
      }
    }

    // Soft sentiment/rating confidence bonus
    final averageRatingScore =
        (reviewProfile.ratingPattern.averageRating / 5.0).clamp(0.0, 1.0);
    final sentimentScore =
        reviewProfile.reviewSentiment.sentimentScore.clamp(0.0, 1.0);
    reviewScore += ((averageRatingScore * 0.6) + (sentimentScore * 0.4)) * 0.05;

    // Penalize historically disliked artists.
    for (final lowRatedArtist in reviewProfile.ratingPattern.lowRatedArtists) {
      if (_artistMatches(candidateArtist, lowRatedArtist)) {
        reviewScore -= 0.32;
        break;
      }
    }

    // Penalize recommendations that do not match key genre/artist signals.
    if (normalizedCandidateGenres.isNotEmpty) {
      final hasStrongGenreMatch = normalizedCandidateGenres.any(
        (genre) =>
            _bestGenrePreferenceScore(genre, normalizedGenrePreferences) >=
            0.55,
      );
      if (!hasStrongGenreMatch) {
        reviewScore -= 0.16;
      }
    }
    if (genreScore < 0.35 && artistScore < 0.35) {
      reviewScore -= 0.10;
    }

    // Source priors: reduce generic source bias and reward profile-conditioned picks.
    if (sourceHints.contains('spotify') && sourceHints.length == 1) {
      reviewScore -= 0.08;
      if (genreScore >= 0.7 || artistScore >= 0.7) {
        reviewScore += 0.04;
      }
    }
    if (sourceHints.contains('ai')) {
      reviewScore += 0.04;
    }
    if (sourceHints.contains('collaborative') && artistScore >= 0.5) {
      reviewScore += 0.03;
    }

    reviewScore = reviewScore.clamp(0.0, 1.0);

    // If we have signals, compute a signal-aggregated score and blend
    if (signals.isNotEmpty) {
      final signalScore = ScoringUtils.signalAggregatedScore(
        candidateArtist: recommendation.artist,
        candidateGenres: recommendation.genres,
        signals: signals,
        adjustedWeights: adjustedWeights,
      );

      // Blend: keep review-derived profile fit as the dominant signal.
      return (reviewScore * 0.75 + signalScore * 0.25).clamp(0.0, 1.0);
    }

    return reviewScore;
  }

  static String _recommendationKey(MusicRecommendation recommendation) {
    return '${recommendation.artist.toLowerCase().trim()}|${recommendation.song.toLowerCase().trim()}';
  }

  static bool _artistMatches(String candidateArtist, String knownArtist) {
    final candidate = candidateArtist.toLowerCase().trim();
    final known = knownArtist.toLowerCase().trim();
    if (candidate.isEmpty || known.isEmpty) return false;
    if (candidate == known) return true;
    if (candidate.contains(known) || known.contains(candidate)) return true;

    final candidatePrimary = candidate.split(',').first.trim();
    final knownPrimary = known.split(',').first.trim();
    if (candidatePrimary.isEmpty || knownPrimary.isEmpty) return false;
    if (candidatePrimary == knownPrimary) return true;
    return candidatePrimary.contains(knownPrimary) ||
        knownPrimary.contains(candidatePrimary);
  }

  static double _bestGenrePreferenceScore(
    String candidateGenre,
    Map<String, double> normalizedGenrePreferences,
  ) {
    final genre = candidateGenre.toLowerCase().trim();
    if (genre.isEmpty || normalizedGenrePreferences.isEmpty) return 0.0;

    double best = normalizedGenrePreferences[genre] ?? 0.0;
    for (final entry in normalizedGenrePreferences.entries) {
      final preferenceGenre = entry.key;
      if (preferenceGenre == genre) {
        if (entry.value > best) {
          best = entry.value;
        }
        continue;
      }

      if (preferenceGenre.contains(genre) || genre.contains(preferenceGenre)) {
        final partialScore = entry.value * 0.82;
        if (partialScore > best) {
          best = partialScore;
        }
      }
    }
    return best.clamp(0.0, 1.0);
  }

  static Future<TasteEmbeddingMetadata?> _buildTasteEmbeddingMetadata(
    String userId,
    EnhancedUserPreferences preferences,
  ) async {
    try {
      final topTracks = <String>[
        ...preferences.savedTracks.take(16),
      ];
      final savedArtists = <String>[
        ...preferences.favoriteArtists.take(16),
      ];
      final recentTrackContexts = <String>[];

      for (final history in preferences.recentlyPlayed.take(20)) {
        final trackLabel =
            '${history.trackName.trim()} - ${history.artistName.trim()}';
        if (history.trackName.trim().isNotEmpty &&
            history.artistName.trim().isNotEmpty) {
          topTracks.add(trackLabel);
          savedArtists.add(history.artistName.trim());
        }

        final context =
            history.context.trim().isEmpty ? 'unknown' : history.context.trim();
        final genres = history.genres.where((g) => g.trim().isNotEmpty).take(2);
        final genrePart = genres.isEmpty ? '' : ', genres: ${genres.join("/")}';
        recentTrackContexts.add('$trackLabel (context: $context$genrePart)');
      }

      final playlistNames = await _fetchUserPlaylistNames(userId);
      final metadata = TasteEmbeddingMetadata(
        topTracks: topTracks,
        savedArtists: savedArtists,
        playlistNames: playlistNames,
        recentTrackContexts: recentTrackContexts,
      );
      return metadata.isEmpty ? null : metadata;
    } catch (e) {
      debugPrint('[SEMANTIC] Error building embedding metadata: $e');
      return null;
    }
  }

  static Future<List<String>> _fetchUserPlaylistNames(
    String userId, {
    int limit = 12,
  }) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('playlists')
          .where('userId', isEqualTo: userId)
          .limit(limit)
          .get();
      return snapshot.docs
          .map((doc) => (doc.data()['name'] as String?)?.trim() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('[SEMANTIC] Error fetching playlist names: $e');
      return [];
    }
  }

  static Future<List<MusicRecommendation>> _rerankWithTasteProfileLlm({
    required List<MusicRecommendation> recommendations,
    required EnhancedUserPreferences preferences,
    required List<Review> reviews,
    required UserReviewProfile? reviewProfile,
    required int targetCount,
  }) async {
    if (openAIKey.isEmpty || recommendations.length < 4) {
      return recommendations;
    }

    int rerankWindow = targetCount * 4;
    if (rerankWindow < 12) rerankWindow = 12;
    if (rerankWindow > 40) rerankWindow = 40;
    if (rerankWindow > recommendations.length) {
      rerankWindow = recommendations.length;
    }

    final candidatePool = recommendations.take(rerankWindow).toList();
    final remaining = recommendations.skip(rerankWindow).toList();

    final topGenres = reviewProfile == null
        ? <String>[]
        : (reviewProfile.genrePreferences.entries.toList()
              ..sort((a, b) => b.value.preferenceStrength
                  .compareTo(a.value.preferenceStrength)))
            .take(6)
            .map((e) => e.key)
            .toList();

    final likedArtists = reviewProfile == null
        ? preferences.favoriteArtists.take(8).toList()
        : reviewProfile.ratingPattern.highlyRatedArtists.take(8).toList();
    final dislikedArtists =
        reviewProfile?.ratingPattern.lowRatedArtists.take(6).toList() ??
            <String>[];

    final reviewSnippets = reviews.take(8).map((r) {
      final reviewText = r.review.replaceAll('\n', ' ').trim();
      final clipped = reviewText.length > 140
          ? '${reviewText.substring(0, 140)}...'
          : reviewText;
      return '- ${r.title} by ${r.artist} | ${r.score}/5 | "$clipped"';
    }).join('\n');

    final candidates = candidatePool.asMap().entries.map((entry) {
      final rec = entry.value;
      final genres =
          rec.genres.isEmpty ? 'unknown' : rec.genres.take(4).join(', ');
      return '${entry.key}: ${rec.song} by ${rec.artist} | genres: $genres';
    }).join('\n');

    final prompt = '''
You are reranking candidate songs for a single user. Prioritize profile fit and review sentiment alignment over popularity.

User taste profile:
- Favorite genres: ${preferences.favoriteGenres.take(8).join(', ')}
- Top review-derived genres: ${topGenres.join(', ')}
- Liked artists: ${likedArtists.join(', ')}
- Disliked artists: ${dislikedArtists.join(', ')}
- Saved artists: ${preferences.favoriteArtists.take(8).join(', ')}

Recent reviews:
$reviewSnippets

Candidate recommendations (index: song by artist | genres):
$candidates

Task:
Return a JSON array of candidate indices, ordered best to worst for this user.
Rules:
1) Use each index at most once.
2) Prefer songs consistent with review sentiment and genre/artist affinities.
3) Penalize obvious popularity-only picks that weakly match the profile.
4) Return ONLY valid JSON (example: [3,1,0,2]).
''';

    try {
      final response = await http
          .post(
            Uri.parse(_openAiEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $openAIKey',
            },
            body: jsonEncode({
              'model': _model,
              'temperature': 0.15,
              'max_tokens': 500,
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'You are a strict ranking assistant. Return only a JSON array of integer indices with no commentary.',
                },
                {
                  'role': 'user',
                  'content': prompt,
                },
              ],
            }),
          )
          .timeout(_timeoutDuration);

      if (response.statusCode != 200) {
        debugPrint(
            '[RERANK] API error ${response.statusCode}, skipping rerank: ${response.body}');
        return recommendations;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = body['choices'] as List<dynamic>?;
      final firstChoice =
          choices != null && choices.isNotEmpty ? choices.first : null;
      final firstChoiceMap =
          firstChoice is Map ? Map<String, dynamic>.from(firstChoice) : null;
      final messageRaw = firstChoiceMap?['message'];
      final message =
          messageRaw is Map ? Map<String, dynamic>.from(messageRaw) : null;
      final content = message?['content']?.toString() ?? '';
      final orderedIndices =
          _parseRerankIndices(content, maxIndexExclusive: candidatePool.length);
      if (orderedIndices.isEmpty) {
        debugPrint(
            '[RERANK] Empty/invalid rerank response, using semantic order');
        return recommendations;
      }

      final reRanked = <MusicRecommendation>[];
      final seen = <int>{};
      for (final index in orderedIndices) {
        if (index >= 0 && index < candidatePool.length && seen.add(index)) {
          reRanked.add(candidatePool[index]);
        }
      }
      for (int i = 0; i < candidatePool.length; i++) {
        if (!seen.contains(i)) {
          reRanked.add(candidatePool[i]);
        }
      }

      debugPrint(
          '[RERANK] Applied LLM reranking to ${candidatePool.length} candidates');
      return <MusicRecommendation>[
        ...reRanked,
        ...remaining,
      ];
    } catch (e) {
      debugPrint('[RERANK] Error during LLM rerank, using semantic order: $e');
      return recommendations;
    }
  }

  static List<int> _parseRerankIndices(
    String content, {
    required int maxIndexExclusive,
  }) {
    if (content.trim().isEmpty || maxIndexExclusive <= 0) return const [];
    try {
      var clean =
          content.replaceAll('```json', '').replaceAll('```', '').trim();

      final start = clean.indexOf('[');
      final end = clean.lastIndexOf(']');
      if (start >= 0 && end > start) {
        clean = clean.substring(start, end + 1);
      }

      final decoded = jsonDecode(clean);
      if (decoded is! List) return const [];

      final indices = <int>[];
      final seen = <int>{};
      for (final item in decoded) {
        final value = item is int ? item : (item is num ? item.toInt() : null);
        if (value == null) continue;
        if (value < 0 || value >= maxIndexExclusive) continue;
        if (seen.add(value)) {
          indices.add(value);
        }
      }
      return indices;
    } catch (_) {
      return const [];
    }
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
              'You are a music recommendation engine. CRITICAL: Only recommend songs that you KNOW exist on Spotify. Do NOT invent, guess, or create song titles, artist names, or album names. All recommendations will be validated against Spotify\'s API - any fake or non-existent songs will be automatically rejected. If you cannot find enough real songs, return fewer valid recommendations rather than inventing fake ones. Every recommendation object MUST include a "reason" field explaining why it matches the user\'s taste. Respond only with valid JSON arrays.'
        },
        {'role': 'user', 'content': prompt}
      ]
    });

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final response = await http
            .post(Uri.parse(_openAiEndpoint), headers: headers, body: body)
            .timeout(_timeoutDuration);
        debugPrint('Response status: ${response.body}');

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

  /// Escapes unescaped double quotes inside JSON string values.
  ///
  /// GPT sometimes returns names like `"Evelyn "Champagne" King"` where the
  /// inner quotes are not escaped, breaking [jsonDecode]. This scanner repairs
  /// those cases by checking whether each `"` encountered inside a string is
  /// followed by a structural JSON character (`,`, `}`, `]`, `:`). If not, the
  /// quote must be part of the string content and is escaped as `\"`.
  static String _sanitizeJsonQuotes(String input) {
    final buf = StringBuffer();
    bool inString = false;
    bool escaped = false;
    for (int i = 0; i < input.length; i++) {
      final c = input[i];
      if (escaped) {
        buf.write(c);
        escaped = false;
        continue;
      }
      if (c == r'\') {
        buf.write(c);
        escaped = true;
        continue;
      }
      if (c != '"') {
        buf.write(c);
        continue;
      }
      // c == '"'
      if (!inString) {
        inString = true;
        buf.write(c);
      } else {
        // Peek ahead past whitespace to find the next meaningful character.
        int j = i + 1;
        while (j < input.length &&
            (input[j] == ' ' ||
                input[j] == '\t' ||
                input[j] == '\n' ||
                input[j] == '\r')) {
          j++;
        }
        final next = j < input.length ? input[j] : '\x00';
        if (next == ',' || next == '}' || next == ']' || next == ':' || j >= input.length) {
          // Real closing quote — exit string context.
          inString = false;
          buf.write(c);
        } else {
          // Unescaped quote inside a string value — escape it.
          buf.write(r'\"');
        }
      }
    }
    return buf.toString();
  }

  static List<MusicRecommendation> _parseRecommendations(String response) {
    try {
      // Clean response - remove markdown code blocks if present
      final cleanResponse =
          response.replaceAll('```json', '').replaceAll('```', '').trim();

      // Try direct parse first; if it fails due to unescaped quotes (common
      // with artist names like Evelyn "Champagne" King), sanitize and retry.
      dynamic decoded;
      try {
        decoded = jsonDecode(cleanResponse);
      } on FormatException {
        decoded = jsonDecode(_sanitizeJsonQuotes(cleanResponse));
      }

      // Handle both array and single object responses
      List<dynamic> parsed;
      if (decoded is List) {
        parsed = decoded;
      } else if (decoded is Map) {
        parsed = [decoded];
      } else {
        throw ParseException(
            'Unexpected response format: ${decoded.runtimeType}');
      }

      final recommendations = parsed
          .map((item) {
            try {
              if (item is Map<String, dynamic>) {
                return MusicRecommendation.fromJson(item);
              } else {
                debugPrint('Skipping invalid item: $item');
                return null;
              }
            } catch (e) {
              debugPrint('Error parsing item $item: $e');
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

  /// Log shown recommendations in the background for outcome tracking (Phase 4).
  static void _logShownRecommendationsInBackground(
      List<MusicRecommendation> recs) {
    Future(() async {
      try {
        final records = recs
            .map((r) => RecommendationRecord(
                  track: r.song,
                  artist: r.artist,
                  source: 'ai', // Default; could be enriched with actual source
                ))
            .toList();
        await RecommendationOutcomeService.logRecommendationsShown(
          recommendations: records,
        );
      } catch (e) {
        debugPrint('[OUTCOMES] Error logging shown recs: $e');
      }
    });
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
        final cacheKey =
            '${rec.song.toLowerCase().trim()}|${rec.artist.toLowerCase().trim()}';
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

      debugPrint(
          'Validation cache hit: ${recommendations.length - uncachedRecs.length}/${recommendations.length}');

      // Only validate uncached recommendations
      if (uncachedRecs.isNotEmpty) {
        // Validate uncached recommendations (with rate limiting for MusicBrainz if needed)
        final validationResults = validationMode == 'spotify-only'
            ? await _validateBatchSpotifyOnly(
                uncachedRecs, spotify, skipMetadataEnrichment)
            : await _validateBatchWithRateLimit(
                uncachedRecs, spotify, skipMetadataEnrichment);

        // Update cache and results
        int uncachedIndex = 0;
        for (int i = 0; i < recommendations.length; i++) {
          if (cachedResults[i] == null && uncachedIndex < uncachedRecs.length) {
            final rec = uncachedRecs[uncachedIndex];
            final cacheKey =
                '${rec.song.toLowerCase().trim()}|${rec.artist.toLowerCase().trim()}';
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
      debugPrint('Error validating recommendations: $e');
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
      final result = await _validateSingleRecommendation(spotify, rec,
          skipMetadataEnrichment: skipMetadataEnrichment);
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
      recommendations.map((rec) => _validateSingleRecommendationSpotifyOnly(
          spotify, rec, skipMetadataEnrichment)),
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
      final trackQuery =
          'track:"${recommendation.song}" artist:"${recommendation.artist.split(',').first.trim()}"';
      final trackSearchResults = await spotify.search
          .get(trackQuery, types: [SearchType.track]).first(1);

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
      debugPrint(
          '⚠️  Track not found on Spotify: "${recommendation.song}" by "${recommendation.artist}"');
      return null;
    } catch (e) {
      debugPrint('Error validating with Spotify: $e');
      return null;
    }
  }

  /// Maintains validation cache size
  static void _updateValidationCacheSize() {
    if (_validationCache.length > _maxValidationCacheSize) {
      // Remove oldest entries (simple FIFO - remove first 20%)
      final keysToRemove =
          _validationCache.keys.take(_maxValidationCacheSize ~/ 5).toList();
      for (final key in keysToRemove) {
        _validationCache.remove(key);
      }
    }
  }

  /// Validates AI recommendations using a hybrid approach:
  /// 1. First checks MusicBrainz (broader coverage, free, no rate limits)
  /// 2. Then checks Spotify (to get metadata like images, ensures track is playable)
  /// Returns only recommendations that exist in MusicBrainz (Spotify is optional for metadata)
  static Future<List<MusicRecommendation>>
      _validateRecommendationsAgainstSpotify(
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
      debugPrint(
          'Checking MusicBrainz for "${recommendation.song}" by "${recommendation.artist}"...');
      final existsInMusicBrainz = await MusicBrainzService.validateTrackExists(
        recommendation.song,
        recommendation.artist,
      );

      if (!existsInMusicBrainz) {
        // Track doesn't exist in MusicBrainz - likely a hallucination
        debugPrint(
            '⚠️  AI hallucination detected: "${recommendation.song}" by "${recommendation.artist}" not found in MusicBrainz');
        return null;
      }

      // Step 2: Track exists in MusicBrainz, now try Spotify to get metadata (images, etc.)
      debugPrint(
          'Track found in MusicBrainz, checking Spotify for metadata...');
      try {
        // Try searching for the track on Spotify (most accurate)
        final trackQuery =
            'track:"${recommendation.song}" artist:"${recommendation.artist.split(',').first.trim()}"';
        final trackSearchResults = await spotify.search
            .get(trackQuery, types: [SearchType.track]).first(1);

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

                debugPrint(
                    '✓ Track found on Spotify with metadata: "${recommendation.song}" by "${recommendation.artist}"');

                if (skipMetadataEnrichment) {
                  // Just return original (validated existence, skip metadata)
                  return recommendation;
                }

                return MusicRecommendation(
                  song: item.name ?? recommendation.song,
                  artist: artistName,
                  album: albumName,
                  imageUrl: imageUrl,
                  genres: recommendation
                      .genres, // Keep existing genres, will be enriched later
                );
              }
            }
          }
        }

        // If exact search didn't find it, try a more lenient search (without quotes for fuzzy matching)
        final lenientQuery =
            '${recommendation.song} ${recommendation.artist.split(',').first.trim()}';
        final lenientSearchResults = await spotify.search
            .get(lenientQuery, types: [SearchType.track]).first(1);

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
                final recArtistLower =
                    recommendation.artist.split(',').first.trim().toLowerCase();

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
                      ? (item.album!.images!.first.url ??
                          recommendation.imageUrl)
                      : recommendation.imageUrl;

                  debugPrint(
                      '✓ Track found on Spotify (fuzzy match) with metadata: "${recommendation.song}" by "${recommendation.artist}"');

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
        debugPrint(
            '✓ Track exists in MusicBrainz but not on Spotify (may not be playable): "${recommendation.song}" by "${recommendation.artist}"');
        return recommendation; // Return as-is since we can't get Spotify metadata
      } catch (e) {
        debugPrint(
            'Error checking Spotify (but track exists in MusicBrainz): $e');
        // Track exists in MusicBrainz, so it's valid even if Spotify check fails
        debugPrint(
            '✓ Track validated in MusicBrainz (Spotify check failed): "${recommendation.song}" by "${recommendation.artist}"');
        return recommendation;
      }
    } catch (e) {
      debugPrint(
          'Error validating "${recommendation.song}" by "${recommendation.artist}": $e');
      // If validation fails for this specific track, exclude it to be safe
      return null;
    }
  }

  /// Enrich recommendations with MusicBrainz genres (hybrid Spotify + MusicBrainz approach)
  static Future<List<MusicRecommendation>> _enrichRecommendationsWithGenres(
    List<MusicRecommendation> recommendations, {
    bool allowMusicBrainzNetwork = true,
    bool allowSpotifyFallback = true,
  }) async {
    if (recommendations.isEmpty) return <MusicRecommendation>[];

    SpotifyApi? spotify;
    if (allowSpotifyFallback) {
      try {
        final credentials = SpotifyApiCredentials(clientId, clientSecret);
        spotify = SpotifyApi(credentials);
      } catch (_) {
        spotify = null;
      }
    }

    final futures = recommendations.map((rec) {
      return _enrichRecommendationGenres(
        rec,
        spotify: spotify,
        allowMusicBrainzNetwork: allowMusicBrainzNetwork,
        allowSpotifyFallback: allowSpotifyFallback,
      );
    }).toList();

    return Future.wait(futures);
  }

  static Future<MusicRecommendation> _enrichRecommendationGenres(
    MusicRecommendation rec, {
    SpotifyApi? spotify,
    required bool allowMusicBrainzNetwork,
    required bool allowSpotifyFallback,
  }) async {
    List<String> genres = List.from(rec.genres);

    if (genres.isEmpty || genres.length < 2) {
      try {
        final cachedGenres = await GenreCacheService.getGenresWithCache(
          rec.song,
          rec.artist.split(',').first.trim(),
          allowNetworkFetch: allowMusicBrainzNetwork,
        );

        if (cachedGenres.isNotEmpty) {
          final cachedGenresSet =
              cachedGenres.map((g) => g.toLowerCase().trim()).toSet();
          genres = cachedGenres.toList();
          for (final existing in rec.genres) {
            if (!cachedGenresSet.contains(existing.toLowerCase().trim())) {
              genres.add(existing);
            }
          }
        }
      } catch (e) {
        debugPrint('Error enriching ${rec.song} with genres: $e');
      }
    }

    if (allowSpotifyFallback && genres.isEmpty && spotify != null) {
      try {
        final artistName = rec.artist.split(',').first.trim();
        final searchResults = await spotify.search
            .get(artistName, types: [SearchType.artist]).first(1);

        for (final page in searchResults) {
          if (page.items == null) continue;
          for (final item in page.items!) {
            if (item is Artist &&
                item.genres != null &&
                item.genres!.isNotEmpty) {
              genres = item.genres!.toList();
              break;
            }
          }
          if (genres.isNotEmpty) break;
        }
      } catch (e) {
        debugPrint('Error getting Spotify artist genres for ${rec.song}: $e');
      }
    }

    return MusicRecommendation(
      song: rec.song,
      artist: rec.artist,
      album: rec.album,
      imageUrl: rec.imageUrl,
      genres: genres,
    );
  }

  /// Warms MusicBrainz-backed genre cache off the request critical path.
  static void _warmGenreCacheInBackground(List<MusicRecommendation> recs) {
    Future(() async {
      try {
        await _enrichRecommendationsWithGenres(
          recs,
          allowMusicBrainzNetwork: true,
          allowSpotifyFallback: false,
        );
      } catch (e) {
        debugPrint('Error warming genre cache: $e');
      }
    });
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
                .get(query, types: [SearchType.track]).first(1);

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
                  .get(albumQuery, types: [SearchType.album]).first(1);

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
            debugPrint(
                'Error fetching image for ${rec.song} by ${rec.artist}: $e');
            // Return original recommendation if fetch fails
            return rec;
          }
        });

        // Wait for all images to be fetched in parallel
        final updatedRecommendations = await Future.wait(futures);

        // Update cache with images (this would require modifying the cache structure)
        // For now, images will be fetched on next load or we could emit an event
        debugPrint('Fetched ${updatedRecommendations.length} album images');
      } catch (e) {
        debugPrint('Error in _fetchAlbumImagesInBackground: $e');
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
      final query =
          'track:"${recommendation.song}" artist:"${recommendation.artist}"';
      final searchResults =
          await spotify.search.get(query, types: [SearchType.track]).first(1);

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
            .get(albumQuery, types: [SearchType.album]).first(1);

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
      debugPrint('Error fetching image for ${recommendation.song}: $e');
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
