import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service to cache album art URLs in Firestore to avoid repeated API calls.
/// Cached entries expire after [_cacheTtl] and are treated as stale on read.
class AlbumArtCacheService {
  static const String _collectionName = 'albumArt';

  /// How long a cached album art URL is considered fresh (30 days).
  static const Duration _cacheTtl = Duration(days: 30);
  
  /// Generate a cache key from track title and artist
  /// Sanitizes to ensure valid Firestore document ID
  static String _generateCacheKey(String title, String artist) {
    // Normalize: lowercase, trim
    final normalizedTitle = title.toLowerCase().trim();
    final normalizedArtist = artist.toLowerCase().trim().split(',').first.trim();
    
    // Replace invalid Firestore document ID characters
    // Firestore document IDs cannot contain: /, \, ?, #, [, ], *, and cannot be longer than 1500 bytes
    final String sanitizedTitle = normalizedTitle
        .replaceAll('/', '_')
        .replaceAll('\\', '_')
        .replaceAll('?', '_')
        .replaceAll('#', '_')
        .replaceAll('[', '_')
        .replaceAll(']', '_')
        .replaceAll('*', '_')
        .replaceAll('|', '_'); // Also replace pipe for cleaner keys
    
    final String sanitizedArtist = normalizedArtist
        .replaceAll('/', '_')
        .replaceAll('\\', '_')
        .replaceAll('?', '_')
        .replaceAll('#', '_')
        .replaceAll('[', '_')
        .replaceAll(']', '_')
        .replaceAll('*', '_')
        .replaceAll('|', '_');
    
    // Use underscore separator instead of pipe
    final cacheKey = '${sanitizedTitle}_$sanitizedArtist';
    
    // Ensure it's not too long (Firestore limit is 1500 bytes, but we'll limit to 500 chars for safety)
    if (cacheKey.length > 500) {
      return cacheKey.substring(0, 500);
    }
    
    return cacheKey;
  }

  /// Get cached album art URL for a track
  static Future<String?> getCachedAlbumArt(String title, String artist) async {
    try {
      final cacheKey = _generateCacheKey(title, artist);
      final doc = await FirebaseFirestore.instance
          .collection(_collectionName)
          .doc(cacheKey)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        // Check TTL — treat entry as stale if older than _cacheTtl
        final cachedAt = data['cachedAt'] as Timestamp?;
        if (cachedAt != null) {
          final age = DateTime.now().difference(cachedAt.toDate());
          if (age > _cacheTtl) {
            debugPrint('Cache expired for $title by $artist (${age.inDays}d old)');
            return null; // stale — caller will re-fetch
          }
        }
        final imageUrl = data['imageUrl'] as String?;
        if (imageUrl != null && imageUrl.isNotEmpty) {
          debugPrint('Found cached album art for $title by $artist');
          return imageUrl;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting cached album art: $e');
      return null;
    }
  }

  /// Cache album art URL for a track
  static Future<void> cacheAlbumArt(
    String title,
    String artist,
    String imageUrl,
  ) async {
    if (imageUrl.isEmpty) return; // Don't cache empty URLs
    
    try {
      final cacheKey = _generateCacheKey(title, artist);
      await FirebaseFirestore.instance
          .collection(_collectionName)
          .doc(cacheKey)
          .set({
        'title': title,
        'artist': artist,
        'imageUrl': imageUrl,
        'cachedAt': FieldValue.serverTimestamp(),
        'source': 'spotify', // Track where image came from
      }, SetOptions(merge: true));
      
      debugPrint('Cached album art for $title by $artist');
    } catch (e) {
      debugPrint('Error caching album art: $e');
    }
  }

  /// Get album art with caching: checks cache first, then fetches from API if needed
  static Future<String?> getAlbumArtWithCache(
    String title,
    String artist,
    Future<String?> Function() fetchFunction,
  ) async {
    // 1. Check cache first
    final cachedImageUrl = await getCachedAlbumArt(title, artist);
    if (cachedImageUrl != null && cachedImageUrl.isNotEmpty) {
      return cachedImageUrl;
    }

    // 2. Fetch from API
    try {
      final imageUrl = await fetchFunction();
      
      if (imageUrl != null && imageUrl.isNotEmpty) {
        // 3. Cache the result for future use
        await cacheAlbumArt(title, artist, imageUrl);
        return imageUrl;
      }
    } catch (e) {
      debugPrint('Error fetching album art: $e');
    }

    // 4. Return null if nothing found
    return null;
  }

  /// Clear cache for a specific track (useful if image needs to be refreshed)
  static Future<void> clearCache(String title, String artist) async {
    try {
      final cacheKey = _generateCacheKey(title, artist);
      await FirebaseFirestore.instance
          .collection(_collectionName)
          .doc(cacheKey)
          .delete();
      debugPrint('Cleared album art cache for $title by $artist');
    } catch (e) {
      debugPrint('Error clearing album art cache: $e');
    }
  }
}
