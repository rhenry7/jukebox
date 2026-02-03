import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_test_project/services/wikipedia_bio_cache_service.dart';

/// Simple service to fetch artist information from Wikipedia
/// Uses REST API directly to avoid CORS issues with MediaWiki API
class WikipediaService {
  static const String _baseUrl = 'https://en.wikipedia.org/api/rest_v1';

  /// Get Wikipedia page summary (bio) for an artist with caching
  /// Uses REST API directly (handles redirects automatically) to avoid CORS issues
  static Future<String?> getArtistSummary(String artistName) async {
    // Use cache service to check cache first, then fetch if needed
    return WikipediaBioCacheService.getBioWithCache(
      artistName,
      () => _fetchArtistSummaryFromAPI(artistName),
    );
  }

  /// Internal method to fetch bio from Wikipedia API (called by cache service)
  static Future<String?> _fetchArtistSummaryFromAPI(String artistName) async {
    try {
      // PRIORITIZE musical disambiguation suffixes FIRST to avoid matching wrong pages
      // (e.g., "Train" should match "Train (band)" not "Train (vehicle)")
      final nameVariations = [
        // Try musical disambiguation suffixes FIRST
        '$artistName (band)',
        '$artistName (musician)',
        '$artistName (singer)',
        '$artistName (artist)',
        '$artistName (musical group)',
        '$artistName (group)',
        // Then try with underscores
        artistName.replaceAll(' ', '_'),
        '$artistName (band)'.replaceAll(' ', '_'),
        '$artistName (musician)'.replaceAll(' ', '_'),
        // Finally try original name (last resort)
        artistName,
      ];

      for (final name in nameVariations) {
        try {
          // Use REST API directly (handles redirects automatically, no CORS issues)
          final encodedTitle = Uri.encodeComponent(name);
          final url = Uri.parse('$_baseUrl/page/summary/$encodedTitle');

          final response = await http.get(
            url,
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'Jukeboxd/1.0 (https://juxeboxd.web.app)',
              'Origin': 'https://juxeboxd.web.app', // Add origin header for CORS
            },
          ).timeout(
            const Duration(seconds: 10), // Longer timeout for production
            onTimeout: () {
              throw TimeoutException('Wikipedia API request timed out');
            },
          );

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final extract = data['extract'] as String?;
            
            // Validate that the extract is actually about music/musicians
            if (extract != null && extract.isNotEmpty) {
              // Check if this is actually about music (avoid matching wrong pages)
              final extractLower = extract.toLowerCase();
              final isMusical = _isMusicalContent(extractLower, artistName);
              
              if (isMusical) {
                // Return first 2-3 sentences (approximately 200-300 characters)
                final sentences = extract.split('. ');
                if (sentences.length >= 2) {
                  return '${sentences.take(2).join('. ')}.';
                }
                // If less than 2 sentences, return first 250 characters
                return extract.length > 250 ? '${extract.substring(0, 250)}...' : extract;
              } else {
                // Not musical content - try next variation
                continue;
              }
            }
          } else if (response.statusCode == 404) {
            // Try next variation
            continue;
          }
        } on TimeoutException {
          // Timeout - try next variation
          continue;
        } catch (e) {
          // CORS or other error - try next variation silently
          // Don't log CORS errors as they're expected on web
          if (name == nameVariations.last && 
              !e.toString().contains('CORS') && 
              !e.toString().contains('XMLHttpRequest')) {
            // Only log non-CORS errors on last attempt
            print('⚠️  Wikipedia page not found for: $artistName');
          }
          continue;
        }
      }
      
      // All attempts failed - return null silently
      return null;
    } catch (e) {
      // Silently fail - don't spam console
      return null;
    }
  }

  /// Validate that Wikipedia extract is about music/musicians
  /// Returns true if the content appears to be about a musical artist/band
  static bool _isMusicalContent(String extractLower, String artistName) {
    // Musical keywords that indicate this is about music
    final musicalKeywords = [
      'band', 'musician', 'singer', 'artist', 'album', 'song', 'music',
      'record', 'recording', 'single', 'ep', 'tour', 'concert', 'guitar',
      'bass', 'drums', 'piano', 'vocal', 'lyrics', 'composer', 'producer',
      'label', 'chart', 'billboard', 'grammy', 'award', 'genre', 'rock',
      'pop', 'jazz', 'hip hop', 'rap', 'country', 'folk', 'electronic',
      'indie', 'alternative', 'punk', 'metal', 'blues', 'r&b', 'soul',
      'released', 'debut', 'hit', 'top', 'radio', 'streaming', 'spotify',
    ];
    
    // Non-musical keywords that indicate this is NOT about music
    // (e.g., "train" as vehicle, "eagle" as bird, etc.)
    final nonMusicalKeywords = [
      'vehicle', 'transport', 'locomotive', 'railway', 'station',
      'bird', 'animal', 'species', 'wildlife', 'habitat',
      'company', 'corporation', 'business', 'industry', 'manufacturing',
      'plant', 'tree', 'flower', 'botanical',
      'city', 'town', 'place', 'location', 'geography',
      'person', 'politician', 'scientist', 'writer', 'author', 'actor',
    ];
    
    // Check for non-musical keywords first (higher priority)
    for (final keyword in nonMusicalKeywords) {
      if (extractLower.contains(keyword) && 
          !extractLower.contains('music') && 
          !extractLower.contains('band') &&
          !extractLower.contains('song')) {
        // If it contains non-musical keywords but no musical context, likely wrong page
        return false;
      }
    }
    
    // Check for musical keywords
    int musicalScore = 0;
    for (final keyword in musicalKeywords) {
      if (extractLower.contains(keyword)) {
        musicalScore++;
      }
    }
    
    // If we found at least 2 musical keywords, it's likely about music
    // OR if the artist name appears in musical context
    if (musicalScore >= 2) {
      return true;
    }
    
    // If artist name appears with musical context, accept it
    if (extractLower.contains(artistName.toLowerCase()) && musicalScore >= 1) {
      return true;
    }
    
    // Default: if we have at least 1 musical keyword, accept it
    // (better to show something than nothing, but prioritize better matches)
    return musicalScore >= 1;
  }

  /// Get Wikipedia bio without caching (for cache service use)
  /// This is the actual API fetch method
  static Future<String?> getArtistSummaryUncached(String artistName) async {
    return _fetchArtistSummaryFromAPI(artistName);
  }
}
