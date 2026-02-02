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
    return await WikipediaBioCacheService.getBioWithCache(
      artistName,
      () => _fetchArtistSummaryFromAPI(artistName),
    );
  }

  /// Internal method to fetch bio from Wikipedia API (called by cache service)
  static Future<String?> _fetchArtistSummaryFromAPI(String artistName) async {
    try {
      // Try multiple variations of the artist name to handle different page titles
      // REST API automatically handles redirects, so we can try direct access
      final nameVariations = [
        artistName, // Original name
        artistName.replaceAll(' ', '_'), // With underscores (common Wikipedia format)
        // Try with common disambiguation suffixes
        '$artistName (band)',
        '$artistName (musician)',
        '$artistName (singer)',
        '$artistName (artist)',
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
            },
          ).timeout(const Duration(seconds: 5));

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final extract = data['extract'] as String?;
            
            // Return first 2-3 sentences (approximately 200-300 characters)
            if (extract != null && extract.isNotEmpty) {
              // Find the first few sentences
              final sentences = extract.split('. ');
              if (sentences.length >= 2) {
                return '${sentences.take(2).join('. ')}.';
              }
              // If less than 2 sentences, return first 250 characters
              return extract.length > 250 ? '${extract.substring(0, 250)}...' : extract;
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

  /// Get Wikipedia bio without caching (for cache service use)
  /// This is the actual API fetch method
  static Future<String?> getArtistSummaryUncached(String artistName) async {
    return await _fetchArtistSummaryFromAPI(artistName);
  }
}
