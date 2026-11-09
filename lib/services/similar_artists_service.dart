import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// An artist that sounds like another, from ListenBrainz.
typedef SimilarArtist = ({String mbid, String name, double score});

/// Artists that sound like a given one, by name. Used by onboarding to
/// suggest more artists after each pick.
///
/// The artist's MusicBrainz ID comes from a MusicBrainz search; the similar
/// artists from the `similarArtists/{mbid}` cache that Cloud Functions keeps
/// for reviewed artists (functions/src/musicbrainz.ts), or straight from
/// ListenBrainz when it isn't cached. Both services are free and keyless,
/// and allow calls from the browser.
class SimilarArtistsService {
  static const _mbBase = 'https://musicbrainz.org/ws/2';
  static const _timeout = Duration(seconds: 10);

  /// Must match `SIMILAR_ARTISTS_URL` / `SIMILAR_ARTISTS_ALGORITHM` in
  /// functions/src/musicbrainz.ts.
  static const _similarUrl =
      'https://labs.api.listenbrainz.org/similar-artists/json';
  static const _algorithm =
      'session_based_days_7500_session_300_contribution_5_threshold_10_limit_100_filter_True_skip_30';

  /// MusicBrainz allows about one request a second per client.
  static const Duration _gap = Duration(milliseconds: 1100);
  static DateTime _lastMbRequest = DateTime.fromMillisecondsSinceEpoch(0);

  /// Answers this session, by lowercase name.
  static final Map<String, Future<List<SimilarArtist>>> _memo = {};

  /// Up to [limit] artists that sound like [name], most similar first.
  /// Empty if the artist isn't found or the services can't be reached.
  static Future<List<SimilarArtist>> similarTo(
    String name, {
    int limit = 10,
    FirebaseFirestore? db,
  }) {
    final key = name.trim().toLowerCase();
    if (key.isEmpty) return Future.value(const []);
    return _memo
        .putIfAbsent(key, () => _load(name.trim(), db))
        .then((all) => all.take(limit).toList());
  }

  static Future<List<SimilarArtist>> _load(
    String name,
    FirebaseFirestore? db,
  ) async {
    try {
      final mbid = await _artistMbid(name);
      if (mbid == null) return const [];
      try {
        final cached = await (db ?? FirebaseFirestore.instance)
            .collection('similarArtists')
            .doc(mbid)
            .get();
        final list = parseCachedSimilar(cached.data());
        if (list.isNotEmpty) return list;
      } catch (e) {
        debugPrint('[SIMILAR_ARTISTS] Cache read failed: $e');
      }
      final uri = Uri.parse(_similarUrl).replace(
        queryParameters: {'artist_mbids': mbid, 'algorithm': _algorithm},
      );
      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode != 200) return const [];
      return parseSimilarArtists(jsonDecode(response.body));
    } catch (e) {
      debugPrint('[SIMILAR_ARTISTS] Lookup for "$name" failed: $e');
      _memo.remove(name.trim().toLowerCase())?.ignore(); // retry next time
      return const [];
    }
  }

  static Future<String?> _artistMbid(String name) async {
    final wait = _gap - DateTime.now().difference(_lastMbRequest);
    if (wait > Duration.zero) await Future<void>.delayed(wait);
    _lastMbRequest = DateTime.now();
    final uri = Uri.parse('$_mbBase/artist').replace(
      queryParameters: {
        'query': 'artist:"${name.replaceAll('"', ' ')}"',
        'fmt': 'json',
        'limit': '5',
      },
    );
    final response = await http.get(uri).timeout(_timeout);
    if (response.statusCode != 200) return null;
    final artists = (jsonDecode(response.body) as Map)['artists'] as List?;
    return pickArtistMbid(artists ?? const [], name);
  }

  /// A confident (score ≥ 90), exact-name match's ID. Same rule as
  /// `pickArtist` in functions/src/musicbrainz.ts.
  @visibleForTesting
  static String? pickArtistMbid(List results, String name) {
    final wanted = normName(name);
    for (final a in results) {
      if (a is! Map) continue;
      if (((a['score'] as num?) ?? 0) < 90) continue;
      if (normName(a['name']?.toString() ?? '') == wanted) {
        return a['id'] as String?;
      }
    }
    return null;
  }

  /// Lowercase, no accents or punctuation; "&" reads as "and", for
  /// comparing artist names. Same as `normName` in
  /// functions/src/musicbrainz.ts.
  static String normName(String s) {
    const accents = {
      'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', //
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
      'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', 'ø': 'o',
      'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
      'ñ': 'n', 'ç': 'c', 'ý': 'y', 'ÿ': 'y',
    };
    final lower = s.toLowerCase();
    final plain = StringBuffer();
    for (final ch in lower.split('')) {
      plain.write(accents[ch] ?? ch);
    }
    return plain
        .toString()
        .replaceAll('&', ' and ')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  /// The `similar` list of a `similarArtists` cache doc.
  @visibleForTesting
  static List<SimilarArtist> parseCachedSimilar(Map<String, dynamic>? doc) {
    final similar = doc?['similar'];
    if (similar is! List) return const [];
    return [
      for (final s in similar)
        if (s is Map &&
            s['mbid'] is String &&
            s['name'] is String &&
            s['score'] is num)
          (
            mbid: s['mbid'] as String,
            name: s['name'] as String,
            score: (s['score'] as num).toDouble(),
          ),
    ];
  }

  /// ListenBrainz's response, best first, scores scaled so the best is 1.
  /// Same as `parseSimilarArtists` in functions/src/musicbrainz.ts.
  @visibleForTesting
  static List<SimilarArtist> parseSimilarArtists(Object? body) {
    final rows = <Map>[];
    void walk(Object? x) {
      if (x is List) {
        x.forEach(walk);
      } else if (x is Map &&
          x['artist_mbid'] is String &&
          x['name'] is String) {
        rows.add(x);
      }
    }

    walk(body);
    num score(Map r) => (r['score'] as num?) ?? 0;
    rows.sort((a, b) => score(b).compareTo(score(a)));
    if (rows.isEmpty) return const [];
    final top = score(rows.first) > 0 ? score(rows.first) : 1;
    return [
      for (final r in rows.take(50))
        (
          mbid: r['artist_mbid'] as String,
          name: r['name'] as String,
          score: score(r) / top,
        ),
    ];
  }
}
