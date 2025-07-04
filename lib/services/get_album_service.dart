import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:spotify/spotify.dart';

class MusicBrainzAlbum {
  final String id;
  final String title;
  final String artist;
  String? imageURL;
  final DateTime? releaseDate;
  final List<String>? genres;

  MusicBrainzAlbum({
    required this.id,
    required this.title,
    required this.artist,
    this.imageURL,
    this.releaseDate,
    this.genres = const [],
  });

  @override
  String toString() {
    return 'MusicBrainzAlbum(title: $title, artist: $artist, releaseDate: $releaseDate, genres: $genres)';
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
      'genres': genres,
    };
  }
}

class MusicBrainzService {
  static const String _baseUrl = 'https://musicbrainz.org/ws/2';
  static DateTime? _lastRequest;

  static Future<void> _rateLimit() async {
    if (_lastRequest != null) {
      final diff = DateTime.now().difference(_lastRequest!);
      if (diff.inMilliseconds < 1000) {
        await Future.delayed(
            Duration(milliseconds: 1000 - diff.inMilliseconds));
      }
    }
    _lastRequest = DateTime.now();
  }

  static Future<List<MusicBrainzAlbum>> searchAlbums({
    required int year,
    int? month = 6,
    String? genre = "hip hop",
    int limit = 10,
  }) async {
    await _rateLimit();
    print("in search albums");

    String query = '$year';
    if (month != null) {
      query += '-${month.toString().padLeft(2, '0')}';
    }
    if (genre != null) {
      query += ' AND tag:$genre';
    }

    final url = Uri.parse('$_baseUrl/release-group').replace(queryParameters: {
      'query': query,
      'limit': limit.toString(),
      'fmt': 'json',
      'inc': 'artist-credits+tags',
    });

    final response = await http.get(url, headers: {
      'User-Agent': 'jukeboxd/1.0 (ramoneh94@gmail.com)',
    });
    print('Status code: ${response.statusCode}');
    try {
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<MusicBrainzAlbum> albums = [];

        for (var item in data['release-groups'] ?? []) {
          final album = _parseAlbum(item);
          if (album != null) albums.add(album);
        }

        return albums;
      }
      return [];
    } catch (e) {
      print('Error: $e');
      return [];
    }
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
            .where((tag) => _isGenre(tag))
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
    });

    if (response.statusCode == 200) {
      try {
        final data = json.decode(response.body);
        final items = data['release-groups'] as List?;
        if (items != null && items.isNotEmpty) {
          return _parseAlbum(items.first);
        }
      } catch (e) {
        print('Parsing error: $e');
      }
    } else {
      //print('MusicBrainz search failed: ${response.statusCode}');
    }

    return null;
  }

  Future<List<MusicBrainzAlbum>> enrichAlbumsWithMusicBrainz(
      List<Album> spotifyAlbums) async {
    List<MusicBrainzAlbum> enriched = [];

    for (final album in spotifyAlbums) {
      final title = album.name;
      final imageURL = album.images![0].url;
      final artist =
          album.artists!.isNotEmpty ? album.artists!.first.name.toString() : '';

      if (title!.isNotEmpty && artist.isNotEmpty) {
        final mbAlbum =
            await MusicBrainzService.searchByTitleAndArtist(title, artist);
        mbAlbum?.imageURL = imageURL;
        // print(imageURL);
        // print(mbAlbum);
        if (mbAlbum != null) {
          enriched.add(mbAlbum);
        } else {
          print('No match found for "$title" by $artist');
        }
      }
    }
    //print(enriched.toString());
    return enriched;
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
