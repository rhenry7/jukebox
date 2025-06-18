import 'dart:convert';
import 'package:flutter_test_project/Api/api_key.dart';
import 'package:http/http.dart' as http;

/// -------- MODEL --------
class MusicNewsArticle {
  final String title;
  final String description;
  final String url;
  final String imageUrl;

  MusicNewsArticle({
    required this.title,
    required this.description,
    required this.url,
    required this.imageUrl,
  });

  factory MusicNewsArticle.fromJson(Map<String, dynamic> json) {
    return MusicNewsArticle(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      url: json['url'] ?? '',
      imageUrl: json['urlToImage'] ?? '',
    );
  }
}

/// -------- SERVICE --------
class NewsApiService {
  static const String _apiKey = newsAPIKey;
  static const String _baseUrl = 'https://newsapi.org/v2/everything';

  Future<List<MusicNewsArticle>> fetchArticles(List<String> keywords) async {
    final query = keywords.join(' OR ');
    final uri = Uri.parse(
        '$_baseUrl?q=$query&language=en&sortBy=publishedAt&apiKey=$_apiKey');

    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List articles = data['articles'];
      return articles
          .map((articleJson) => MusicNewsArticle.fromJson(articleJson))
          .toList();
    } else {
      throw Exception('Failed to load news articles');
    }
  }
}
