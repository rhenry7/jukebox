import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test_project/services/get_album_service.dart';

/// Service to cache genres in Firestore to avoid repeated API calls
class GenreCacheService {
  static const String _collectionName = 'trackGenres';
  
  /// Generate a cache key from track title and artist
  static String _generateCacheKey(String title, String artist) {
    // Normalize: lowercase, trim, remove special characters for consistency
    final normalizedTitle = title.toLowerCase().trim();
    final normalizedArtist = artist.toLowerCase().trim().split(',').first.trim();
    return '$normalizedTitle|$normalizedArtist';
  }

  /// Get cached genres for a track
  static Future<List<String>?> getCachedGenres(String title, String artist) async {
    try {
      final cacheKey = _generateCacheKey(title, artist);
      final doc = await FirebaseFirestore.instance
          .collection(_collectionName)
          .doc(cacheKey)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final genres = data['genres'] as List<dynamic>?;
        if (genres != null && genres.isNotEmpty) {
          final genreList = genres.map((g) => g.toString()).toList();
          debugPrint('Found cached genres for $title by $artist: $genreList');
          return genreList;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting cached genres: $e');
      return null;
    }
  }

  /// Cache genres for a track
  static Future<void> cacheGenres(
    String title,
    String artist,
    List<String> genres,
  ) async {
    if (genres.isEmpty) return; // Don't cache empty genres
    
    try {
      final cacheKey = _generateCacheKey(title, artist);
      await FirebaseFirestore.instance
          .collection(_collectionName)
          .doc(cacheKey)
          .set({
        'title': title,
        'artist': artist,
        'genres': genres,
        'cachedAt': FieldValue.serverTimestamp(),
        'source': 'musicbrainz', // Track where genres came from
      }, SetOptions(merge: true));
      
      debugPrint('Cached ${genres.length} genres for $title by $artist');
    } catch (e) {
      debugPrint('Error caching genres: $e');
    }
  }

  /// Get genres with caching: checks cache first, then fetches from API if needed
  static Future<List<String>> getGenresWithCache(
    String title,
    String artist,
  ) async {
    // 1. Check cache first
    final cachedGenres = await getCachedGenres(title, artist);
    if (cachedGenres != null && cachedGenres.isNotEmpty) {
      return cachedGenres;
    }

    // 2. Fetch from MusicBrainz API
    try {
      final mbAlbum = await MusicBrainzService.searchByTitleAndArtist(title, artist);
      
      if (mbAlbum != null && mbAlbum.genres != null && mbAlbum.genres!.isNotEmpty) {
        final genres = mbAlbum.genres!;
        
        // 3. Cache the results for future use
        await cacheGenres(title, artist, genres);
        
        return genres;
      }
    } catch (e) {
      debugPrint('Error fetching genres from MusicBrainz: $e');
    }

    // 4. Return empty if nothing found
    return [];
  }

  /// Clear cache for a specific track (useful if genres need to be refreshed)
  static Future<void> clearCache(String title, String artist) async {
    try {
      final cacheKey = _generateCacheKey(title, artist);
      await FirebaseFirestore.instance
          .collection(_collectionName)
          .doc(cacheKey)
          .delete();
      debugPrint('Cleared genre cache for $title by $artist');
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }

  /// Clear all genre caches (admin function)
  static Future<void> clearAllCache() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(_collectionName)
          .get();
      
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      debugPrint('Cleared all genre caches');
    } catch (e) {
      debugPrint('Error clearing all caches: $e');
    }
  }
}
