import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../providers/tag_reviews_provider.dart' show normalizeTag;
import 'genre_cache_service.dart';

/// Tag suggestions for the review form, from MusicBrainz: the song's own tags
/// first, then its album's, then the artist's, best first. Cached per song
/// in `trackGenres/{song}` (field `suggestedTags`), so each song is looked
/// up once for everyone.
///
/// Separate from the genres cards show ([GenreCacheService]), which keep
/// only a few broad genres; suggestions keep niche ones like darkwave.
class TagSuggestionService {
  static const _base = 'https://musicbrainz.org/ws/2';
  static const _timeout = Duration(seconds: 10);

  /// How long to keep retrying MusicBrainz when it's busy (it often answers
  /// 503 "slow down") before giving up. Stays under [suggestionTimeout].
  static const Duration retryFor = Duration(seconds: 25);

  /// How many tags are kept per song.
  static const int keep = 8;

  /// How long cached suggestions are used before looking again.
  static const Duration _fresh = Duration(days: 30);

  /// How long a cached "no tags found" is trusted: songs pick up tags over
  /// time, so look again sooner.
  static const Duration _freshEmpty = Duration(days: 1);

  /// MusicBrainz allows about one request a second per client.
  static const Duration _gap = Duration(milliseconds: 1100);
  static DateTime _lastRequest = DateTime.fromMillisecondsSinceEpoch(0);

  /// Suggested tags for [title] by [artist]: from the cache if fresh,
  /// otherwise from MusicBrainz (and then cached). Empty if nothing useful is
  /// found or MusicBrainz can't be reached.
  static Future<List<String>> forTrack(
    String title,
    String artist, {
    FirebaseFirestore? db,
  }) async {
    if (title.trim().isEmpty || artist.trim().isEmpty) return const [];
    final firestore = db ?? FirebaseFirestore.instance;
    final doc = firestore
        .collection('trackGenres')
        .doc(GenreCacheService.cacheKey(title, artist));

    try {
      final cached = (await doc.get()).data();
      final at = cached?['suggestedTagsAt'];
      final tags = cached?['suggestedTags'];
      if (tags is List &&
          at is Timestamp &&
          DateTime.now().difference(at.toDate()) <
              (tags.isEmpty ? _freshEmpty : _fresh)) {
        return [for (final t in tags) t.toString()];
      }
    } catch (e) {
      debugPrint('[TAG_SUGGEST] Cache read failed: $e');
    }

    final firstArtist = artist.split(',').first.trim();
    final deadline = DateTime.now().add(retryFor);
    final sources = [
      await _tags(
        'recording',
        'recording:"${_quote(title)}" AND artist:"${_quote(firstArtist)}"',
        'recordings',
        deadline,
      ),
      await _tags(
        'release-group',
        'releasegroup:"${_quote(title)}" AND artist:"${_quote(firstArtist)}"',
        'release-groups',
        deadline,
      ),
      await _tags(
        'artist',
        'artist:"${_quote(firstArtist)}"',
        'artists',
        deadline,
      ),
    ];
    final found = mergeSuggestions([
      for (final tags in sources) ?tags,
    ], limit: keep);

    // A lookup that failed (MusicBrainz busy or unreachable) isn't the
    // same as "no tags": don't cache, so the next try asks again.
    if (sources.contains(null)) return found;

    try {
      await doc.set({
        'title': title,
        'artist': artist,
        'suggestedTags': found,
        'suggestedTagsAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Signed out (the cache needs sign-in) or offline: still show them.
      debugPrint('[TAG_SUGGEST] Cache write skipped: $e');
    }
    return found;
  }

  static String _quote(String s) => s.replaceAll('"', ' ');

  /// The best result's tags for a MusicBrainz search, most voted first,
  /// junk removed; empty if MusicBrainz has none. Retries while MusicBrainz
  /// is busy (503) or unreachable until [deadline], then returns null.
  static Future<List<String>?> _tags(
    String entity,
    String query,
    String listKey,
    DateTime deadline,
  ) async {
    final uri = Uri.parse(
      '$_base/$entity',
    ).replace(queryParameters: {'query': query, 'fmt': 'json', 'limit': '1'});
    var backoff = const Duration(seconds: 2);
    while (true) {
      final wait = _gap - DateTime.now().difference(_lastRequest);
      if (wait > Duration.zero) await Future<void>.delayed(wait);
      _lastRequest = DateTime.now();
      try {
        final response = await http.get(uri).timeout(_timeout);
        if (response.statusCode == 200) {
          final results = (jsonDecode(response.body) as Map)[listKey] as List?;
          if (results == null || results.isEmpty) return const [];
          return tagsFromResult(results.first as Map);
        }
        debugPrint(
          '[TAG_SUGGEST] MusicBrainz $entity lookup: ${response.statusCode}',
        );
        // Only "busy" and server errors are worth retrying.
        if (response.statusCode != 429 && response.statusCode < 500) {
          return null;
        }
      } catch (e) {
        debugPrint('[TAG_SUGGEST] MusicBrainz $entity lookup failed: $e');
      }
      if (DateTime.now().add(backoff).isAfter(deadline)) return null;
      await Future<void>.delayed(backoff);
      backoff *= 2;
    }
  }

  /// A MusicBrainz search result's tags, most votes first, without junk.
  @visibleForTesting
  static List<String> tagsFromResult(Map result) {
    final tags = [
      for (final t in (result['tags'] as List? ?? const []))
        if (t is Map && t['name'] is String)
          (name: t['name'] as String, count: (t['count'] as num?) ?? 0),
    ]..sort((a, b) => b.count.compareTo(a.count));
    return [
      for (final t in tags)
        if (isUsefulTag(t.name)) t.name.trim().toLowerCase(),
    ];
  }

  /// Whether a MusicBrainz tag is worth suggesting: not a personal or
  /// bookkeeping tag ("seen live", "meme", "favorites"), not a bare year,
  /// and a sensible length. Decades ("70s", "1980s") are kept.
  @visibleForTesting
  static bool isUsefulTag(String tag) {
    final t = normalizeTag(tag);
    if (t.length < 2 || t.length > 30) return false;
    if (RegExp(r'^\d+$').hasMatch(t)) return false; // a bare year or number
    const junk = [
      'meme',
      'seen live',
      'favorite',
      'favourite',
      'owned',
      'spotify',
      'playlist',
      'listened',
      'to listen',
      'fixme',
      'check',
      'wishlist',
      'my ',
      'love it',
    ];
    return !junk.any(t.contains);
  }
}

/// Tags from several sources, in order (earlier sources first), each once
/// by its [normalizeTag] key, skipping [exclude] (normalized keys), up to
/// [limit].
List<String> mergeSuggestions(
  List<List<String>> sources, {
  Set<String> exclude = const {},
  int limit = 5,
}) {
  final seen = {...exclude};
  final out = <String>[];
  for (final source in sources) {
    for (final tag in source) {
      final key = normalizeTag(tag);
      if (key.isEmpty || !seen.add(key)) continue;
      out.add(tag);
      if (out.length == limit) return out;
    }
  }
  return out;
}
