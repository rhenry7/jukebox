import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// A single release returned by the Discogs database search.
class DiscogsRelease {
  final int id;
  final String title;
  final String artist;
  final int? year;
  final List<String> genres;
  final List<String> styles;
  final double communityRating;
  final int ratingCount;
  final int haveCount;
  final int wantCount;

  DiscogsRelease({
    required this.id,
    required this.title,
    required this.artist,
    required this.year,
    required this.genres,
    required this.styles,
    required this.communityRating,
    required this.ratingCount,
    required this.haveCount,
    required this.wantCount,
  });

  /// Higher = more desired relative to how many people own it (hidden gem signal).
  double get hiddenGemScore => wantCount / (haveCount + 1);

  /// Combined quality + gem score used for sorting candidates.
  /// Community rating is weighted more heavily than scarcity.
  double get candidateScore =>
      (communityRating / 5.0) * 0.7 + (hiddenGemScore.clamp(0, 10) / 10.0) * 0.3;

  factory DiscogsRelease.fromJson(Map<String, dynamic> json) {
    final community = json['community'] as Map<String, dynamic>?;
    final rating = community?['rating'] as Map<String, dynamic>?;

    // Artist is either a top-level string or nested in the title as "Artist - Title"
    String artist = '';
    String title = json['title']?.toString() ?? '';
    if (title.contains(' - ')) {
      final parts = title.split(' - ');
      artist = parts.first.trim();
      title = parts.sublist(1).join(' - ').trim();
    }

    return DiscogsRelease(
      id: _parseInt(json['id']) ?? 0,
      title: title,
      artist: artist,
      year: _parseInt(json['year']),
      genres: _toStringList(json['genre']),
      styles: _toStringList(json['style']),
      communityRating: _parseDouble(rating?['average']) ?? 0.0,
      ratingCount: _parseInt(rating?['count']) ?? 0,
      haveCount: _parseInt(community?['have']) ?? 0,
      wantCount: _parseInt(community?['want']) ?? 0,
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static List<String> _toStringList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }
}

class DiscogsService {
  static const _baseUrl = 'https://api.discogs.com';
  // Discogs requires a descriptive User-Agent — no API key needed for search.
  static const _userAgent = 'CrateBoxd/1.0 (music discovery app)';
  static const _timeout = Duration(seconds: 15);

  /// Search Discogs for releases matching the given styles/genres.
  /// Returns results filtered by minimum community rating and sorted by
  /// candidate score (quality + hidden gem signal).
  static Future<List<DiscogsRelease>> searchByStyles({
    required List<String> styles,
    List<String> genres = const [],
    double minRating = 3.8,
    int minRatingCount = 10,
    int perStyle = 8,
  }) async {
    final results = <DiscogsRelease>[];
    final seen = <int>{};

    // Query each style separately and merge, so niche styles aren't drowned out
    final queries = [
      ...styles.take(4),
      ...genres.take(2),
    ];

    for (final query in queries) {
      try {
        final releases = await _searchDiscogs(style: query, perPage: perStyle * 2);
        for (final r in releases) {
          if (seen.contains(r.id)) continue;
          if (r.communityRating < minRating) continue;
          if (r.ratingCount < minRatingCount) continue;
          seen.add(r.id);
          results.add(r);
        }
      } catch (e) {
        debugPrint('[Discogs] Error searching style "$query": $e');
      }
    }

    // Sort by combined candidate score descending
    results.sort((a, b) => b.candidateScore.compareTo(a.candidateScore));
    return results;
  }

  static Future<List<DiscogsRelease>> _searchDiscogs({
    required String style,
    int perPage = 15,
  }) async {
    final uri = Uri.parse('$_baseUrl/database/search').replace(queryParameters: {
      'style': style,
      'type': 'release',
      'per_page': '$perPage',
      'page': '1',
      'sort': 'want',
      'sort_order': 'desc',
    });

    final response = await http.get(
      uri,
      headers: {'User-Agent': _userAgent},
    ).timeout(_timeout);

    if (response.statusCode != 200) {
      debugPrint('[Discogs] Search failed (${response.statusCode}): ${response.body}');
      return [];
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final results = body['results'] as List<dynamic>? ?? [];
    return results
        .whereType<Map<String, dynamic>>()
        .map(DiscogsRelease.fromJson)
        .toList();
  }

  /// Formats a list of Discogs releases as a compact candidate block
  /// ready to be injected into an AI prompt.
  static String formatCandidatesForPrompt(List<DiscogsRelease> releases) {
    if (releases.isEmpty) return '';
    final lines = releases.take(25).map((r) {
      final styleStr = r.styles.take(3).join(', ');
      final gemNote = r.hiddenGemScore > 3.0 ? ' [cult/underrated]' : '';
      return '• "${r.title}" by ${r.artist} | ${styleStr.isNotEmpty ? styleStr : r.genres.take(2).join(', ')} | ★${r.communityRating.toStringAsFixed(1)} (${r.ratingCount} ratings)$gemNote';
    }).join('\n');
    return lines;
  }
}
