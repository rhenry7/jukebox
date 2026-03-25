import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/providers/popular_tracks_provider.dart';
import 'package:flutter_test_project/ui/screens/Trending/popular_track_card.dart';
import 'package:flutter_test_project/ui/widgets/skeleton_loader.dart';
import 'package:gap/gap.dart';

/// Horizontal scroll section displaying globally popular tracks.
///
/// Shows skeleton placeholders while loading and hides itself silently
/// on error or when there are no tracks to display.
class PopularTracksSection extends ConsumerWidget {
  const PopularTracksSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracksAsync = ref.watch(popularTracksProvider);

    return tracksAsync.when(
      data: (tracks) {
        if (tracks.isEmpty) return const SizedBox.shrink();
        return _TracksContent(tracks: tracks);
      },
      loading: () => const _TracksLoading(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// The loaded tracks section with header + horizontal list.
class _TracksContent extends StatelessWidget {
  final List<PopularTrack> tracks;

  const _TracksContent({required this.tracks});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            'Popular Right Now',
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
            itemCount: tracks.length,
            itemBuilder: (context, index) {
              return Padding(
                padding:
                    EdgeInsets.only(right: index < tracks.length - 1 ? 12 : 0),
                child: PopularTrackCard(track: tracks[index]),
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
class _TracksLoading extends StatelessWidget {
  const _TracksLoading();

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
