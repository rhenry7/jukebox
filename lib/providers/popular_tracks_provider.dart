import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/Api/api_key.dart';
import 'package:spotify/spotify.dart' as spotify;

/// A globally popular track — not personalised to the user.
class PopularTrack {
  final String id;
  final String name;
  final String artist;
  final String imageUrl;
  final int popularity;

  const PopularTrack({
    required this.id,
    required this.name,
    required this.artist,
    required this.imageUrl,
    required this.popularity,
  });
}

/// Fetches globally popular tracks from Spotify, sorted purely by popularity.
///
/// No user-preference weighting — these are what's hot worldwide right now.
final popularTracksProvider = FutureProvider<List<PopularTrack>>((ref) async {
  try {
    final credentials = spotify.SpotifyApiCredentials(clientId, clientSecret);
    final api = spotify.SpotifyApi(credentials);

    debugPrint('[POPULAR] Fetching globally popular tracks...');

    final currentYear = DateTime.now().year;
    final results = await api.search
        .get('year:$currentYear', types: [spotify.SearchType.track]).first(20);

    final tracks = <PopularTrack>[];
    final seen = <String>{};

    for (final page in results) {
      if (page.items == null) continue;
      for (final item in page.items!) {
        if (item is spotify.Track &&
            item.id != null &&
            seen.add(item.id!)) {
          final pop = item.popularity ?? 0;
          if (pop >= 50) {
            tracks.add(PopularTrack(
              id: item.id!,
              name: item.name ?? 'Unknown',
              artist: item.artists
                      ?.map((a) => a.name ?? 'Unknown')
                      .join(', ') ??
                  'Unknown Artist',
              imageUrl: item.album?.images?.isNotEmpty == true
                  ? item.album!.images!.first.url ?? ''
                  : '',
              popularity: pop,
            ));
          }
        }
      }
    }

    // Pure popularity sort — no user bias
    tracks.sort((a, b) => b.popularity.compareTo(a.popularity));

    debugPrint('[POPULAR] Found ${tracks.length} popular tracks');
    return tracks.take(15).toList();
  } catch (e) {
    debugPrint('[POPULAR] Error fetching popular tracks: $e');
    return [];
  }
});
