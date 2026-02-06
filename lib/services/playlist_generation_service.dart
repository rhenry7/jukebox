import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_test_project/Api/api_key.dart';
import 'package:flutter_test_project/models/enhanced_user_preferences.dart';
import 'package:flutter_test_project/services/album_art_cache_service.dart';
import 'package:spotify/spotify.dart' as spotify;

/// HTTP timeout for MusicBrainz API requests in playlist generation.
const _httpTimeout = Duration(seconds: 20);

/// Playlist track with MusicBrainz metadata
class PlaylistTrack {
  final String title;
  final String artist;
  final String? albumTitle;
  final DateTime? releaseDate;
  final List<String> tags; // Genres, moods, eras, etc.
  final String? musicBrainzId;
  final String? recordingId;
  final double? rating; // Community rating if available
  final String? area; // Geographic origin
  final List<String>? relatedArtists; // Collaborators
  final String? imageUrl; // Album cover art URL

  PlaylistTrack({
    required this.title,
    required this.artist,
    this.albumTitle,
    this.releaseDate,
    this.tags = const [],
    this.musicBrainzId,
    this.recordingId,
    this.rating,
    this.area,
    this.relatedArtists,
    this.imageUrl,
  });
}

class PlaylistGenerationService {
  static const String _baseUrl = 'https://musicbrainz.org/ws/2';

  /// Queue-based rate limiter: ensures only 1 request per second globally.
  static final List<Completer<void>> _requestQueue = [];
  static bool _processing = false;

  static Future<void> _rateLimit() async {
    final completer = Completer<void>();
    _requestQueue.add(completer);
    if (!_processing) {
      _processQueue();
    }
    return completer.future;
  }

  static Future<void> _processQueue() async {
    _processing = true;
    while (_requestQueue.isNotEmpty) {
      final next = _requestQueue.removeAt(0);
      next.complete();
      await Future.delayed(const Duration(milliseconds: 1100));
    }
    _processing = false;
  }

  /// Generate playlist based on user preferences using MusicBrainz
  /// Prioritizes: Genre Weights > Mood > Tempo
  /// If context is provided, uses context-specific genre and tempo preferences
  static Future<List<PlaylistTrack>> generatePlaylist({
    required EnhancedUserPreferences preferences,
    String? context, // 'workout', 'study', 'party', 'chill', 'sleep', etc.
    int trackCount = 20,
  }) async {
    // Step 1: Get context-specific genre and tempo preferences
    final contextGenres = _getContextGenres(context, preferences);
    final contextTempo = _getContextTempo(context, preferences);
    final contextMood = _getContextMood(context, preferences);

    // Step 2: Get tracks from genres (use context genres if available, otherwise user preferences)
    List<PlaylistTrack> genreTracks = [];
    final genresToUse = contextGenres.isNotEmpty ? contextGenres : preferences.favoriteGenres;
    final genreWeightsToUse = contextGenres.isNotEmpty 
        ? _getContextGenreWeights(contextGenres, preferences)
        : preferences.genreWeights;

    if (genresToUse.isNotEmpty) {
      genreTracks = await _getTracksByGenres(
        genresToUse,
        genreWeightsToUse,
        limit: trackCount * 2, // Get more tracks to filter from
      );
    }

    if (genreTracks.isEmpty) {
      return []; // No tracks found
    }

    // Step 3: Apply mood filters (use context mood if available)
    final moodFiltered = _applyMoodFilters(
      genreTracks,
      contextMood,
      context,
    );

    // Step 4: Apply tempo preferences (use context tempo if available)
    final tempoFiltered = _applyTempoFilters(
      moodFiltered.isNotEmpty ? moodFiltered : genreTracks,
      contextTempo,
    );

    // Step 5: Rank by preferences with context-specific weighting
    final ranked = _rankByPreferences(
      tempoFiltered.isNotEmpty ? tempoFiltered : moodFiltered.isNotEmpty ? moodFiltered : genreTracks,
      preferences,
      context,
      contextGenres: contextGenres,
      contextTempo: contextTempo,
    );

    // Step 6: Remove duplicates and return top tracks
    final finalTracks = _deduplicateAndReturn(ranked, trackCount);
    
    // Step 7: Enrich with album art (fetch images)
    return enrichTracksWithImages(finalTracks);
  }

  /// Fetch album art for a single track using Spotify API (with caching)
  static Future<String?> fetchAlbumArt(String title, String artist) async {
    // Use cache service to check cache first, then fetch if needed
    return AlbumArtCacheService.getAlbumArtWithCache(
      title,
      artist,
      () async {
        try {
          final credentials = spotify.SpotifyApiCredentials(clientId, clientSecret);
          final spotifyApi = spotify.SpotifyApi(credentials);
          
          // Search for track on Spotify
          final query = 'track:"$title" artist:"$artist"';
          final searchResults = await spotifyApi.search
              .get(query, types: [spotify.SearchType.track])
              .first(1);
          
          if (searchResults.isNotEmpty) {
            for (final page in searchResults) {
              if (page.items != null) {
                for (final item in page.items!) {
                  if (item is spotify.Track) {
                    final album = item.album;
                    if (album != null && album.images != null && album.images!.isNotEmpty) {
                      return album.images!.first.url;
                    }
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Error fetching image for $title by $artist: $e');
        }
        return null;
      },
    );
  }

  /// Enrich tracks with album art (fetches images for tracks that don't have them)
  /// Uses caching to avoid repeated API calls
  static Future<List<PlaylistTrack>> enrichTracksWithImages(
    List<PlaylistTrack> tracks,
  ) async {
    debugPrint('🎨 Enriching ${tracks.length} tracks with album art...');
    final enrichedTracks = <PlaylistTrack>[];
    
    // First, try to load all from cache in parallel (fast)
    final cacheResults = <String, String?>{};
    final cacheFutures = tracks.map((track) async {
      final key = '${track.title}|${track.artist}';
      if (track.imageUrl != null && track.imageUrl!.isNotEmpty) {
        cacheResults[key] = track.imageUrl;
        debugPrint('✅ Track already has image: ${track.title}');
        return;
      }
      final cachedUrl = await AlbumArtCacheService.getCachedAlbumArt(
        track.title,
        track.artist,
      );
      cacheResults[key] = cachedUrl;
      if (cachedUrl != null) {
        debugPrint('💾 Found cached image for: ${track.title}');
      }
    });
    
    await Future.wait(cacheFutures);
    
    // Process results: use cached images or fetch new ones
    int fetchedCount = 0;
    int cachedCount = 0;
    
    for (final track in tracks) {
      final key = '${track.title}|${track.artist}';
      String? imageUrl = cacheResults[key];
      
      // If not in cache, fetch from API
      if (imageUrl == null || imageUrl.isEmpty) {
        debugPrint('🔍 Fetching image for: ${track.title} by ${track.artist}');
        imageUrl = await fetchAlbumArt(track.title, track.artist);
        if (imageUrl != null && imageUrl.isNotEmpty) {
          fetchedCount++;
          debugPrint('✅ Fetched image for: ${track.title}');
        } else {
          debugPrint('❌ No image found for: ${track.title}');
        }
        // Small delay to avoid rate limiting (only for API calls)
        await Future.delayed(const Duration(milliseconds: 100));
      } else {
        cachedCount++;
      }
      
      // Create new track with image
      enrichedTracks.add(PlaylistTrack(
        title: track.title,
        artist: track.artist,
        albumTitle: track.albumTitle,
        releaseDate: track.releaseDate,
        tags: track.tags,
        musicBrainzId: track.musicBrainzId,
        recordingId: track.recordingId,
        rating: track.rating,
        area: track.area,
        relatedArtists: track.relatedArtists,
        imageUrl: imageUrl,
      ));
    }
    
    debugPrint('🎨 Image enrichment complete: $cachedCount from cache, $fetchedCount fetched, ${tracks.length - cachedCount - fetchedCount} without images');
    return enrichedTracks;
  }

  /// Get context-specific genres that fit the category
  static List<String> _getContextGenres(
    String? context,
    EnhancedUserPreferences preferences,
  ) {
    if (context == null) return [];

    // Map context to genres that typically fit that category
    // We'll use user's favorite genres but prioritize ones that fit the context
    final contextGenreMap = {
      'workout': ['hip hop', 'rap', 'electronic', 'rock', 'metal', 'dance', 'edm', 'pop'],
      'study': ['jazz', 'classical', 'ambient', 'instrumental', 'lo-fi', 'chill', 'acoustic'],
      'party': ['dance', 'electronic', 'edm', 'pop', 'hip hop', 'rap', 'house', 'techno'],
      'chill': ['jazz', 'ambient', 'chill', 'lo-fi', 'acoustic', 'folk', 'indie'],
      'sleep': ['ambient', 'classical', 'instrumental', 'meditation', 'nature sounds', 'piano'],
    };

    final contextGenres = contextGenreMap[context] ?? [];
    
    // Filter to only include genres the user actually likes
    return contextGenres.where((genre) => 
        preferences.favoriteGenres.any((fg) => 
            fg.toLowerCase().contains(genre.toLowerCase()) || 
            genre.toLowerCase().contains(fg.toLowerCase()))).toList();
  }

  /// Get context-specific genre weights
  static Map<String, double> _getContextGenreWeights(
    List<String> contextGenres,
    EnhancedUserPreferences preferences,
  ) {
    final weights = <String, double>{};
    
    for (final contextGenre in contextGenres) {
      // Find matching user genre
      final matchingGenre = preferences.favoriteGenres.firstWhere(
        (fg) => fg.toLowerCase().contains(contextGenre.toLowerCase()) || 
                contextGenre.toLowerCase().contains(fg.toLowerCase()),
        orElse: () => contextGenre,
      );
      
      // Use user's weight if available, otherwise give it a high weight
      weights[contextGenre] = preferences.genreWeights[matchingGenre] ?? 0.8;
    }
    
    return weights;
  }

  /// Get context-specific tempo preferences
  static Map<String, double> _getContextTempo(
    String? context,
    EnhancedUserPreferences preferences,
  ) {
    if (context == null) return preferences.tempoPreferences;

    // Map context to tempo preferences
    final contextTempoMap = {
      'workout': {'fast': 0.9, 'medium': 0.1, 'slow': 0.0},
      'study': {'fast': 0.0, 'medium': 0.2, 'slow': 0.8},
      'party': {'fast': 0.95, 'medium': 0.05, 'slow': 0.0},
      'chill': {'fast': 0.0, 'medium': 0.3, 'slow': 0.7},
      'sleep': {'fast': 0.0, 'medium': 0.0, 'slow': 1.0},
    };

    return contextTempoMap[context] ?? preferences.tempoPreferences;
  }

  /// Get context-specific mood preferences
  static Map<String, double> _getContextMood(
    String? context,
    EnhancedUserPreferences preferences,
  ) {
    if (context == null) return preferences.moodPreferences;

    // Map context to mood preferences
    final contextMoodMap = {
      'workout': {'energetic': 0.95, 'upbeat': 0.9, 'intense': 0.85, 'chill': 0.0},
      'study': {'chill': 0.9, 'calm': 0.95, 'focus': 0.9, 'energetic': 0.0},
      'party': {'energetic': 0.95, 'dance': 0.95, 'upbeat': 0.9, 'chill': 0.0},
      'chill': {'chill': 0.95, 'relaxed': 0.9, 'mellow': 0.85, 'energetic': 0.0},
      'sleep': {'calm': 0.95, 'peaceful': 0.95, 'ambient': 0.9, 'energetic': 0.0},
    };

    return contextMoodMap[context] ?? preferences.moodPreferences;
  }

  /// Get tracks by genre tags from MusicBrainz
  /// Prioritizes genres with higher weights (more tracks for higher weights)
  static Future<List<PlaylistTrack>> _getTracksByGenres(
    List<String> genres,
    Map<String, double> genreWeights, {
    int limit = 10,
  }) async {
    final List<PlaylistTrack> tracks = [];

    // Sort genres by weight (highest first)
    final sortedGenres = List<String>.from(genres);
    sortedGenres.sort((a, b) {
      final weightA = genreWeights[a] ?? 0.5;
      final weightB = genreWeights[b] ?? 0.5;
      return weightB.compareTo(weightA);
    });

    // Calculate total weight for distribution
    final totalWeight = sortedGenres.fold<double>(
      0.0,
      (sum, genre) => sum + (genreWeights[genre] ?? 0.5),
    );

    if (totalWeight == 0) return tracks;

    for (final genre in sortedGenres) {
      final weight = genreWeights[genre] ?? 0.5;
      // Allocate tracks proportionally to weight
      final tracksForGenre = ((limit * weight) / totalWeight).round();
      
      if (tracksForGenre > 0) {
        await _rateLimit();
        
        final url = Uri.parse('$_baseUrl/recording').replace(queryParameters: {
          'query': 'tag:"$genre"',
          'limit': tracksForGenre.toString(),
          'fmt': 'json',
          'inc': 'tags+ratings+artist-credits+releases',
        });

        try {
          final response = await http.get(url, headers: {
            'User-Agent': 'jukeboxd/1.0 (ramoneh94@gmail.com)',
          }).timeout(_httpTimeout);

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final recordings = data['recordings'] as List?;
            
            if (recordings != null) {
              for (final recording in recordings) {
                final track = _parseRecording(recording);
                if (track != null) {
                  // Store genre weight with track for ranking
                  tracks.add(track);
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Error fetching tracks for genre $genre: $e');
        }
      }
    }

    return tracks;
  }


  /// Get artist ID by name
  static Future<String?> _getArtistId(String artistName) async {
    await _rateLimit();
    
    final url = Uri.parse('$_baseUrl/artist').replace(queryParameters: {
      'query': 'artist:"$artistName"',
      'limit': '1',
      'fmt': 'json',
    });

    try {
      final response = await http.get(url, headers: {
        'User-Agent': 'jukeboxd/1.0 (ramoneh94@gmail.com)',
      }).timeout(_httpTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final artists = data['artists'] as List?;
        if (artists != null && artists.isNotEmpty) {
          return artists.first['id'] as String?;
        }
      }
    } catch (e) {
      debugPrint('Error finding artist ID for $artistName: $e');
    }
    return null;
  }

  /// Get recordings by artist ID
  static Future<List<PlaylistTrack>> _getArtistRecordings(
    String artistId, {
    int limit = 10,
  }) async {
    await _rateLimit();
    
    final url = Uri.parse('$_baseUrl/recording').replace(queryParameters: {
      'query': 'arid:$artistId',
      'limit': limit.toString(),
      'fmt': 'json',
      'inc': 'tags+ratings+artist-credits+releases',
    });

    try {
      final response = await http.get(url, headers: {
        'User-Agent': 'jukeboxd/1.0 (ramoneh94@gmail.com)',
      }).timeout(_httpTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final recordings = data['recordings'] as List?;
        
        if (recordings != null) {
          return recordings
              .map((e) => _parseRecording(e as Map<String, dynamic>))
              .whereType<PlaylistTrack>()
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching artist recordings: $e');
    }
    return [];
  }

  /// Parse recording JSON to PlaylistTrack
  static PlaylistTrack? _parseRecording(Map<String, dynamic> recording) {
    try {
      final title = recording['title'] as String? ?? 'Unknown';
      final id = recording['id'] as String?;
      
      // Get artist
      final artistCredits = recording['artist-credit'] as List?;
      String artist = 'Unknown';
      if (artistCredits != null && artistCredits.isNotEmpty) {
        artist = artistCredits.first['name'] as String? ?? 'Unknown';
      }

      // Get tags
      final tags = recording['tags'] as List?;
      final tagList = tags
          ?.map((tag) => tag['name'] as String?)
          .whereType<String>()
          .toList() ?? [];

      // Get rating
      final rating = recording['rating']?['value'] as String?;
      final ratingValue = rating != null ? double.tryParse(rating) : null;

      // Get release date from first release
      DateTime? releaseDate;
      final releases = recording['releases'] as List?;
      if (releases != null && releases.isNotEmpty) {
        final dateStr = releases.first['date'] as String?;
        if (dateStr != null && dateStr.length >= 4) {
          try {
            releaseDate = DateTime.parse(dateStr);
          } catch (_) {
            final year = int.tryParse(dateStr.substring(0, 4));
            if (year != null) releaseDate = DateTime(year);
          }
        }
      }

      return PlaylistTrack(
        title: title,
        artist: artist,
        tags: tagList,
        musicBrainzId: id,
        recordingId: id,
        rating: ratingValue,
        releaseDate: releaseDate,
      );
    } catch (e) {
      debugPrint('Error parsing recording: $e');
      return null;
    }
  }

  /// Apply mood filters based on tags
  /// Prioritizes tracks that match mood preferences
  static List<PlaylistTrack> _applyMoodFilters(
    List<PlaylistTrack> tracks,
    Map<String, double> moodPreferences,
    String? context,
  ) {
    // Map context to mood tags (if context provided, use it)
    final contextMoodMap = {
      'workout': ['energetic', 'upbeat', 'intense', 'powerful', 'high-energy'],
      'study': ['chill', 'ambient', 'instrumental', 'calm', 'focus', 'peaceful'],
      'party': ['energetic', 'dance', 'upbeat', 'festive', 'danceable'],
      'sleep': ['ambient', 'calm', 'peaceful', 'soft', 'quiet', 'relaxing'],
      'chill': ['chill', 'relaxed', 'mellow', 'calm', 'laid-back'],
    };

    // If context provided, use context moods; otherwise use preferences
    final targetMoods = context != null 
        ? contextMoodMap[context] ?? []
        : moodPreferences.entries
            .where((e) => e.value > 0.3) // Lower threshold to include more moods
            .map((e) => e.key.toLowerCase())
            .toList();

    if (targetMoods.isEmpty) return tracks;

    // Score tracks by mood match (prefer tracks that match, but don't exclude all)
    final scoredTracks = tracks.map((track) {
      final trackTags = track.tags.map((t) => t.toLowerCase()).toList();
      final matchCount = targetMoods.where((mood) => 
          trackTags.any((tag) => tag.contains(mood) || mood.contains(tag))).length;
      return MapEntry(track, matchCount);
    }).toList();

    // Sort by match count (highest first), but keep all tracks
    scoredTracks.sort((a, b) => b.value.compareTo(a.value));
    
    // Return all tracks (mood matching is used for ranking, not filtering)
    return scoredTracks.map((e) => e.key).toList();
  }

  /// Apply tempo preferences
  /// Scores tracks by tempo match (doesn't exclude, just ranks)
  static List<PlaylistTrack> _applyTempoFilters(
    List<PlaylistTrack> tracks,
    Map<String, double> tempoPreferences,
  ) {
    if (tempoPreferences.isEmpty) return tracks;

    // Find preferred tempo (highest weight)
    final preferredTempo = tempoPreferences.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key
        .toLowerCase();

    // Score tracks by tempo match
    final scoredTracks = tracks.map((track) {
      int score = 0;
      
      if (preferredTempo == 'fast') {
        // Prefer recent tracks (last 20 years)
        if (track.releaseDate != null) {
          final cutoff = DateTime.now().subtract(const Duration(days: 365 * 20));
          if (track.releaseDate!.isAfter(cutoff)) score += 2;
        }
        // Check for fast tempo tags
        final tags = track.tags.map((t) => t.toLowerCase()).toList();
        if (tags.any((t) => t.contains('fast') || t.contains('upbeat') || t.contains('energetic'))) {
          score += 1;
        }
      } else if (preferredTempo == 'slow') {
        // Prefer older tracks or slow tempo tags
        if (track.releaseDate != null) {
          final cutoff = DateTime.now().subtract(const Duration(days: 365 * 20));
          if (track.releaseDate!.isBefore(cutoff)) score += 2;
        }
        final tags = track.tags.map((t) => t.toLowerCase()).toList();
        if (tags.any((t) => t.contains('slow') || t.contains('ambient') || t.contains('calm'))) {
          score += 1;
        }
      } else if (preferredTempo == 'medium') {
        // Prefer medium tempo - balanced approach
        score = 1; // Neutral score
      }
      
      return MapEntry(track, score);
    }).toList();

    // Sort by tempo score (highest first)
    scoredTracks.sort((a, b) => b.value.compareTo(a.value));
    return scoredTracks.map((e) => e.key).toList();
  }


  /// Rank tracks by preferences: Genre Weight > Mood > Tempo > Rating
  /// Uses context-specific preferences if provided
  static List<PlaylistTrack> _rankByPreferences(
    List<PlaylistTrack> tracks,
    EnhancedUserPreferences preferences,
    String? context, {
    List<String>? contextGenres,
    Map<String, double>? contextTempo,
  }) {
    // Use context-specific preferences if available
    final genresToCheck = contextGenres ?? preferences.favoriteGenres;
    final genreWeightsToUse = contextGenres != null
        ? _getContextGenreWeights(contextGenres, preferences)
        : preferences.genreWeights;
    final tempoToUse = contextTempo ?? preferences.tempoPreferences;
    final moodToUse = context != null 
        ? _getContextMood(context, preferences)
        : preferences.moodPreferences;

    final scoredTracks = tracks.map((track) {
      double score = 0.0;

      // 1. Genre Weight (highest priority)
      // If context genres exist, prioritize those; otherwise use user preferences
      for (final genre in genresToCheck) {
        final weight = genreWeightsToUse[genre] ?? 
                       preferences.genreWeights[genre] ?? 
                       0.5;
        final trackTags = track.tags.map((t) => t.toLowerCase()).toList();
        if (trackTags.any((tag) => 
            tag.contains(genre.toLowerCase()) || 
            genre.toLowerCase().contains(tag))) {
          // Boost score more if it's a context genre
          final multiplier = contextGenres != null && contextGenres.contains(genre) ? 15 : 10;
          score += weight * multiplier;
        }
      }

      // 2. Mood Match (use context mood if available)
      if (moodToUse.isNotEmpty) {
        final trackTags = track.tags.map((t) => t.toLowerCase()).toList();
        for (final moodEntry in moodToUse.entries) {
          final mood = moodEntry.key.toLowerCase();
          final moodWeight = moodEntry.value;
          if (trackTags.any((tag) => tag.contains(mood) || mood.contains(tag))) {
            score += moodWeight * 5; // Mood is important but less than genre
          }
        }
      }

      // 3. Tempo Match (use context tempo if available)
      if (tempoToUse.isNotEmpty) {
        final preferredTempo = tempoToUse.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key
            .toLowerCase();
        
        if (preferredTempo == 'fast' && track.releaseDate != null) {
          final cutoff = DateTime.now().subtract(const Duration(days: 365 * 20));
          if (track.releaseDate!.isAfter(cutoff)) score += 3; // Boost for context tempo
        } else if (preferredTempo == 'slow' && track.releaseDate != null) {
          final cutoff = DateTime.now().subtract(const Duration(days: 365 * 20));
          if (track.releaseDate!.isBefore(cutoff)) score += 3; // Boost for context tempo
        }
      }

      // 4. Rating (bonus points)
      if (track.rating != null) {
        score += track.rating! * 0.5; // Small bonus for high ratings
      }

      return MapEntry(track, score);
    }).toList();
    
    // Sort by score descending
    scoredTracks.sort((a, b) => b.value.compareTo(a.value));
    
    // Return just the tracks (sorted by score)
    return scoredTracks.map((e) => e.key).toList();
  }

  /// Deduplicate and return top tracks
  static List<PlaylistTrack> _deduplicateAndReturn(
    List<PlaylistTrack> tracks,
    int targetCount,
  ) {
    // Remove duplicates by title + artist
    final seen = <String>{};
    final unique = <PlaylistTrack>[];
    
    for (final track in tracks) {
      final key = '${track.title.toLowerCase()}_${track.artist.toLowerCase()}';
      if (!seen.contains(key)) {
        seen.add(key);
        unique.add(track);
        if (unique.length >= targetCount) break;
      }
    }

    return unique;
  }

  /// Generate playlist by specific type
  static Future<List<PlaylistTrack>> generatePlaylistByType({
    required EnhancedUserPreferences preferences,
    required String playlistType, // 'genre', 'mood'
    int trackCount = 20,
  }) async {
    List<PlaylistTrack> finalTracks;
    
    switch (playlistType) {
      case 'genre':
        // Genre-only playlist, still apply mood and tempo for ranking
        final genreTracks = await _getTracksByGenres(
          preferences.favoriteGenres,
          preferences.genreWeights,
          limit: trackCount * 2,
        );
        final moodFiltered = _applyMoodFilters(
          genreTracks,
          preferences.moodPreferences,
          null,
        );
        final tempoFiltered = _applyTempoFilters(
          moodFiltered,
          preferences.tempoPreferences,
        );
        final ranked = _rankByPreferences(
          tempoFiltered,
          preferences,
          null,
        );
        finalTracks = _deduplicateAndReturn(ranked, trackCount);
        break;
      
      case 'mood':
        // Mood-focused playlist
        final genreTracks = await _getTracksByGenres(
          preferences.favoriteGenres,
          preferences.genreWeights,
          limit: trackCount * 2,
        );
        final moodFiltered = _applyMoodFilters(
          genreTracks,
          preferences.moodPreferences,
          null,
        );
        final tempoFiltered = _applyTempoFilters(
          moodFiltered,
          preferences.tempoPreferences,
        );
        final ranked = _rankByPreferences(
          tempoFiltered,
          preferences,
          null,
        );
        finalTracks = _deduplicateAndReturn(ranked, trackCount);
        break;
      
      default:
        return generatePlaylist(
          preferences: preferences,
          trackCount: trackCount,
        );
    }
    
    // Enrich with album art (fetch images)
    return enrichTracksWithImages(finalTracks);
  }
}
