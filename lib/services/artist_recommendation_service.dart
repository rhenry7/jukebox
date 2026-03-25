import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test_project/Api/api_key.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:http/http.dart' as http;

/// A recommended artist returned by the AI with an image resolved via MusicBrainz.
class RecommendedArtist {
  final String name;
  final String reason;
  final List<String> genres;
  String imageUrl;

  RecommendedArtist({
    required this.name,
    required this.reason,
    required this.genres,
    this.imageUrl = '',
  });
}

/// Uses OpenAI to recommend artists based on the user's review history,
/// then resolves artist images via MusicBrainz + Cover Art Archive.
class ArtistRecommendationService {
  static const _openAiEndpoint = 'https://api.openai.com/v1/chat/completions';
  static const _model = 'gpt-4o-mini';
  static const _timeout = Duration(seconds: 30);
  static const _mbBaseUrl = 'https://musicbrainz.org/ws/2';
  static const _coverArtBaseUrl = 'https://coverartarchive.org';
  static const _httpTimeout = Duration(seconds: 15);

  // In-memory cache keyed by userId
  static final Map<String, _CachedResult> _cache = {};
  static const _cacheTtl = Duration(minutes: 15);

  /// Get AI-powered artist recommendations for a user.
  ///
  /// 1. Reads the user's own reviews from Firestore.
  /// 2. Sends them to OpenAI to get recommended artist names + genres.
  /// 3. Resolves artist images via MusicBrainz artist search + Cover Art Archive.
  /// 4. Caches the result in memory for [_cacheTtl].
  static Future<List<RecommendedArtist>> getRecommendedArtists(
    String userId,
  ) async {
    // Return cached results if fresh
    final cached = _cache[userId];
    if (cached != null && !cached.isExpired) {
      debugPrint('[ARTIST_REC] Returning ${cached.results.length} cached artists');
      return cached.results;
    }

    // 1. Fetch user's own reviews
    final userReviews = await _fetchUserReviews(userId);
    if (userReviews.isEmpty) {
      debugPrint('[ARTIST_REC] No user reviews — skipping');
      return [];
    }

    // 2. Ask OpenAI for artist recommendations
    List<RecommendedArtist> artists;
    if (openAIKey.isNotEmpty) {
      try {
        artists = await _getAIRecommendations(userReviews);
        debugPrint('[ARTIST_REC] AI returned ${artists.length} artists');
      } catch (e) {
        debugPrint('[ARTIST_REC] AI failed, using fallback: $e');
        artists = _fallbackFromReviews(userReviews);
      }
    } else {
      debugPrint('[ARTIST_REC] No OpenAI key, using fallback');
      artists = _fallbackFromReviews(userReviews);
    }

    if (artists.isEmpty) return [];

    // 3. Resolve images via MusicBrainz in parallel (with rate-limit friendly batching)
    await _resolveArtistImages(artists);

    _cache[userId] = _CachedResult(artists);
    return artists;
  }

  /// Clear cache for a user (used before force refresh).
  static void clearCache([String? userId]) {
    if (userId != null) {
      _cache.remove(userId);
    } else {
      _cache.clear();
    }
  }

  // ---------------------------------------------------------------------------
  // OpenAI
  // ---------------------------------------------------------------------------

  static Future<List<RecommendedArtist>> _getAIRecommendations(
    List<Review> userReviews,
  ) async {
    final reviewsSummary = userReviews.take(20).map((r) {
      final genres = (r.genres ?? []).join(', ');
      return '- "${r.title}" by ${r.artist} (${r.score}/5) [${genres.isNotEmpty ? genres : "unknown genre"}]';
    }).join('\n');

    final prompt = '''
Based on the following user's music review history, recommend 15 artists they would enjoy but have NOT already reviewed. Focus on similar genres, styles, and vibes.

USER'S REVIEWS:
$reviewsSummary

TASK: Return a JSON array of objects with keys "name" (artist name), "reason" (1 short sentence why), and "genres" (array of 1-3 genre strings). Return ONLY valid JSON, no markdown or explanation.
Example: [{"name":"Artist Name","reason":"Similar vibe to X","genres":["rock","indie"]}]
''';

    final response = await http
        .post(
          Uri.parse(_openAiEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $openAIKey',
          },
          body: jsonEncode({
            'model': _model,
            'temperature': 0.8,
            'max_tokens': 1500,
            'messages': [
              {
                'role': 'system',
                'content':
                    'You are a music recommendation engine. Given a user\'s review history, return a JSON array of artist recommendations. Return ONLY valid JSON, no other text.',
              },
              {'role': 'user', 'content': prompt},
            ],
          }),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('OpenAI error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final content = (data['choices'] as List?)
        ?.firstOrNull?['message']?['content']
        ?.toString()
        .trim();
    if (content == null || content.isEmpty) return [];

    return _parseArtistsResponse(content);
  }

  static List<RecommendedArtist> _parseArtistsResponse(String content) {
    try {
      var clean = content
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      final start = clean.indexOf('[');
      final end = clean.lastIndexOf(']');
      if (start >= 0 && end > start) {
        clean = clean.substring(start, end + 1);
      }

      final decoded = jsonDecode(clean) as List;
      return decoded.map((item) {
        final map = item as Map<String, dynamic>;
        return RecommendedArtist(
          name: (map['name'] as String? ?? '').trim(),
          reason: (map['reason'] as String? ?? '').trim(),
          genres: (map['genres'] as List?)
                  ?.map((g) => g.toString().trim())
                  .where((g) => g.isNotEmpty)
                  .toList() ??
              [],
        );
      }).where((a) => a.name.isNotEmpty).take(15).toList();
    } catch (e) {
      debugPrint('[ARTIST_REC] Failed to parse AI response: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // MusicBrainz image resolution
  // ---------------------------------------------------------------------------

  /// For each artist, search MusicBrainz for the artist MBID, then get the
  /// cover art of their most popular release via Cover Art Archive.
  static Future<void> _resolveArtistImages(
    List<RecommendedArtist> artists,
  ) async {
    // Process in batches of 3 to stay within MusicBrainz rate limits
    for (var i = 0; i < artists.length; i += 3) {
      final batch = artists.skip(i).take(3);
      await Future.wait(batch.map(_resolveOneImage));
      // Respect MusicBrainz 1 req/sec rate limit (3 parallel then wait)
      if (i + 3 < artists.length) {
        await Future.delayed(const Duration(milliseconds: 1200));
      }
    }
  }

  static Future<void> _resolveOneImage(RecommendedArtist artist) async {
    try {
      // Step 1: Search for artist MBID
      final artistId = await _searchArtistMbid(artist.name);
      if (artistId == null) return;

      // Step 2: Get the artist's release groups (albums) — pick the first one
      final releaseGroupId = await _getTopReleaseGroup(artistId);
      if (releaseGroupId == null) return;

      // Step 3: Get cover art from Cover Art Archive
      final imageUrl = await _getCoverArt(releaseGroupId);
      if (imageUrl != null) {
        artist.imageUrl = imageUrl;
      }
    } catch (e) {
      debugPrint('[ARTIST_REC] Image resolve failed for ${artist.name}: $e');
    }
  }

  /// Search MusicBrainz for an artist by name and return their MBID.
  static Future<String?> _searchArtistMbid(String artistName) async {
    final url = Uri.parse('$_mbBaseUrl/artist').replace(queryParameters: {
      'query': 'artist:"$artistName"',
      'fmt': 'json',
      'limit': '1',
    });

    final response = await http.get(url, headers: {
      'User-Agent': 'jukeboxd/1.0 (ramoneh94@gmail.com)',
    }).timeout(_httpTimeout);

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body);
    final artists = data['artists'] as List?;
    if (artists == null || artists.isEmpty) return null;

    return artists.first['id'] as String?;
  }

  /// Get the top release-group (album) MBID for an artist.
  static Future<String?> _getTopReleaseGroup(String artistMbid) async {
    final url =
        Uri.parse('$_mbBaseUrl/release-group').replace(queryParameters: {
      'artist': artistMbid,
      'type': 'album',
      'fmt': 'json',
      'limit': '1',
      'sort': '-first-release-date',
    });

    final response = await http.get(url, headers: {
      'User-Agent': 'jukeboxd/1.0 (ramoneh94@gmail.com)',
    }).timeout(_httpTimeout);

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body);
    final groups = data['release-groups'] as List?;
    if (groups == null || groups.isEmpty) return null;

    return groups.first['id'] as String?;
  }

  /// Fetch the front cover image URL from the Cover Art Archive.
  static Future<String?> _getCoverArt(String releaseGroupId) async {
    // Cover Art Archive supports release-group lookups
    final url =
        Uri.parse('$_coverArtBaseUrl/release-group/$releaseGroupId');

    try {
      final response = await http.get(url, headers: {
        'User-Agent': 'jukeboxd/1.0 (ramoneh94@gmail.com)',
        'Accept': 'application/json',
      }).timeout(_httpTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final images = data['images'] as List?;
        if (images != null && images.isNotEmpty) {
          // Prefer the front image; fall back to the first image
          for (final img in images) {
            if (img['front'] == true) {
              return img['image'] as String?;
            }
          }
          return images.first['image'] as String?;
        }
      }
    } catch (e) {
      debugPrint('[ARTIST_REC] Cover Art Archive error: $e');
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Fallback (no OpenAI key)
  // ---------------------------------------------------------------------------

  /// Simple fallback: extract unique artists the user has reviewed with high
  /// scores and return them. Not ideal but keeps the section functional.
  static List<RecommendedArtist> _fallbackFromReviews(List<Review> reviews) {
    final seen = <String>{};
    final result = <RecommendedArtist>[];

    // Sort by score descending so top-rated artists appear first
    final sorted = List<Review>.from(reviews)
      ..sort((a, b) => b.score.compareTo(a.score));

    for (final r in sorted) {
      final key = r.artist.trim().toLowerCase();
      if (seen.add(key)) {
        result.add(RecommendedArtist(
          name: r.artist,
          reason: 'Based on your reviews',
          genres: r.genres ?? [],
          imageUrl: r.albumImageUrl ?? '',
        ));
      }
      if (result.length >= 15) break;
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Firestore helpers
  // ---------------------------------------------------------------------------

  static Future<List<Review>> _fetchUserReviews(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reviews')
          .orderBy('date', descending: true)
          .limit(30)
          .get();

      return snapshot.docs
          .map((doc) => Review.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('[ARTIST_REC] Error fetching user reviews: $e');
      return [];
    }
  }
}

class _CachedResult {
  final List<RecommendedArtist> results;
  final DateTime _createdAt;

  _CachedResult(this.results) : _createdAt = DateTime.now();

  bool get isExpired =>
      DateTime.now().difference(_createdAt) >
      ArtistRecommendationService._cacheTtl;
}
