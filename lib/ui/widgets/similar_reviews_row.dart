import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/review.dart';
import '../../providers/similar_reviews_provider.dart';
import '../theme/tokens.dart';
import 'review_card.dart' show CompactReviewCard;
import 'skeleton_loader.dart';

/// "More like this": a sideways-scrolling row of [CompactReviewCard]s for
/// reviews tagged like [review]. Shows placeholders while loading and
/// nothing at all if there are none (or they fail to load).
///
/// Lays itself out [gutter] wider on each side than it's given, so the cards
/// scroll in from the screen edge while the first one lines up with the
/// page's text.
class SimilarReviewsRow extends ConsumerWidget {
  const SimilarReviewsRow({
    super.key,
    required this.review,
    required this.reviewId,
    required this.gutter,
  });

  final Review review;
  final String? reviewId;
  final double gutter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final similar = ref
        .watch(similarReviewsProvider(similarReviewsKeyFor(review, reviewId)));
    final reviews = similar.valueOrNull;
    if (!similar.isLoading && (reviews == null || reviews.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'More like this',
          style: TextStyle(
            color: AppColors.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) => SizedBox(
            height: CompactReviewCard.height,
            child: OverflowBox(
              maxWidth: constraints.maxWidth + gutter * 2,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: gutter),
                itemCount: reviews?.length ?? 2,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.md),
                itemBuilder: (context, i) => reviews == null
                    ? const SkeletonLoader(
                        width: CompactReviewCard.width,
                        height: CompactReviewCard.height,
                        borderRadius: AppRadius.cardAll,
                      )
                    : CompactReviewCard(
                        key: ValueKey(reviews[i].fullReviewId),
                        review: reviews[i].review,
                        reviewId: reviews[i].fullReviewId,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
