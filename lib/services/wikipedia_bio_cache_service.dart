import 'package:cloud_firestore/cloud_firestore.dart';

/// Service to cache Wikipedia artist bios in Firestore to avoid repeated API calls
class WikipediaBioCacheService {
  static const String _collectionName = 'wikipediaBios';
  
  /// Generate a cache key from artist name
  /// Sanitizes to ensure valid Firestore document ID
  static String generateCacheKey(String artistName) {
    // Normalize: lowercase, trim
    final normalized = artistName.toLowerCase().trim();
    
    // Replace invalid Firestore document ID characters
    // Firestore document IDs cannot contain: /, \, ?, #, [, ], *, and cannot be longer than 1500 bytes
    final String sanitized = normalized
        .replaceAll('/', '_')
        .replaceAll('\\', '_')
        .replaceAll('?', '_')
        .replaceAll('#', '_')
        .replaceAll('[', '_')
        .replaceAll(']', '_')
        .replaceAll('*', '_')
        .replaceAll('|', '_')
        .replaceAll(' ', '_'); // Replace spaces with underscores
    
    // Ensure it's not too long (Firestore limit is 1500 bytes, but we'll limit to 500 chars for safety)
    if (sanitized.length > 500) {
      return sanitized.substring(0, 500);
    }
    
    return sanitized;
  }

  /// Get cached Wikipedia bio for an artist
  static Future<String?> getCachedBio(String artistName) async {
    try {
      final cacheKey = generateCacheKey(artistName);
      final doc = await FirebaseFirestore.instance
          .collection(_collectionName)
          .doc(cacheKey)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final bio = data['bio'] as String?;
        if (bio != null && bio.isNotEmpty) {
          print('💾 Found cached Wikipedia bio for: $artistName');
          return bio;
        }
      }
      return null;
    } catch (e) {
      print('⚠️  Error getting cached Wikipedia bio: $e');
      return null;
    }
  }

  /// Cache Wikipedia bio for an artist
  static Future<void> cacheBio(
    String artistName,
    String bio,
  ) async {
    if (bio.isEmpty) return; // Don't cache empty bios
    
    try {
      final cacheKey = generateCacheKey(artistName);
      await FirebaseFirestore.instance
          .collection(_collectionName)
          .doc(cacheKey)
          .set({
        'artistName': artistName,
        'bio': bio,
        'cachedAt': FieldValue.serverTimestamp(),
        'source': 'wikipedia', // Track where bio came from
      }, SetOptions(merge: true));
      
      print('💾 Cached Wikipedia bio for: $artistName');
    } catch (e) {
      print('⚠️  Error caching Wikipedia bio: $e');
    }
  }

  /// Get Wikipedia bio with caching: checks cache first, then fetches from API if needed
  static Future<String?> getBioWithCache(
    String artistName,
    Future<String?> Function() fetchFunction,
  ) async {
    // 1. Check cache first
    final cachedBio = await getCachedBio(artistName);
    if (cachedBio != null && cachedBio.isNotEmpty) {
      return cachedBio;
    }

    // 2. Fetch from API
    try {
      final bio = await fetchFunction();
      
      if (bio != null && bio.isNotEmpty) {
        // 3. Cache the result for future use
        await cacheBio(artistName, bio);
        return bio;
      }
    } catch (e) {
      print('⚠️  Error fetching Wikipedia bio: $e');
    }

    // 4. Return null if nothing found
    return null;
  }

  /// Clear cache for a specific artist (useful if bio needs to be refreshed)
  static Future<void> clearCache(String artistName) async {
    try {
      final cacheKey = generateCacheKey(artistName);
      await FirebaseFirestore.instance
          .collection(_collectionName)
          .doc(cacheKey)
          .delete();
      print('🗑️  Cleared Wikipedia bio cache for: $artistName');
    } catch (e) {
      print('⚠️  Error clearing Wikipedia bio cache: $e');
    }
  }
}
