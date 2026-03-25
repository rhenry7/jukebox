import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/Api/api_key.dart';
import 'package:flutter_test_project/GIFs/gifs.dart';
import 'package:flutter_test_project/models/enhanced_user_preferences.dart';
import 'package:flutter_test_project/providers/preferences_provider.dart';
import 'package:flutter_test_project/providers/recommended_albums_provider.dart';
import 'package:flutter_test_project/providers/recommended_artists_provider.dart';
import 'package:flutter_test_project/services/artist_recommendation_service.dart';
import 'package:flutter_test_project/ui/screens/Trending/recommended_albums_section.dart';
import 'package:flutter_test_project/ui/screens/Trending/recommended_artists_section.dart';
import 'package:flutter_test_project/ui/screens/Trending/popular_tracks_section.dart';
import 'package:flutter_test_project/providers/popular_tracks_provider.dart';
import 'package:gap/gap.dart';
import 'package:spotify/spotify.dart' as spotify;

/// Provider for trending tracks based on user preferences
final trendingTracksProvider =
    FutureProvider.family<List<TrendingTrack>, EnhancedUserPreferences>(
        (ref, preferences) async {
  return TrendingTracksService.fetchPersonalizedTrendingTracks(preferences);
});

/// Trending track with popularity score
class TrendingTrack {
  final spotify.Track track;
  final int popularity; // 0-100 from Spotify
  final double relevanceScore; // Calculated based on user preferences

  TrendingTrack({
    required this.track,
    required this.popularity,
    required this.relevanceScore,
  });
}

/// Service for fetching trending tracks
class TrendingTracksService {
  /// Fetch personalized trending tracks - SIMPLIFIED for speed
  /// Just gets Global Top 50 (updated daily) and personalizes ranking
  static Future<List<TrendingTrack>> fetchPersonalizedTrendingTracks(
    EnhancedUserPreferences preferences,
  ) async {
    try {
      final credentials = spotify.SpotifyApiCredentials(clientId, clientSecret);
      final spotifyApi = spotify.SpotifyApi(credentials);

      debugPrint(
          '🔥 [TRENDING] Fetching trending tracks from Global Top 50...');

      final List<TrendingTrack> trendingTracks = [];

      // Use "Today's Top Hits" - it's updated daily and reflects current trends
      // Alternative: Use search for recent popular tracks
      try {
        debugPrint('   📋 Fetching trending tracks...');

        // Strategy: Search for recent popular tracks from current year
        final currentYear = DateTime.now().year;
        final searchQueries = [
          'year:$currentYear', // Most recent tracks
        ];

        // Add user's favorite genres if available
        if (preferences.favoriteGenres.isNotEmpty) {
          for (final genre in preferences.favoriteGenres.take(2)) {
            searchQueries.add('year:$currentYear genre:$genre');
          }
        }

        // Search for trending tracks
        for (final query in searchQueries.take(3)) {
          try {
            debugPrint('   🔍 Searching: $query');
            final searchResults = await spotifyApi.search
                .get(query, types: [spotify.SearchType.track]).first(10);

            for (final page in searchResults) {
              if (page.items != null) {
                for (final track in page.items!) {
                  if (track is spotify.Track && track.id != null) {
                    // Use track data directly - it already has popularity
                    final popularity = track.popularity ?? 0;

                    // Only include tracks with decent popularity (trending)
                    if (popularity >= 40) {
                      final relevanceScore = _calculateRelevanceScore(
                        track,
                        preferences,
                      );

                      // Only add if not already in list
                      if (!trendingTracks.any((t) => t.track.id == track.id)) {
                        trendingTracks.add(TrendingTrack(
                          track: track,
                          popularity: popularity,
                          relevanceScore: relevanceScore,
                        ));
                      }
                    }
                  }
                }
              }
            }

            await Future.delayed(
                const Duration(milliseconds: 200)); // Rate limiting
          } catch (e) {
            debugPrint('   ⚠️  Error with query "$query": $e');
            continue;
          }
        }

        debugPrint('   ✅ Found ${trendingTracks.length} trending tracks');
      } catch (e) {
        debugPrint('   ⚠️  Error fetching trending tracks: $e');
        return [];
      }

      // Sort by: (relevanceScore * 0.6) + (popularity * 0.4)
      // This balances user preference relevance with overall popularity
      trendingTracks.sort((a, b) {
        final scoreA = (a.relevanceScore * 0.6) + (a.popularity * 0.4);
        final scoreB = (b.relevanceScore * 0.6) + (b.popularity * 0.4);
        return scoreB.compareTo(scoreA);
      });

      debugPrint('   ✅ Processed ${trendingTracks.length} trending tracks');
      debugPrint('   📊 Top 3 tracks:');
      for (var i = 0; i < trendingTracks.length.clamp(0, 3); i++) {
        final track = trendingTracks[i];
        debugPrint(
            '      ${i + 1}. "${track.track.name}" by ${track.track.artists?.first.name ?? "Unknown"} (popularity: ${track.popularity}, relevance: ${track.relevanceScore.toStringAsFixed(2)})');
      }

      return trendingTracks; // Return all (already limited to 30)
    } catch (e) {
      debugPrint('❌ [TRENDING] Error fetching trending tracks: $e');
      return [];
    }
  }

  /// Calculate relevance score based on user preferences (0.0 to 1.0)
  /// Simplified version - faster calculation
  static double _calculateRelevanceScore(
    spotify.Track track,
    EnhancedUserPreferences preferences,
  ) {
    double score = 0.0;

    // Check if track artist is in user's favorite artists
    if (preferences.favoriteArtists.isNotEmpty && track.artists != null) {
      for (final artist in track.artists!) {
        final artistName = artist.name?.toLowerCase() ?? '';
        for (final favArtist in preferences.favoriteArtists) {
          if (artistName.contains(favArtist.toLowerCase()) ||
              favArtist.toLowerCase().contains(artistName)) {
            score += 0.5; // High boost for favorite artist
            break;
          }
        }
      }
    }

    // Check if track album/genre matches user's favorite genres
    if (preferences.favoriteGenres.isNotEmpty) {
      // Check album name and track name for genre keywords
      final trackText =
          '${track.name ?? ""} ${track.album?.name ?? ""}'.toLowerCase();

      for (final genre in preferences.favoriteGenres.take(3)) {
        // Limit to top 3 genres for speed
        final genreWeight = preferences.genreWeights[genre] ?? 0.5;
        if (trackText.contains(genre.toLowerCase())) {
          score += 0.3 * genreWeight; // Weighted by user's genre preference
        }
      }
    }

    // Boost for high popularity (trending) - Global Top 50 tracks are already popular
    if (track.popularity != null && track.popularity! > 70) {
      score += 0.2; // Boost for very popular tracks
    }

    return score.clamp(0.0, 1.0);
  }
}

/// Trending Tracks Widget
class TrendingTracksWidget extends ConsumerWidget {
  const TrendingTracksWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferencesAsync = ref.watch(userPreferencesProvider);

    return preferencesAsync.when(
      data: (preferences) {
        final trendingAsync = ref.watch(trendingTracksProvider(preferences));

        return trendingAsync.when(
          data: (trendingTracks) {
            if (trendingTracks.isEmpty) {
              final emptyBottomInset = MediaQuery.of(context).padding.bottom +
                  kBottomNavigationBarHeight +
                  32;

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(trendingTracksProvider(preferences));
                  ref.invalidate(userPreferencesProvider);
                  ref.invalidate(recommendedAlbumsProvider);
                  ArtistRecommendationService.clearCache();
                  ref.invalidate(recommendedArtistsProvider);
                  ref.invalidate(popularTracksProvider);
                },
                color: Colors.red[600],
                child: CustomScrollView(
                  slivers: [
                    const SliverToBoxAdapter(
                      child: RecommendedAlbumsSection(),
                    ),
                    const SliverToBoxAdapter(
                      child: RecommendedArtistsSection(),
                    ),
                    const SliverToBoxAdapter(
                      child: PopularTracksSection(),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.only(bottom: emptyBottomInset),
                    ),
                  ],
                ),
              );
            }

            // Bottom padding to clear the floating nav bar + safe area
            final bottomInset = MediaQuery.of(context).padding.bottom;

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(trendingTracksProvider(preferences));
                ref.invalidate(userPreferencesProvider);
                ref.invalidate(recommendedAlbumsProvider);
                ArtistRecommendationService.clearCache();
                ref.invalidate(recommendedArtistsProvider);
                ref.invalidate(popularTracksProvider);
              },
              color: Colors.red[600],
              child: CustomScrollView(
                slivers: [
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: RecommendedAlbumsSection(),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: RecommendedArtistsSection(),
                  ),
                  const SliverToBoxAdapter(
                    child: PopularTracksSection(),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.only(bottom: bottomInset),
                  ),
                ],
              ),
            );
          },
          loading: () => const DiscoBallLoading(),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const Gap(16),
                const Text(
                  'Error loading trending tracks',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                const Gap(8),
                Text(
                  error.toString(),
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const Gap(16),
                ElevatedButton(
                  onPressed: () {
                    ref.invalidate(trendingTracksProvider(preferences));
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const DiscoBallLoading(),
      error: (error, stack) => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            Gap(16),
            Text(
              'Error loading preferences',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
