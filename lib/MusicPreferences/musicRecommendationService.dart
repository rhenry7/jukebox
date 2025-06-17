import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test_project/models/music_recommendation.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/api_key.dart';
import 'package:http/http.dart' as http;

class MusicRecommendationService {
  static const _openAiEndpoint = 'https://api.openai.com/v1/chat/completions';
  static const _model = 'gpt-3.5-turbo';
  static const _maxRetries = 3;
  static const _timeoutDuration = Duration(seconds: 30);

  // Cache for recent recommendations to avoid duplicates
  static final Set<String> _recentRecommendations = <String>{};
  static const int _maxRecentRecommendations = 50;

  static Future<List<MusicRecommendation>> getRecommendations(
    Map<String, dynamic> preferencesJson, {
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

      final prompt =
          _buildPrompt(preferencesJson, count, excludeSongs, reviewList);
      final response = await _makeApiRequest(prompt);
      return _parseRecommendations(response);
    } catch (e) {
      throw MusicRecommendationException('Failed to get recommendations: $e');
    }
  }

  static String _buildPrompt(Map<String, dynamic> preferences, int count,
      List<String>? excludeSongs, List<dynamic> reviews) {
    final excludeList = [
      ..._recentRecommendations,
      ...excludeSongs ?? [],
    ];
    print('reviews: ${jsonEncode(reviews)}');

    return '''
You are a music recommendation engine. Based on the user profile, suggest $count songs.
- Avoid genres they dislike
- Prioritize high-weighted genres
- Include some variety and surprises
- Return ONLY valid JSON, no commentary

```json
${excludeList.isNotEmpty ? 'Exclude these songs:\n${excludeList.join('\n')}\n' : ''}

:
${reviews.isNotEmpty ? 'Consider the following reviews for context:\n${jsonEncode(reviews)}' : ''}

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
              'You are a music recommendation engine. Respond only with valid JSON arrays.'
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

      final List<dynamic> parsed = jsonDecode(cleanResponse);
      final recommendations = parsed
          .map((item) => MusicRecommendation.fromJson(item))
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
