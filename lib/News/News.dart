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
  static String get _apiKey => newsAPIKey;
  static const String _baseUrl = 'https://newsapi.org/v2/everything';

  /// Generate personalized keywords based on user preferences
  static List<String> generatePersonalizedKeywords({
    List<String>? favoriteGenres,
    List<String>? favoriteArtists,
  }) {
    List<String> keywords = [];
    
    // Base music news keywords (always included)
    keywords.addAll([
      'music news',
      'music industry',
      'new album release',
      'music festival',
      'music award',
    ]);
    
    // Add favorite genres
    if (favoriteGenres != null && favoriteGenres.isNotEmpty) {
      for (var genre in favoriteGenres.take(5)) { // Limit to top 5 genres
        keywords.add('$genre music');
        keywords.add('$genre artist');
        keywords.add('$genre album');
      }
    }
    
    // Add favorite artists (limit to top 3 to avoid query being too long)
    if (favoriteArtists != null && favoriteArtists.isNotEmpty) {
      for (var artist in favoriteArtists.take(3)) {
        keywords.add(artist);
      }
    }
    
    return keywords;
  }

  /// Fetch articles with personalized keywords based on user preferences
  Future<List<MusicNewsArticle>> fetchPersonalizedArticles({
    List<String>? favoriteGenres,
    List<String>? favoriteArtists,
    int maxResults = 20,
  }) async {
    final keywords = generatePersonalizedKeywords(
      favoriteGenres: favoriteGenres,
      favoriteArtists: favoriteArtists,
    );
    return fetchArticles(keywords, maxResults: maxResults);
  }

  /// Fetch articles with custom keywords
  Future<List<MusicNewsArticle>> fetchArticles(
    List<String> keywords, {
    int maxResults = 20,
  }) async {
    // Build query with music-focused terms
    final musicTerms = [
      'music',
      'album',
      'artist',
      'song',
      'concert',
      'tour',
      'festival',
    ];
    
    // Combine user keywords with music terms for better filtering
    final queryTerms = <String>[];
    
    // Add music context to each keyword
    for (var keyword in keywords) {
      // If keyword already contains music-related terms, use as-is
      if (keyword.toLowerCase().contains('music') ||
          keyword.toLowerCase().contains('album') ||
          keyword.toLowerCase().contains('artist') ||
          keyword.toLowerCase().contains('song')) {
        queryTerms.add('"$keyword"');
      } else {
        // Add music context
        queryTerms.add('"$keyword" AND (music OR album OR artist)');
      }
    }
    
    // Build final query - use OR for keywords, but ensure music relevance
    final query = queryTerms.join(' OR ');
    
    // Add date filter to get recent articles (last 30 days)
    final fromDate = DateTime.now().subtract(const Duration(days: 30));
    final fromDateStr = fromDate.toIso8601String().split('T')[0];
    
    final uri = Uri.parse(
      '$_baseUrl?q=$query&language=en&sortBy=publishedAt&from=$fromDateStr&pageSize=$maxResults&apiKey=$_apiKey',
    );

    print('📰 [NEWS] Fetching articles with query: $query');
    
    try {
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List articles = data['articles'] ?? [];
        
        print('📰 [NEWS] Found ${articles.length} articles');
        
        // Filter out articles that are clearly not music-related
        final musicArticles = articles
            .map((articleJson) => MusicNewsArticle.fromJson(articleJson))
            .where((article) => _isMusicRelated(article))
            .toList();
        
        print('📰 [NEWS] Filtered to ${musicArticles.length} music-related articles');
        
        return musicArticles;
      } else {
        print('❌ [NEWS] API Error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load news articles: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [NEWS] Error fetching articles: $e');
      rethrow;
    }
  }

  /// Check if an article is music-related based on title and description
  bool _isMusicRelated(MusicNewsArticle article) {
    final musicKeywords = [
      'music', 'album', 'artist', 'song', 'track', 'single', 'ep',
      'concert', 'tour', 'festival', 'award', 'grammy', 'billboard',
      'spotify', 'streaming', 'release', 'debut', 'collaboration',
      'genre', 'hip hop', 'rap', 'rock', 'pop', 'jazz', 'electronic',
      'indie', 'country', 'r&b', 'soul', 'folk', 'metal', 'punk',
    ];
    
    final text = '${article.title} ${article.description}'.toLowerCase();
    
    // Article is music-related if it contains at least 2 music keywords
    final matchCount = musicKeywords.where((keyword) => text.contains(keyword)).length;
    return matchCount >= 2;
  }
}
