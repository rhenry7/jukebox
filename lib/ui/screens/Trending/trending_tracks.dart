import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/Api/api_key.dart';
import 'package:flutter_test_project/GIFs/gifs.dart';
import 'package:flutter_test_project/models/enhanced_user_preferences.dart';
import 'package:flutter_test_project/providers/preferences_provider.dart';
import 'package:flutter_test_project/ui/screens/addReview/reviewSheetContentForm.dart';
import 'package:gap/gap.dart';
import 'package:spotify/spotify.dart' as spotify;

/// Provider for trending tracks based on user preferences
final trendingTracksProvider = FutureProvider.family<List<TrendingTrack>, EnhancedUserPreferences>((ref, preferences) async {
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

      print('🔥 [TRENDING] Fetching trending tracks from Global Top 50...');

      final List<TrendingTrack> trendingTracks = [];
      
      // Use "Today's Top Hits" - it's updated daily and reflects current trends
      // Alternative: Use search for recent popular tracks
      try {
        print('   📋 Fetching trending tracks...');
        
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
            print('   🔍 Searching: $query');
            final searchResults = await spotifyApi.search
                .get(query, types: [spotify.SearchType.track])
                .first(10);

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
            
            await Future.delayed(const Duration(milliseconds: 200)); // Rate limiting
          } catch (e) {
            print('   ⚠️  Error with query "$query": $e');
            continue;
          }
        }

        print('   ✅ Found ${trendingTracks.length} trending tracks');
      } catch (e) {
        print('   ⚠️  Error fetching trending tracks: $e');
        return [];
      }

      // Sort by: (relevanceScore * 0.6) + (popularity * 0.4)
      // This balances user preference relevance with overall popularity
      trendingTracks.sort((a, b) {
        final scoreA = (a.relevanceScore * 0.6) + (a.popularity * 0.4);
        final scoreB = (b.relevanceScore * 0.6) + (b.popularity * 0.4);
        return scoreB.compareTo(scoreA);
      });

      print('   ✅ Processed ${trendingTracks.length} trending tracks');
      print('   📊 Top 3 tracks:');
      for (var i = 0; i < trendingTracks.length.clamp(0, 3); i++) {
        final track = trendingTracks[i];
        print('      ${i + 1}. "${track.track.name}" by ${track.track.artists?.first.name ?? "Unknown"} (popularity: ${track.popularity}, relevance: ${track.relevanceScore.toStringAsFixed(2)})');
      }

      return trendingTracks; // Return all (already limited to 30)
    } catch (e) {
      print('❌ [TRENDING] Error fetching trending tracks: $e');
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
      final trackText = '${track.name ?? ""} ${track.album?.name ?? ""}'.toLowerCase();
      
      for (final genre in preferences.favoriteGenres.take(3)) { // Limit to top 3 genres for speed
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
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.trending_up, size: 64, color: Colors.grey),
                    Gap(16),
                    Text(
                      'No trending tracks found',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    Gap(8),
                    Text(
                      'Try updating your music preferences',
                      style: TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(trendingTracksProvider(preferences));
                ref.invalidate(userPreferencesProvider);
              },
              color: Colors.red[600],
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: trendingTracks.length,
                itemBuilder: (context, index) {
                  final trendingTrack = trendingTracks[index];
                  final track = trendingTrack.track;
                  
                  return _TrendingTrackCard(
                    track: track,
                    popularity: trendingTrack.popularity,
                    relevanceScore: trendingTrack.relevanceScore,
                  );
                },
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

/// Individual trending track card
class _TrendingTrackCard extends StatelessWidget {
  final spotify.Track track;
  final int popularity;
  final double relevanceScore;

  const _TrendingTrackCard({
    required this.track,
    required this.popularity,
    required this.relevanceScore,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = track.album?.images?.isNotEmpty == true
        ? track.album!.images!.first.url
        : null;
    final artistNames = track.artists?.map((a) => a.name ?? 'Unknown').join(', ') ?? 'Unknown Artist';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: relevanceScore > 0.5 ? Colors.red.withOpacity(0.3) : Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (BuildContext context) {
              return MyReviewSheetContentForm(
                title: track.name ?? 'Unknown Track',
                artist: artistNames,
                albumImageUrl: imageUrl ?? '',
              );
            },
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Album cover
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imageUrl != null
                    ? Image.network(
                        imageUrl,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 64,
                            height: 64,
                            color: Colors.grey[800],
                            child: const Icon(Icons.music_note, color: Colors.white70),
                          );
                        },
                      )
                    : Container(
                        width: 64,
                        height: 64,
                        color: Colors.grey[800],
                        child: const Icon(Icons.music_note, color: Colors.white70),
                      ),
              ),
              const Gap(12),
              // Track info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.name ?? 'Unknown Track',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(4),
                    Text(
                      artistNames,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(6),
                    // Popularity and relevance indicators
                    Row(
                      children: [
                        // Popularity indicator
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.trending_up, size: 14, color: Colors.green),
                            const Gap(4),
                            Text(
                              '$popularity',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        if (relevanceScore > 0.3) ...[
                          const Gap(12),
                          // Relevance indicator
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.favorite, size: 14, color: Colors.red),
                              const Gap(4),
                              Text(
                                '${(relevanceScore * 100).toInt()}% match',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
