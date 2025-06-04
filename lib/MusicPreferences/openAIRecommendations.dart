import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test_project/api_key.dart';
import 'package:http/http.dart' as http;

class MusicRecommendationService {
  static Future<List<String>> getRecommendations(
      Map<String, dynamic> preferencesJson) async {
    final prompt = '''
You are a music recommendation engine. 
Based on the following user profile JSON, suggest a list of 10 songs or albums that the user would love. 
Avoid genres they dislike. 
Prioritize genres with high weights.
Respond with only a list of song titles and artists, no commentary.

User Profile JSON:
${jsonEncode(preferencesJson)}
''';

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $openAIKey',
      },
      body: jsonEncode({
        "model": "gpt-3.5-turbo", // or "gpt-4" if you have access
        "messages": [
          {"role": "user", "content": prompt}
        ],
        "temperature": 0.8
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];
      return content
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();
    } else {
      throw Exception(
          "Failed to get recommendations: ${response.statusCode} - ${response.body}");
    }
  }
}
