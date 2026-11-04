import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotify/spotify.dart';
import 'package:flutter_test_project/Api/api_key.dart';
import 'package:flutter_test_project/providers/reviews_provider.dart';
import 'package:flutter_test_project/utils/spotify_retry.dart';

class TopArtistData {
  final String name;
  final String imageUrl;
  final List<String> genres;
  final int popularity;
  final int reviewCount;

  const TopArtistData({
    required this.name,
    required this.imageUrl,
    required this.genres,
    required this.popularity,
    required this.reviewCount,
  });
}

/// How many top artists the profile shows (and looks up on Spotify).
const int topArtistCount = 4;

/// An artist and how many of the user's reviews credit them.
typedef ArtistTally = ({String name, int count});

/// The user's most-reviewed artists, most reviews first, with Spotify photos.
/// Watches [userReviewsProvider] so it refreshes when reviews change.
final spotifyTopArtistsProvider =
    FutureProvider<List<TopArtistData>>((ref) async {
  final reviews = ref.watch(userReviewsProvider).value;
  if (reviews == null || reviews.isEmpty) return [];

  final top = rankArtists([
    for (final r in reviews)
      // Reposts are someone else's review.
      if (!r.review.isRepost) (artist: r.review.artist, date: r.review.date),
  ]).take(topArtistCount);

  final spotify = SpotifyApi(SpotifyApiCredentials(clientId, clientSecret));
  return Future.wait(top.map((tally) async {
    try {
      final pages = await withSpotifyRetry(
        () =>
            spotify.search.get(tally.name, types: [SearchType.artist]).first(5),
      );
      final match = pickArtistMatch(tally.name, [
        for (final page in pages)
          for (final item in page.items ?? const [])
            if (item is Artist) item,
      ]);
      if (match != null) {
        return TopArtistData(
          name: tally.name,
          imageUrl: match.images?.firstOrNull?.url ?? '',
          genres: match.genres?.toList() ?? [],
          popularity: match.popularity ?? 0,
          reviewCount: tally.count,
        );
      }
    } catch (e) {
      debugPrint('Error fetching Spotify artist "${tally.name}": $e');
    }
    // No confident match: the profile shows the artist's initial instead.
    return TopArtistData(
      name: tally.name,
      imageUrl: '',
      genres: const [],
      popularity: 0,
      reviewCount: tally.count,
    );
  }));
});

/// Counts reviews per artist, crediting every artist on a review, and ranks
/// them by count. Names are compared ignoring case and accents; the most
/// recent spelling is shown. Ties go to the artist reviewed most recently.
@visibleForTesting
List<ArtistTally> rankArtists(
    Iterable<({String artist, DateTime? date})> reviews) {
  final counts = <String, int>{};
  final latest = <String, DateTime>{};
  final spelling = <String, String>{};
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);

  for (final r in reviews) {
    final date = r.date ?? epoch;
    for (final name in splitArtists(r.artist)) {
      final key = normalizeArtist(name);
      if (key.isEmpty) continue;
      counts[key] = (counts[key] ?? 0) + 1;
      if (!latest.containsKey(key) || date.isAfter(latest[key]!)) {
        latest[key] = date;
        spelling[key] = name;
      }
    }
  }

  final keys = counts.keys.toList()
    ..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      if (byCount != 0) return byCount;
      final byRecent = latest[b]!.compareTo(latest[a]!);
      return byRecent != 0 ? byRecent : a.compareTo(b);
    });
  return [for (final k in keys) (name: spelling[k]!, count: counts[k]!)];
}

/// Artists whose own names contain ", ", which must not be split.
const Set<String> _commaNames = {
  'tyler, the creator',
  'earth, wind & fire',
  'crosby, stills, nash & young',
  'crosby, stills & nash',
  'emerson, lake & palmer',
  'peter, paul and mary',
  'blood, sweat & tears',
};

/// The artists credited on a review. The review form stores Spotify's
/// artist list joined with ", ", so that is the main separator; manual
/// "feat." credits are split too. "&" is not a separator — Spotify lists
/// "Simon & Garfunkel" as one artist.
@visibleForTesting
List<String> splitArtists(String artist) {
  var rest = artist;
  final protected = <String>[];
  for (final name in _commaNames) {
    final i = rest.toLowerCase().indexOf(name);
    if (i >= 0) {
      protected.add(rest.substring(i, i + name.length));
      rest = rest.replaceRange(i, i + name.length, '');
    }
  }
  final parts = rest
      .split(
          RegExp(r',|\s+(?:feat\.?|ft\.?|featuring)\s+', caseSensitive: false))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty);
  return [...protected, ...parts];
}

/// Lowercase, accents folded and punctuation dropped, so "Beyoncé" and
/// "beyonce" count as the same artist.
@visibleForTesting
String normalizeArtist(String name) {
  const accents = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', //
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', //
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', //
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', 'ø': 'o', //
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', //
    'ñ': 'n', 'ç': 'c', 'ý': 'y', 'ÿ': 'y',
  };
  final folded = name
      .toLowerCase()
      .split('')
      .map((c) => accents[c] ?? c)
      .join()
      .replaceAll('&', 'and');
  return folded
      .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// The Spotify artist whose name matches [name] (ignoring case, accents and
/// punctuation), in Spotify's order — or null, rather than guessing.
@visibleForTesting
Artist? pickArtistMatch(String name, List<Artist> candidates) {
  final want = normalizeArtist(name);
  for (final a in candidates) {
    if (normalizeArtist(a.name ?? '') == want) return a;
  }
  return null;
}
