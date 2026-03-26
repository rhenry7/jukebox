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

/// Fetches Spotify artist data (images, genres, popularity) for the user's
/// most-reviewed artists. Watches [userReviewsProvider] so it auto-refreshes
/// when reviews change.
final spotifyTopArtistsProvider =
    FutureProvider<List<TopArtistData>>((ref) async {
  final reviewsAsync = ref.watch(userReviewsProvider);
  final reviewsWithDocIds = reviewsAsync.value;

  if (reviewsWithDocIds == null || reviewsWithDocIds.isEmpty) {
    return [];
  }

  // Count reviews per artist
  final artistCounts = <String, int>{};
  for (final r in reviewsWithDocIds) {
    final name = r.review.artist.trim();
    if (name.isEmpty) continue;
    artistCounts[name] = (artistCounts[name] ?? 0) + 1;
  }

  // Sort by review count, take top 10
  final sortedArtists = artistCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final topArtists = sortedArtists.take(10).toList();

  final credentials = SpotifyApiCredentials(clientId, clientSecret);
  final spotify = SpotifyApi(credentials);

  // Search Spotify for each artist in parallel
  final futures = topArtists.map((entry) async {
    try {
      final results = await withSpotifyRetry(
        () => spotify.search
            .get(entry.key, types: [SearchType.artist]).first(1),
      );

      for (final page in results) {
        if (page.items != null) {
          for (final item in page.items!) {
            if (item is Artist) {
              final imageUrl = (item.images?.isNotEmpty == true)
                  ? (item.images!.first.url ?? '')
                  : '';
              return TopArtistData(
                name: entry.key,
                imageUrl: imageUrl,
                genres: item.genres?.toList() ?? [],
                popularity: item.popularity ?? 0,
                reviewCount: entry.value,
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching Spotify artist "${entry.key}": $e');
    }

    // Fallback if Spotify search fails
    return TopArtistData(
      name: entry.key,
      imageUrl: '',
      genres: [],
      popularity: 0,
      reviewCount: entry.value,
    );
  });

  return Future.wait(futures);
});
