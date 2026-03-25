import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/providers/recommended_artists_provider.dart';
import 'package:flutter_test_project/ui/screens/Trending/recommended_artist_card.dart';
import 'package:flutter_test_project/ui/widgets/skeleton_loader.dart';
import 'package:gap/gap.dart';

/// Horizontal scroll section displaying recommended artist cards.
///
/// Shows skeleton placeholders while loading and hides itself silently
/// on error or when there are no artists to display.
class RecommendedArtistsSection extends ConsumerWidget {
  const RecommendedArtistsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistsAsync = ref.watch(recommendedArtistsProvider);

    return artistsAsync.when(
      data: (artists) {
        if (artists.isEmpty) return const SizedBox.shrink();
        return _ArtistsContent(artists: artists);
      },
      loading: () => const _ArtistsLoading(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// The loaded artists section with header + horizontal list.
class _ArtistsContent extends StatelessWidget {
  final List<RecommendedArtist> artists;

  const _ArtistsContent({required this.artists});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            'Recommended Artists',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 300,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: artists.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(right: index < artists.length - 1 ? 12 : 0),
                child: RecommendedArtistCard(artist: artists[index]),
              );
            },
          ),
        ),
        const Gap(16),
      ],
    );
  }
}

/// Skeleton loading state: 4 placeholder cards in a horizontal scroll.
class _ArtistsLoading extends StatelessWidget {
  const _ArtistsLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SkeletonLoader(width: 200, height: 22),
        ),
        SizedBox(
          height: 300,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(right: index < 3 ? 12 : 0),
                child: SkeletonLoader(
                  width: 200,
                  height: 300,
                  borderRadius: BorderRadius.circular(12),
                ),
              );
            },
          ),
        ),
        const Gap(16),
      ],
    );
  }
}
