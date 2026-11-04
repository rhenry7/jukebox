import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../providers/tag_reviews_provider.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_states.dart';
import '../../widgets/genre_pills.dart';
import '../../widgets/review_feed.dart';

/// Route name for a tag's page, so a pill for the tag already on screen
/// doesn't push the same page again.
String tagRouteName(String tag) => '/tag/${normalizeTag(tag)}';

/// Opens the page for [tag].
void openTagPage(BuildContext context, String tag) {
  if (ModalRoute.of(context)?.settings.name == tagRouteName(tag)) return;
  Navigator.of(context).push(MaterialPageRoute(
    settings: RouteSettings(name: tagRouteName(tag)),
    builder: (_) => TagReviewsPage(tag: tag),
  ));
}

/// Every recent review tagged [tag], then reviews with similar tags, with
/// related tags to explore next.
class TagReviewsPage extends ConsumerWidget {
  const TagReviewsPage({super.key, required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(tagReviewsProvider(tag));
    final data = result.valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.onSurface,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tag,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (data != null)
              Text(
                _countLabel(data),
                style: const TextStyle(
                    color: AppColors.onSurfaceVariant, fontSize: 12),
              ),
          ],
        ),
      ),
      body: result.when(
        loading: () =>
            const ReviewFeedSkeleton(layout: ReviewFeedLayout.pushed),
        error: (error, _) => AppErrorState(
          title: 'Could not load reviews',
          error: error,
          onRetry: () => ref.invalidate(tagReviewsProvider(tag)),
        ),
        data: (data) {
          final reviews = [...data.exact, ...data.similar];
          if (reviews.isEmpty) {
            return const AppEmptyState(
              icon: Icons.sell_outlined,
              title: 'No reviews with this tag yet',
              message: 'Tag a review with it and it will show up here.',
            );
          }
          final firstSimilar =
              data.similar.isEmpty ? null : data.similar.first.fullReviewId;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (data.related.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.pageGutter, 0,
                      AppSpacing.pageGutter, AppSpacing.md),
                  child: GenrePills(tags: data.related, topPadding: 0),
                ),
              Expanded(
                child: ReviewFeed(
                  reviews: reviews,
                  storageKey: 'tag-${normalizeTag(tag)}',
                  layout: ReviewFeedLayout.pushed,
                  onRefresh: () async =>
                      ref.refresh(tagReviewsProvider(tag).future),
                  itemWrapper: (context, review, card) =>
                      review.fullReviewId != null &&
                              review.fullReviewId == firstSimilar
                          ? _SimilarHeading(child: card)
                          : card,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _countLabel(TagReviews data) {
    final n = data.exact.length;
    final exact = '$n ${n == 1 ? 'review' : 'reviews'}';
    return data.similar.isEmpty
        ? exact
        : '$exact · ${data.similar.length} with similar tags';
  }
}

/// "Similar tags" heading above the first review that only has a similar tag.
class _SimilarHeading extends StatelessWidget {
  const _SimilarHeading({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cards run edge to edge; the heading lines up with their content.
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.cardPadding,
              AppSpacing.xl, AppSpacing.cardPadding, AppSpacing.sm),
          child: Text(
            'Similar tags',
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        child,
      ],
    );
  }
}
