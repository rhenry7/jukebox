import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test_project/MusicPreferences/spotifyRecommendations/helpers/tokenManager.dart';
import 'package:flutter_test_project/api_key.dart';
import 'package:http/http.dart' as http;

class MusicRecommendationService {
  static Future<List<String>> getRecommendations(
      Map<String, dynamic> preferencesJson) async {
    final recentRecommneded = [];
    final prompt = '''
You are a music recommendation engine. 
Based on the following user profile JSON, suggest a list of 10 songs or albums that the user would love. 
Avoid genres they dislike. 
Prioritize genres with high weights.
Respond with only a list of song titles and artists, no commentary.

exclude any songs that are in this list of recent recommendations:
${recentRecommneded.join('\n')}


randomize the order of the recommendations, but ensure that the most relevant songs are at the top of the list.
randomize the suggestions, but ensure that the most relevant songs are at the top of the list.

User Profile JSON:
${jsonEncode(preferencesJson)}

format:
1. SongTitle - ArtistName
''';

    final model =
        FirebaseAI.vertexAI().generativeModel(model: 'gemini-2.0-flash');
    final ammendedPrompt = [Content.text(prompt)];

    final response = await model.generateContent(ammendedPrompt);
    response.text?.split('\n').forEach((element) {
      if (element.isNotEmpty) {
        print(element);
      }
    });
    if (response.text == null) {
      throw Exception('No response from the AI model');
    }
    recentRecommneded.addAll(
        response.text?.split('\n').where((s) => s.isNotEmpty).toList() ?? []);

    print(response.text);
    return response.text?.split('\n').where((s) => s.isNotEmpty).toList() ?? [];
  }
}

class EnrichedTrack {
  final String name;
  final String artist;
  final String imageUrl;
  final String albumUrl;
  final String? albumName;

  EnrichedTrack({
    required this.name,
    required this.artist,
    required this.imageUrl,
    required this.albumUrl,
    this.albumName,
  });

  factory EnrichedTrack.fromSpotifyJson(Map<String, dynamic> preferencesJson) {
    final track = preferencesJson['tracks']['items'][0];
    final album = track['album'];

    return EnrichedTrack(
      name: track['name'],
      artist: track['artists'][0]['name'],
      imageUrl: album['images'].isNotEmpty ? album['images'][0]['url'] : '',
      albumUrl: track['external_urls']['spotify'],
      albumName: album['name'],
    );
  }

  factory EnrichedTrack.fallback(String title, String artist) {
    return EnrichedTrack(
      name: title,
      artist: artist,
      imageUrl: '',
      albumUrl: '',
    );
  }
}

class SpotifyEnrichmentService {
  static const String _baseUrl = 'https://api.spotify.com/v1';

  static Future<String> _getAccessToken() async {
    final credentials = base64Encode(utf8.encode('$clientId:$clientSecret'));

    final uri = Uri.https('accounts.spotify.com', '/api/token');

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Basic $credentials',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'grant_type': 'client_credentials',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final token = SpotifyToken.fromJson(data);
      return token.accessToken;
    } else {
      throw Exception('Failed to get access token: ${response.body}');
    }
  }

  static Future<EnrichedTrack?> _searchTrack(
    String query,
  ) async {
    print('Searcing for track: $query');
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = '$_baseUrl/search?q=$encodedQuery&type=track&limit=1';
      final accessToken = await _getAccessToken();

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['tracks']['items'].isNotEmpty) {
          return EnrichedTrack.fromSpotifyJson(data);
        }
      }

      return null;
    } catch (e) {
      print('Error searching track: $e');
      return null;
    }
  }

  static Map<String, String> _parseRecommendation(String recommendation) {
    String title = '';
    String artist = '';

    if (recommendation.contains(' - ')) {
      final parts = recommendation.split(' - ');
      title = parts[0].trim();
      artist = parts.length > 1
          ? parts.sublist(1).join(' - ').trim()
          : 'Unknown Artist';
    } else if (recommendation.contains(' by ')) {
      final parts = recommendation.split(' by ');
      title = parts[0].trim();
      artist = parts.length > 1 ? parts[1].trim() : 'Unknown Artist';
    } else {
      // If no clear separator, assume the whole string is the title
      title = recommendation.trim();
      artist = 'Unknown Artist';
    }

    return {'title': title, 'artist': artist};
  }

  static Future<List<EnrichedTrack>> enrichRecommendations(
      List<String> recommendations) async {
    try {
      final accessToken = await _getAccessToken();
      final enrichedTracks = <EnrichedTrack>[];

      for (final recommendation in recommendations) {
        final parsed = _parseRecommendation(recommendation);
        final title = parsed['title']!;
        final artist = parsed['artist']!;

        final searchQuery = '$title $artist';

        final spotifyTrack = await _searchTrack(searchQuery);

        if (spotifyTrack != null) {
          enrichedTracks.add(spotifyTrack);
        } else {
          enrichedTracks.add(EnrichedTrack.fallback(title, artist));
        }

        await Future.delayed(const Duration(milliseconds: 100));
      }

      return enrichedTracks;
    } catch (e) {
      print('Error enriching recommendations: $e');

      // Return fallback tracks if everything fails
      return recommendations.map((rec) {
        final parsed = _parseRecommendation(rec);
        return EnrichedTrack.fallback(parsed['title']!, parsed['artist']!);
      }).toList();
    }
  }

  static Future<EnrichedTrack> enrichSingleRecommendation(
      String recommendation) async {
    try {
      final accessToken = await _getAccessToken();
      final parsed = _parseRecommendation(recommendation);
      final title = parsed['title']!;
      final artist = parsed['artist']!;

      final searchQuery = '$title $artist';
      final spotifyTrack = await _searchTrack(searchQuery);

      return spotifyTrack ?? EnrichedTrack.fallback(title, artist);
    } catch (e) {
      print('Error enriching single recommendation: $e');
      final parsed = _parseRecommendation(recommendation);
      return EnrichedTrack.fallback(parsed['title']!, parsed['artist']!);
    }
  }
}

class UpdatedRecommendationService {
  static Future<List<EnrichedTrack>> getEnrichedRecommendations(
      Map<String, dynamic> preferencesJson) async {
    final rawRecommendations =
        await MusicRecommendationService.getRecommendations(preferencesJson);

    final enrichedTracks = await SpotifyEnrichmentService.enrichRecommendations(
        rawRecommendations);

    return enrichedTracks;
  }
}

