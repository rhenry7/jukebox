import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/providers/recommended_albums_provider.dart';
import 'package:flutter_test_project/ui/screens/Trending/recommended_album_card.dart';
import 'package:flutter_test_project/ui/widgets/skeleton_loader.dart';
import 'package:gap/gap.dart';

/// Horizontal scroll section displaying recommended album cards.
///
/// Shows skeleton placeholders while loading and hides itself silently
/// on error or when there are no albums to display.
class RecommendedAlbumsSection extends ConsumerWidget {
  const RecommendedAlbumsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsAsync = ref.watch(recommendedAlbumsProvider);

    return albumsAsync.when(
      data: (albums) {
        if (albums.isEmpty) return const SizedBox.shrink();
        return _AlbumsContent(albums: albums);
      },
      loading: () => const _AlbumsLoading(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// The loaded albums section with header + horizontal list.
class _AlbumsContent extends StatelessWidget {
  final List<AlbumRecommendation> albums;

  const _AlbumsContent({required this.albums});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            'Recommended Tracks',
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
            itemCount: albums.length,
            itemBuilder: (context, index) {
              return Padding(
                padding:
                    EdgeInsets.only(right: index < albums.length - 1 ? 12 : 0),
                child: RecommendedAlbumCard(album: albums[index]),
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
class _AlbumsLoading extends StatelessWidget {
  const _AlbumsLoading();

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
