import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/providers/music_news_provider.dart';
import 'package:flutter_test_project/providers/reviews_provider.dart';
import 'package:flutter_test_project/providers/tag_reviews_provider.dart'
    show normalizeTag;
import 'package:flutter_test_project/services/spotify_client.dart';
import 'package:flutter_test_project/utils/spotify_retry.dart';
import 'package:spotify/spotify.dart' as spotify;

/// What the Search page shows for a query, besides reviews (see
/// `UnifiedSearchResults`): the best single match, tags, songs and albums
/// to review, and Best New Music articles.

/// A tab of the results: everything, or one kind.
enum SearchScope {
  all('All'),
  reviews('Reviews'),
  music('Music'),
  articles('Articles'),
  tags('Tags');

  const SearchScope(this.label);
  final String label;
}

/// The scope pill picked (All unless the user narrows it).
final searchScopeProvider = StateProvider.autoDispose<SearchScope>(
  (ref) => SearchScope.all,
);

/// A tag on REVERB reviews and how many of the searched pool carry it.
@immutable
class TagMatch {
  const TagMatch(this.tag, this.count);

  /// As first spelled on a review ("Night Phonk").
  final String tag;
  final int count;

  @override
  bool operator ==(Object other) =>
      other is TagMatch && other.tag == tag && other.count == count;

  @override
  int get hashCode => Object.hash(tag, count);
}

/// Tags in [reviews] matching [query]: the tag itself, or one with a word
/// starting with it ("phonk" → "phonk", "night phonk", "phonky house").
/// Exact first, then the most used. Spellings fold like tag pages do
/// ([normalizeTag]).
List<TagMatch> matchTags(List<ReviewWithDocId> reviews, String query) {
  final q = normalizeTag(query);
  if (q.length < 2) return const [];
  final counts = <String, int>{};
  final spelled = <String, String>{};
  for (final r in reviews) {
    for (final t in {...?r.review.genres}) {
      final key = normalizeTag(t);
      if (key.isEmpty) continue;
      spelled.putIfAbsent(key, t.trim);
      counts[key] = (counts[key] ?? 0) + 1;
    }
  }
  final hits =
      [
        for (final key in counts.keys)
          if (key == q ||
              key.split(' ').any((w) => w.startsWith(q)) ||
              key.startsWith(q))
            key,
      ]..sort((a, b) {
        final exact = (b == q ? 1 : 0) - (a == q ? 1 : 0);
        return exact != 0 ? exact : counts[b]!.compareTo(counts[a]!);
      });
  return [for (final k in hits) TagMatch(spelled[k]!, counts[k]!)];
}

/// An artist with REVERB reviews, for the top result.
@immutable
class ArtistMatch {
  const ArtistMatch({
    required this.name,
    required this.reviewCount,
    required this.averageScore,
    this.imageUrl,
  });

  final String name;
  final int reviewCount;

  /// Average stars of their REVERB reviews.
  final double averageScore;

  /// The newest review's album art.
  final String? imageUrl;
}

/// The artist [query] most likely means: one of the reviewed artists
/// (each name in "A, B" counts) whose name is the query or has a word
/// starting with it ("billie" → "Billie Eilish"); the most reviewed wins.
ArtistMatch? matchArtist(List<ReviewWithDocId> reviews, String query) {
  final q = query.trim().toLowerCase();
  if (q.length < 2) return null;
  final byArtist = <String, List<ReviewWithDocId>>{};
  final spelled = <String, String>{};
  for (final r in reviews) {
    for (final name in r.review.artist.split(',')) {
      final key = name.trim().toLowerCase();
      if (key.isEmpty) continue;
      if (key == q || key.split(RegExp(r'\s+')).any((w) => w.startsWith(q))) {
        spelled.putIfAbsent(key, name.trim);
        byArtist.putIfAbsent(key, () => []).add(r);
      }
    }
  }
  if (byArtist.isEmpty) return null;
  final best = byArtist.entries.reduce((a, b) {
    final exactA = a.key == q, exactB = b.key == q;
    if (exactA != exactB) return exactA ? a : b;
    return b.value.length > a.value.length ? b : a;
  });
  final list = [...best.value]
    ..sort(
      (a, b) => (b.review.date ?? DateTime(1970)).compareTo(
        a.review.date ?? DateTime(1970),
      ),
    );
  final rated = [
    for (final r in list)
      if (r.review.score > 0) r.review.score,
  ];
  return ArtistMatch(
    name: spelled[best.key]!,
    reviewCount: list.length,
    averageScore: rated.isEmpty
        ? 0
        : rated.reduce((a, b) => a + b) / rated.length,
    imageUrl: list
        .map((r) => r.review.albumImageUrl)
        .firstWhere((u) => u != null && u.isNotEmpty, orElse: () => null),
  );
}

/// Best New Music albums matching [query]: every word appears in the
/// album, artist, tags or genres.
List<NewsAlbum> matchArticles(List<NewsAlbum> albums, String query) {
  final words = query.toLowerCase().split(RegExp(r'\s+'))
    ..removeWhere((w) => w.isEmpty);
  if (words.isEmpty) return const [];
  return [
    for (final a in albums)
      if (words.every(
        [
          for (final r in a.reviews) ...[r.album, r.artist],
          ...a.tags,
          ...a.genres,
        ].join(' ').toLowerCase().contains,
      ))
        a,
  ];
}

/// A song or album on Spotify, to review.
@immutable
class MusicResult {
  const MusicResult({
    required this.title,
    required this.artist,
    required this.isAlbum,
    required this.spotifyUrl,
    this.imageUrl,
  });

  final String title;
  final String artist;
  final bool isAlbum;
  final String spotifyUrl;
  final String? imageUrl;
}

/// Songs (up to 6) then albums (up to 4) on Spotify for [query]. One search
/// per query (the page waits for typing to pause first), kept while the
/// page is open.
final musicSearchProvider = FutureProvider.autoDispose
    .family<List<MusicResult>, String>((ref, query) async {
      final q = query.trim();
      if (q.length < 2) return const [];
      final pages = await withSpotifyRetry(
        () => sharedSpotifyApi().search
            .get(q, types: [spotify.SearchType.track, spotify.SearchType.album])
            .first(6),
      );
      final songs = <MusicResult>[];
      final albums = <MusicResult>[];
      for (final page in pages) {
        for (final item in page.items ?? const []) {
          if (item is spotify.Track && item.id != null) {
            songs.add(
              MusicResult(
                title: item.name ?? '',
                artist: (item.artists ?? const [])
                    .map((a) => a.name ?? '')
                    .where((n) => n.isNotEmpty)
                    .join(', '),
                isAlbum: false,
                spotifyUrl: 'https://open.spotify.com/track/${item.id}',
                imageUrl: item.album?.images?.firstOrNull?.url,
              ),
            );
          } else if (item is spotify.AlbumSimple && item.id != null) {
            albums.add(
              MusicResult(
                title: item.name ?? '',
                artist: (item.artists ?? const [])
                    .map((a) => a.name ?? '')
                    .where((n) => n.isNotEmpty)
                    .join(', '),
                isAlbum: true,
                spotifyUrl: 'https://open.spotify.com/album/${item.id}',
                imageUrl: item.images?.firstOrNull?.url,
              ),
            );
          }
        }
      }
      return [
        ...songs.take(6),
        ...albums.take(4),
      ].where((m) => m.title.isNotEmpty).toList();
    });
