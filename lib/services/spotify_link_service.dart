import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:spotify/spotify.dart';

import '../Api/api_key.dart';
import '../utils/spotify_retry.dart';

/// A Spotify search result reduced to what link matching needs.
class SpotifyCandidate {
  const SpotifyCandidate({
    required this.id,
    required this.name,
    required this.artists,
    required this.isAlbum,
  });

  final String id;
  final String name;
  final List<String> artists;
  final bool isAlbum;

  Uri get url =>
      Uri.parse('https://open.spotify.com/${isAlbum ? 'album' : 'track'}/$id');
}

/// Finds the Spotify page for a reviewed song or album. Reviews only store a
/// title and artist, so this searches tracks and albums together and keeps
/// the result whose name and artist best match the review.
class SpotifyLinkService {
  SpotifyLinkService._();

  static final Map<String, Future<Uri?>> _cache = {};

  /// Spotify's own search page for the review, used when no confident match
  /// is found (or before the lookup finishes).
  static Uri searchUrl(String title, String artist) => Uri.parse(
      'https://open.spotify.com/search/${Uri.encodeComponent('$title $artist'.trim())}');

  /// The best track or album link for [title] by [artist], or null when
  /// nothing matches confidently. Results are cached for the session.
  static Future<Uri?> resolve(String title, String artist) {
    final key = '${normalize(title)}|${normalize(artist)}';
    return _cache[key] ??= _search(title, artist).catchError((Object e) {
      debugPrint('Spotify link lookup failed for $title by $artist: $e');
      _cache.remove(key);
      return null;
    });
  }

  static Future<Uri?> _search(String title, String artist) async {
    if (title.trim().isEmpty) return null;
    final api = SpotifyApi(SpotifyApiCredentials(clientId, clientSecret));
    final pages = await withSpotifyRetry(
      () => api.search.get('$title $artist',
          types: [SearchType.track, SearchType.album]).first(10),
    );

    final candidates = <SpotifyCandidate>[];
    for (final page in pages) {
      for (final item in page.items ?? const []) {
        if (item is Track && item.id != null) {
          candidates.add(SpotifyCandidate(
            id: item.id!,
            name: item.name ?? '',
            artists: [for (final a in item.artists ?? <Artist>[]) a.name ?? ''],
            isAlbum: false,
          ));
        } else if (item is AlbumSimple && item.id != null) {
          candidates.add(SpotifyCandidate(
            id: item.id!,
            name: item.name ?? '',
            artists: [
              for (final a in item.artists ?? <ArtistSimple>[]) a.name ?? ''
            ],
            isAlbum: true,
          ));
        }
      }
    }
    return pickBest(title, artist, candidates)?.url;
  }

  /// Picks the most relevant candidate: the artist must match, then the
  /// closest name wins (exact beats partial). On a tie the track wins over
  /// the album, and then Spotify's own ranking decides.
  @visibleForTesting
  static SpotifyCandidate? pickBest(
    String title,
    String artist,
    List<SpotifyCandidate> candidates,
  ) {
    final wantName = normalize(title);
    final wantArtist = normalize(artist);
    SpotifyCandidate? best;
    var bestScore = 0.0;
    for (var i = 0; i < candidates.length; i++) {
      final c = candidates[i];
      final artistMatch = c.artists.map(normalize).any(
          (a) => a.isNotEmpty && (a == wantArtist || wantArtist.contains(a)));
      if (!artistMatch) continue;

      final name = normalize(c.name);
      final nameScore = name == wantName
          ? 1.0
          : (name.isNotEmpty &&
                  (name.contains(wantName) || wantName.contains(name)))
              ? 0.6
              : 0.0;
      if (nameScore == 0) continue;

      final score = nameScore +
          (c.isAlbum
              ? 0
              : 0.05) + // a song review is more common than an album one
          0.01 * (candidates.length - i) / candidates.length; // Spotify's order
      if (score > bestScore) {
        bestScore = score;
        best = c;
      }
    }
    return best;
  }

  /// Lowercase, without "(feat. …)", "[Remastered]" or " - Live" suffixes,
  /// and without punctuation, so equivalent titles compare equal.
  @visibleForTesting
  static String normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), ' ')
      .replaceAll(RegExp(r'\s+-\s+.*$'), ' ')
      .replaceAll('&', 'and')
      .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
