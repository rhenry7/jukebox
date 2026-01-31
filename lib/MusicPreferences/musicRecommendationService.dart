import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test_project/Api/api_key.dart';
import 'package:flutter_test_project/models/enhanced_user_preferences.dart';
import 'package:flutter_test_project/models/music_recommendation.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/utils/reviews/review_helpers.dart';
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

  static Future<List<MusicRecommendation>> getRecommendations(
    EnhancedUserPreferences preferencesJson, {
    int count = 10,
    List<String>? excludeSongs,
  }) async {
    try {
      final userId = FirebaseAuth.instance.currentUser != null
          ? FirebaseAuth.instance.currentUser!.uid
          : "";
      final List<Review> reviews = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reviews')
          .orderBy('date', descending: true)
          .get()
          .then((snapshot) => snapshot.docs
              .map((doc) => Review.fromFirestore(doc.data()))
              .toList());

      List<dynamic> reviewList = [];
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

      final prompt =
          _buildPrompt(preferencesJson, count, excludeSongs, reviewList);
      print('prompt: $prompt');
      final response = await _makeApiRequest(prompt);

      final EnhancedUserPreferences preferences =
          EnhancedUserPreferences.fromJson(doc.data()!);
      final albums = _parseRecommendations(response);
      
      // Start fetching album images in the background (non-blocking)
      _fetchAlbumImagesInBackground(albums);

      return removeDuplication(albums, preferences);
    } catch (e) {
      throw MusicRecommendationException('Failed to get recommendations: $e');
    }
  }

  static String _buildPrompt(EnhancedUserPreferences preferences, int count,
      List<String>? excludeSongs, List<dynamic> reviews) {
    final excludeList = [
      ..._recentRecommendations,
      ...excludeSongs ?? [],
    ];
    print('reviews: ${jsonEncode(reviews)}');

    return '''



```json
- give ten songs to recommend to the user based on preferences
using saved tracks: ${jsonEncode(preferences.savedTracks).split(', ')}
using moodPreferences: ${jsonEncode(preferences.moodPreferences).split(', ')}
using dislikedTracks: ${jsonEncode(preferences.dislikedTracks).split(', ')}
using dislikedTracks: ${jsonEncode(preferences.tempoPreferences).split(', ')}
using genreWeights, songs that combine elements of genres based on the user's preferences: ${jsonEncode(preferences.genreWeights).split(', ')}

using user reviews: ${jsonEncode(reviews.take(5).join(", "))}
- Prioritize recommendations based on genre weights, mood preferences and tempo preferences 
- Include some variety and surprises
- Return ONLY valid JSON, no commentary
- Consider the songs/tracks liked, the songs recently recommended to not be repetitive of the same tracks within a short space of time
- Consider the songs/tracks disliked to not recommend the user songs they have mentioned they dislike or liked
- exclude recommendations in the savedTracksOrAlbum array

```json
User Profile: ${jsonEncode(preferences)}
Return JSON array:
[{"song":"Title","artist":"Artist","album":"Album","imageUrl":"","genres":["Genre1"]}]''';
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
              'You are a music recommendation engine. Respond only with valid JSON arrays. Consider preferences, recent user reviews. Only return songs that exist on Spotify. Do not invent song or artist names'
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
            for (var page in searchResults) {
              if (page.items != null) {
                for (var item in page.items!) {
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

              for (var page in albumSearchResults) {
                if (page.items != null) {
                  for (var item in page.items!) {
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
      for (var page in searchResults) {
        if (page.items != null) {
          for (var item in page.items!) {
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

        for (var page in albumSearchResults) {
          if (page.items != null) {
            for (var item in page.items!) {
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
