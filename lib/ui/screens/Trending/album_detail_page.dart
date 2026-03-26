import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/providers/album_reviews_provider.dart';
import 'package:flutter_test_project/providers/recommended_albums_provider.dart';
import 'package:flutter_test_project/ui/screens/Home/_comments.dart'
    show ReviewCardWithGenres;
import 'package:flutter_test_project/ui/screens/addReview/reviewSheetContentForm.dart';
import 'package:flutter_test_project/ui/widgets/skeleton_loader.dart';
import 'package:flutter_test_project/utils/cached_image.dart';
import 'package:gap/gap.dart';

/// Full-screen detail page for a recommended album.
///
/// Top half shows album art with title/artist/genre overlay.
/// Bottom half shows community reviews for that album.
class AlbumDetailPage extends ConsumerWidget {
  final AlbumRecommendation album;

  const AlbumDetailPage({super.key, required this.album});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(
      albumReviewsProvider((artist: album.artist, title: album.title)),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          // Hero section with album art and info overlay
          SliverToBoxAdapter(
            child: _AlbumHeroSection(album: album),
          ),

          // Reviews header with write review CTA
          SliverToBoxAdapter(
            child: _ReviewsHeader(
              reviewCount: reviewsAsync.valueOrNull?.length,
              onWriteReview: () => _openReviewSheet(context, ref),
            ),
          ),

          // Reviews list
          ...reviewsAsync.when(
            data: (reviews) {
              if (reviews.isEmpty) {
                return [
                  SliverToBoxAdapter(
                    child: _EmptyReviews(
                      onWriteReview: () => _openReviewSheet(context, ref),
                    ),
                  ),
                ];
              }
              return [
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final review = reviews[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 4.0),
                        child: Card(
                          elevation: 1,
                          margin: EdgeInsets.zero,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                            side: BorderSide(
                                color: Color.fromARGB(56, 158, 158, 158)),
                          ),
                          color: Colors.white10,
                          child: ReviewCardWithGenres(
                            review: review.review,
                            reviewId: review.fullReviewId,
                            showLikeButton: true,
                          ),
                        ),
                      );
                    },
                    childCount: reviews.length,
                  ),
                ),
              ];
            },
            loading: () => [
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, __) => const ReviewCardSkeleton(),
                  childCount: 3,
                ),
              ),
            ],
            error: (error, _) => [
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.red),
                        const Gap(12),
                        const Text(
                          'Error loading reviews',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        const Gap(8),
                        Text(
                          error.toString(),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                        const Gap(16),
                        ElevatedButton(
                          onPressed: () => ref.invalidate(albumReviewsProvider(
                            (artist: album.artist, title: album.title),
                          )),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Bottom safe area padding
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 24,
            ),
          ),
        ],
      ),
    );
  }

  void _openReviewSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return MyReviewSheetContentForm(
          title: album.title,
          artist: album.artist,
          albumImageUrl: album.albumImageUrl,
        );
      },
    ).then((_) {
      // Refresh reviews after the sheet closes (user may have submitted a review)
      ref.invalidate(albumReviewsProvider(
        (artist: album.artist, title: album.title),
      ));
    });
  }
}

/// Top hero section: album art with gradient overlay and info.
class _AlbumHeroSection extends StatelessWidget {
  final AlbumRecommendation album;

  const _AlbumHeroSection({required this.album});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return SizedBox(
      height: 350,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Album art
          album.albumImageUrl.isNotEmpty
              ? AppCachedImage(
                  imageUrl: album.albumImageUrl,
                  width: double.infinity,
                  height: 350,
                  fit: BoxFit.cover,
                )
              : Container(
                  color: Colors.grey[800],
                  child:
                      const Icon(Icons.album, color: Colors.white70, size: 80),
                ),

          // Gradient overlay for readability
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.transparent,
                  Colors.black.withOpacity(0.8),
                  Colors.black,
                ],
                stops: const [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),

          // Close button (top-left, respects status bar)
          Positioned(
            top: topPadding + 8,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.5),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),

          // Album info overlay (bottom of hero)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Text(
                  album.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap(4),
                // Artist
                Text(
                  album.artist,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // Genre pills
                if (album.genres.isNotEmpty) ...[
                  const Gap(10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: album.genres.take(4).map((genre) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          genre,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const Gap(10),
                // Stats row
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        color: Colors.amber, size: 18),
                    const Gap(4),
                    Text(
                      album.averageScore.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Gap(16),
                    const Icon(Icons.rate_review_outlined,
                        color: Colors.white54, size: 16),
                    const Gap(4),
                    Text(
                      '${album.reviewCount} reviews',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Section header between hero and reviews list.
class _ReviewsHeader extends StatelessWidget {
  final int? reviewCount;
  final VoidCallback onWriteReview;

  const _ReviewsHeader({
    required this.reviewCount,
    required this.onWriteReview,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            reviewCount != null ? 'Reviews ($reviewCount)' : 'Reviews',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: onWriteReview,
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Write a Review'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red[400],
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder shown when no reviews exist for this album.
class _EmptyReviews extends StatelessWidget {
  final VoidCallback onWriteReview;

  const _EmptyReviews({required this.onWriteReview});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Gap(24),
            const Icon(Icons.rate_review_outlined,
                size: 48, color: Colors.grey),
            const Gap(12),
            const Text(
              'No reviews yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Gap(8),
            const Text(
              'Be the first to share your thoughts!',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const Gap(20),
            ElevatedButton.icon(
              onPressed: onWriteReview,
              icon: const Icon(Icons.edit),
              label: const Text('Write a Review'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
