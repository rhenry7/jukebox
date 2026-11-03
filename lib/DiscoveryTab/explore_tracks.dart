import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/GIFs/gifs.dart';
import 'package:flutter_test_project/Api/apis.dart';
import 'package:flutter_test_project/providers/recommended_reviews_provider.dart';
import 'package:flutter_test_project/services/new_recommendation_service.dart';
import 'package:flutter_test_project/services/taste_profile_prompt_generation_service.dart';
import 'package:flutter_test_project/ui/theme/tokens.dart';
import 'package:flutter_test_project/ui/widgets/card_surface.dart';
import 'package:flutter_test_project/ui/widgets/genre_pills.dart';
import 'package:flutter_test_project/ui/widgets/review_feed.dart'
    show ReviewFeedLayout, reviewFeedPadding;
import 'package:flutter_test_project/utils/cached_image.dart';
import 'package:spotify/spotify.dart';

class ExploreTracks extends ConsumerStatefulWidget {
  const ExploreTracks({super.key});
  @override
  ConsumerState<ExploreTracks> createState() => ExploreTracksState();
}

class ExploreTracksState extends ConsumerState<ExploreTracks> {
  late Future<Pages<Category>> categories;

  @override
  Widget build(BuildContext context) {
    // Fetch taste profile to get user's music preferences
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final tasteProfileService = MusicProfileService(
      firestore: FirebaseFirestore.instance,
    );

    // Build the tracks future based on taste profile
    final tracksFuture = userId != null
        ? _buildTracksFromTasteProfile(tasteProfileService, userId)
        : fetchExploreTracks(); // Use defaults if not logged in

    return RefreshIndicator(
      onRefresh: () async {
        final refreshUserId = FirebaseAuth.instance.currentUser?.uid;
        if (refreshUserId != null && refreshUserId.isNotEmpty) {
          await NewRecommendationService.clearLocalCache(refreshUserId);
        }
        ref.invalidate(recommendedReviewsProvider);
        // Refresh by invalidating state
        setState(() {});
        await Future.delayed(const Duration(milliseconds: 500));
      },
      color: Colors.red[600],
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            Center(
              child: FutureBuilder<List<Track>>(
                future: tracksFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    if (snapshot.data!.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.explore_outlined,
                                  size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No tracks to explore',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 20),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Pull down to refresh and discover new music!',
                                style: TextStyle(color: Colors.white70),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final allTracks = snapshot.data!;

                    return ListView.builder(
                      padding: reviewFeedPadding(ReviewFeedLayout.tab),
                      itemCount: allTracks.length,
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemBuilder: (context, index) => Padding(
                        padding: AppSpacing.cardListItem,
                        child: _ExploreTrackCard(track: allTracks[index]),
                      ),
                    );
                  } else if (snapshot.hasError) {
                    debugPrint('Tracks load error: ${snapshot.error}');
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            const Text(
                              'Error loading tracks',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 18),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${snapshot.error}',
                              style: const TextStyle(color: Colors.white70),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {});
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return SizedBox(
                    height: MediaQuery.of(context).size.height * 0.65,
                    child: const Center(
                      child: DiscoBallLoading(),
                    ),
                  );
                },
              ),
            ),
            //const Gap(10),
          ],
        ),
      ),
    );
  }

  /// Build tracks future from taste profile
  Future<List<Track>> _buildTracksFromTasteProfile(
    MusicProfileService tasteProfileService,
    String userId,
  ) async {
    try {
      // Fetch music profile (with caching)
      final musicProfile =
          await tasteProfileService.getUserMusicProfile(userId);

      if (musicProfile != null) {
        // Generate taste profile to get structured data
        final tasteProfile =
            tasteProfileService.generateTasteProfile(musicProfile);

        // Extract preferred genres and genre weights
        final preferredGenres =
            (tasteProfile['preferredGenres'] as List?)?.cast<String>() ?? [];
        final genreWeights =
            (musicProfile['genreWeights'] as Map<String, dynamic>?)?.map(
                  (key, value) => MapEntry(key, (value as num).toDouble()),
                ) ??
                <String, double>{};

        debugPrint(
            '🎵 [EXPLORE] Using taste profile: ${preferredGenres.take(5).join(", ")}');

        if (preferredGenres.isNotEmpty) {
          return fetchExploreTracks(
            userGenres: preferredGenres,
            genreWeights: genreWeights.isNotEmpty ? genreWeights : null,
          );
        }
      }

      // Fallback to defaults if no taste profile
      debugPrint('🎵 [EXPLORE] No taste profile found, using defaults...');
      return fetchExploreTracks();
    } catch (e) {
      debugPrint('⚠️ Error fetching taste profile for explore: $e');
      // Fallback to defaults on error
      return fetchExploreTracks();
    }
  }
}

/// A track in the Explore list, laid out like the top of a review card
/// (same surface, art size, type and genre pills) without the review parts.
class _ExploreTrackCard extends StatelessWidget {
  const _ExploreTrackCard({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final images = track.album?.images ?? const [];
    // First image is the largest.
    final imageUrl = images.isNotEmpty ? images.first.url : null;
    final artists = track.artists ?? const <Artist>[];
    final primaryArtist = artists.isNotEmpty
        ? artists.first.name ?? 'Unknown Artist'
        : 'Unknown Artist';

    return CardSurface(
      imageUrl: imageUrl,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                imageUrl != null
                    ? AppCachedImage(
                        imageUrl: imageUrl,
                        width: 100,
                        height: 100,
                        borderRadius: AppRadius.smAll,
                      )
                    : ClipRRect(
                        borderRadius: AppRadius.smAll,
                        child: Container(
                          width: 100,
                          height: 100,
                          color: Colors.white10,
                          child: const Icon(Icons.music_note,
                              size: 48, color: Colors.white38),
                        ),
                      ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        artists.isNotEmpty
                            ? artists.map((a) => a.name).join(', ')
                            : 'Unknown Artist',
                        style: const TextStyle(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        track.name ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            TrackGenrePills(title: track.name ?? '', artist: primaryArtist),
          ],
        ),
      ),
    );
  }
}
