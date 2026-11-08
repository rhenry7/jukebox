import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// HTTP timeout for MusicBrainz API requests.
const _httpTimeout = Duration(seconds: 15);

class MusicBrainzAlbum {
  final String id;
  final String title;
  final String artist;
  String? imageURL;
  final DateTime? releaseDate;
  final String? country;
  final List<String>? genres;

  MusicBrainzAlbum({
    required this.id,
    required this.title,
    required this.artist,
    this.imageURL,
    this.releaseDate,
    this.country,
    this.genres = const [],
  });

  @override
  String toString() {
    return 'MusicBrainzAlbum(title: $title, artist: $artist, releaseDate: $releaseDate, country: $country, genres: $genres)';
  }

// todo: use package to make this portion easier
  factory MusicBrainzAlbum.fromJson(Map<String, dynamic> json) {
    return MusicBrainzAlbum(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      imageURL: json['imageURL'] as String?,
      releaseDate: json['releaseDate'] != null
          ? DateTime.tryParse(json['releaseDate'])
          : null,
      country: json['country'] as String?,
      genres:
          (json['genres'] as List<dynamic>?)?.map((e) => e as String).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'imageURL': imageURL,
      'releaseDate': releaseDate?.toIso8601String(),
      'country': country,
      'genres': genres,
    };
  }
}

class MusicBrainzService {
  static const String _baseUrl = 'https://musicbrainz.org/ws/2';

  /// Queue-based rate limiter: ensures only 1 request per second globally.
  static final List<Completer<void>> _requestQueue = [];
  static bool _processing = false;

  static Future<void> _rateLimit() async {
    final completer = Completer<void>();
    _requestQueue.add(completer);
    if (!_processing) {
      _processQueue();
    }
    return completer.future;
  }

  static Future<void> _processQueue() async {
    _processing = true;
    while (_requestQueue.isNotEmpty) {
      final next = _requestQueue.removeAt(0);
      next.complete();
      // Wait 1 second between requests to respect MusicBrainz rate limit.
      await Future.delayed(const Duration(milliseconds: 1100));
    }
    _processing = false;
  }

  static MusicBrainzAlbum? _parseAlbum(Map<String, dynamic> data) {
    final id = data['id'] as String?;
    if (id == null) return null;

    final title = data['title'] as String? ?? 'Unknown';
    final artistCredits = data['artist-credit'] as List?;
    final artist = artistCredits?.isNotEmpty == true
        ? artistCredits!.first['name'] as String? ?? 'Unknown'
        : 'Unknown';

    DateTime? releaseDate;
    final dateStr = data['first-release-date'] as String?;
    if (dateStr != null && dateStr.length >= 4) {
      try {
        releaseDate = DateTime.parse(dateStr);
      } catch (_) {
        final year = int.tryParse(dateStr.substring(0, 4));
        if (year != null) releaseDate = DateTime(year);
      }
    }

    final tags = data['tags'] as List?;
    final genres = tags
            ?.map((tag) => tag['name'] as String)
            .where(_isGenre)
            .toList() ??
        <String>[];

    return MusicBrainzAlbum(
      id: id,
      title: title,
      artist: artist,
      releaseDate: releaseDate,
      genres: genres,
    );
  }

  static Future<MusicBrainzAlbum?> searchByTitleAndArtist(
      String title, String artist) async {
    await _rateLimit();

    final query = 'release:$title AND artist:$artist';

    final url = Uri.parse('$_baseUrl/release-group').replace(queryParameters: {
      'query': query,
      'fmt': 'json',
      'limit': '1',
      'inc': 'artist-credits+tags',
    });

    final response = await http.get(url, headers: {
      'User-Agent': 'jukeboxd/1.0 (ramoneh94@gmail.com)',
    }).timeout(_httpTimeout);

    if (response.statusCode == 200) {
      try {
        final data = json.decode(response.body);
        final items = data['release-groups'] as List?;
        if (items != null && items.isNotEmpty) {
          return _parseAlbum(items.first);
        }
      } catch (e) {
        debugPrint('Parsing error: $e');
      }
    } else {
      //debugPrint('MusicBrainz search failed: ${response.statusCode}');
    }

    return null;
  }

  static bool _isGenre(String tag) {
    final genreWords = [
      'rock',
      'pop',
      'jazz',
      'electronic',
      'hip hop',
      'metal',
      'folk',
      'blues'
    ];
    return genreWords.any((genre) => tag.toLowerCase().contains(genre));
  }
}
