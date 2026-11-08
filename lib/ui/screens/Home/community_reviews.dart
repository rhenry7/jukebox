import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/community_reviews_provider.dart';
import '../../../providers/home_feed_controls.dart';
import '../../../providers/reviews_provider.dart' show ReviewWithDocId;
import '../../../routing/MainNavigation.dart';

import 'package:flutter_test_project/ui/widgets/app_states.dart';
import 'package:flutter_test_project/ui/widgets/home_feed_controls.dart'
    show NoTagMatches;
import 'package:flutter_test_project/ui/widgets/review_feed.dart';
import 'package:flutter_test_project/ui/widgets/review_options.dart';

/// Popular tab: community reviews with real text and album art, in a fresh
/// random order each time the tab is shown (or pulled to refresh), revealed
/// a page at a time. The Home row's tag filter switches it to reviews with
/// those tags (through the tag index), and its sort reorders either list.
class CommunityReviewsCollection extends ConsumerStatefulWidget {
  const CommunityReviewsCollection({super.key});

  @override
  ConsumerState<CommunityReviewsCollection> createState() =>
      _CommunityReviewsCollectionState();
}

class _CommunityReviewsCollectionState
    extends ConsumerState<CommunityReviewsCollection> {
  static const int _pageSize = 20;

  /// Picks the random order. A new one each time this tab is built (the
  /// TabBarView rebuilds it whenever the tab is selected) and on refresh.
  int _shuffleSeed = math.Random().nextInt(1 << 31);
  int _visibleCount = _pageSize;

  /// Reviews in the order they were dealt (see [keepPlacedOrder]), so cards
  /// keep their places as more of the pool arrives. Cleared on reshuffle.
  List<String> _placedIds = const [];

  Future<void> _loadMore() async {
    setState(() => _visibleCount += _pageSize);
  }

  /// Pull-to-refresh: re-reads the pool (it isn't kept live) and deals a
  /// new order.
  Future<void> _reshuffle() async {
    ref.invalidate(communityReviewsProvider);
    try {
      await ref.read(communityReviewsProvider.future);
    } catch (_) {
      // The tab shows the error state with its own Retry.
    }
    if (!mounted) return;
    setState(() {
      _shuffleSeed = math.Random().nextInt(1 << 31);
      _visibleCount = _pageSize;
      _placedIds = const [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final tags = ref.watch(homeTagFilterProvider);
    final sort = ref.watch(homeSortProvider);
    // A new filter or sort starts the list again from its first page.
    ref.listen(homeTagFilterProvider, (_, __) => _resetPaging());
    ref.listen(homeSortProvider, (_, __) => _resetPaging());

    if (tags.isNotEmpty) {
      final key = tagFilterKey(tags);
      return ref
          .watch(popularTagFilterProvider(key))
          .when(
            skipLoadingOnReload: true,
            data: (reviews) {
              if (reviews.isEmpty) return const NoTagMatches();
              return _feed(
                'community_filtered_list',
                applyHomeSort(reviews, sort, (r) => r.review),
                onRefresh: () async {
                  ref.invalidate(popularTagFilterProvider(key));
                  try {
                    await ref.read(popularTagFilterProvider(key).future);
                  } catch (_) {
                    // The tab shows the error state with its own Retry.
                  }
                },
              );
            },
            loading: () => const ReviewFeedSkeleton(),
            error: (error, _) {
              debugPrint('Error filtering Popular by tags: $error');
              return AppErrorState(
                title: 'Error loading reviews for these tags',
                error: error,
                onRetry: () => ref.invalidate(popularTagFilterProvider(key)),
              );
            },
          );
    }

    final reviewsAsync = ref.watch(communityReviewsProvider);
    return reviewsAsync.when(
      data: (reviews) {
        if (reviews.isEmpty) {
          return AppEmptyState(
            icon: Icons.music_note,
            title: 'No community reviews yet',
            message: 'Be the first to share your music reviews!',
            action: AppStateAction(
              label: 'Write a review',
              icon: Icons.add,
              onPressed: () {
                context.findAncestorStateOfType<MainNavState>()?.navigateToTab(
                  MainNavState.addTab,
                );
              },
            ),
          );
        }

        final shuffled = keepPlacedOrder(reviews, _placedIds, _shuffleSeed);
        _placedIds = [for (final r in shuffled) r.fullReviewId ?? r.docId];
        return _feed(
          'community_reviews_list',
          applyHomeSort(shuffled, sort, (r) => r.review),
          onRefresh: _reshuffle,
        );
      },
      loading: () => const ReviewFeedSkeleton(),
      error: (error, stackTrace) {
        debugPrint('❌ Error loading community reviews: $error');
        return AppErrorState(
          title: 'Error loading community reviews',
          error: error,
          onRetry: () => ref.invalidate(communityReviewsProvider),
        );
      },
    );
  }

  void _resetPaging() {
    if (mounted) setState(() => _visibleCount = _pageSize);
  }

  Widget _feed(
    String storageKey,
    List<ReviewWithDocId> reviews, {
    required Future<void> Function() onRefresh,
  }) {
    return ReviewFeed(
      storageKey: storageKey,
      reviews: reviews.take(_visibleCount).toList(),
      hasMore: reviews.length > _visibleCount,
      onLoadMore: _loadMore,
      onRefresh: onRefresh,
      itemWrapper: _withReviewOptions,
    );
  }

  Widget _withReviewOptions(
    BuildContext context,
    ReviewWithDocId review,
    Widget card,
  ) => OwnReviewOptions(
    review: review,
    onDeleted: () => ref.invalidate(communityReviewsProvider),
    child: card,
  );
}
