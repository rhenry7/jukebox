import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/auth_provider.dart' show currentUserIdProvider;
import '../../../providers/home_feed_controls.dart';
import '../../../providers/recommended_reviews_provider.dart';
import '../../../services/review_recommendation_service.dart';
import '../Profile/helpers/profileHelpers.dart' show openSignIn;
import '../../../routing/MainNavigation.dart';

import 'package:flutter_test_project/ui/widgets/app_states.dart';
import 'package:flutter_test_project/ui/widgets/home_feed_controls.dart'
    show NoTagMatches;
import 'package:flutter_test_project/ui/widgets/reason_label.dart';
import 'package:flutter_test_project/ui/widgets/review_feed.dart';

/// "For You" tab — shows NLP-recommended community reviews
/// personalized to the user's taste profile.
class RecommendedReviewsCollection extends ConsumerStatefulWidget {
  const RecommendedReviewsCollection({super.key});

  @override
  ConsumerState<RecommendedReviewsCollection> createState() =>
      _RecommendedReviewsCollectionState();
}

class _RecommendedReviewsCollectionState
    extends ConsumerState<RecommendedReviewsCollection> {
  bool _isRefreshingRecommendations = false;

  // Tab-focus tracking — detects when the For You tab (index 2) is selected.
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    // Check on first mount in case a review was written before the tab opened.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndRefresh());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tc = DefaultTabController.of(context);
    if (_tabController != tc) {
      _tabController?.removeListener(_onTabChanged);
      _tabController = tc;
      tc.addListener(_onTabChanged);
    }
  }

  void _onTabChanged() {
    // For You is tab index 2; only act once animation has settled.
    if (_tabController?.index == 2 &&
        !(_tabController?.indexIsChanging ?? true)) {
      _checkAndRefresh();
    }
  }

  /// If a review was submitted or preferences saved since last load, re-fetch.
  void _checkAndRefresh() {
    if (!mounted) return;
    if (ReviewRecommendationService.consumeNeedsRefresh()) {
      debugPrint('[FOR_YOU] Dirty flag detected — refreshing recommendations');
      ref.invalidate(recommendedReviewsProvider);
    }
  }

  @override
  void dispose() {
    _tabController?.removeListener(_onTabChanged);
    super.dispose();
  }

  Future<void> _loadMore() async {
    ref.read(loadMoreRecommendedReviewsProvider)();
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> _fetchNewRecommendations() async {
    if (_isRefreshingRecommendations) return;
    _isRefreshingRecommendations = true;

    ref.read(recommendedReviewsDisplayLimitProvider.notifier).state = 5;
    await ref.read(refreshRecommendationsProvider)();

    _isRefreshingRecommendations = false;
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final recommendedAsync = ref.watch(recommendedReviewsProvider);
    final displayLimit = ref.watch(recommendedReviewsDisplayLimitProvider);

    // Auth gate — must be signed in for personalized recommendations
    if (userId == null) {
      return AppEmptyState(
        icon: Icons.person_off,
        title: 'Sign In Required',
        message: 'Sign in to get personalized review recommendations based on your taste!',
        action: AppStateAction(
          label: 'Sign In!',
          icon: Icons.login,
          onPressed: () {
            openSignIn(context);
          },
        ),
      );
    }

    final tags = ref.watch(homeTagFilterProvider);
    final sort = ref.watch(homeSortProvider);
    // Filtering or sorting needs the whole list, not just the loaded page.
    final narrowing = tags.isNotEmpty || sort != HomeSort.standard;
    ref.listen(homeTagFilterProvider, (_, __) => _backToFirstPage());
    ref.listen(homeSortProvider, (_, __) => _backToFirstPage());

    return recommendedAsync.when(
      // "Load more" re-runs the provider; keep the cards on screen meanwhile.
      skipLoadingOnReload: true,
      data: (feed) {
        if (feed.total == 0) {
          return AppEmptyState(
            icon: Icons.auto_awesome,
            title: 'No recommendations yet',
            message: 'Write some reviews to get personalized recommendations',
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

        if (!narrowing) {
          return _feed(
            storageKey: 'recommended_reviews_list',
            scored: feed.loaded,
            total: feed.total,
            displayLimit: displayLimit,
            onRefresh: _fetchNewRecommendations,
          );
        }

        if (displayLimit < feed.total) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ref.read(recommendedReviewsDisplayLimitProvider.notifier).state =
                  feed.total;
            }
          });
        }
        final allLoaded =
            feed.loaded.length >= feed.total ||
            !recommendedAsync.isLoading && displayLimit >= feed.total;
        final shown = applyHomeSort(
          [
            for (final s in feed.loaded)
              if (matchesTagFilter(s.reviewWithDocId.review, tags)) s,
          ],
          sort,
          (s) => s.reviewWithDocId.review,
        );
        if (shown.isEmpty) {
          return allLoaded ? const NoTagMatches() : const ReviewFeedSkeleton();
        }
        return _feed(
          storageKey: 'recommended_filtered_list',
          scored: shown,
          displayLimit: shown.length,
          onRefresh: _fetchNewRecommendations,
        );
      },
      loading: () => const ReviewFeedSkeleton(),
      error: (error, stackTrace) {
        debugPrint('Error loading recommendations: $error');
        return AppErrorState(
          title: 'Error loading recommendations',
          error: error,
          onRetry: () => ref.invalidate(recommendedReviewsProvider),
        );
      },
    );
  }

  /// A new filter or sort starts from the top; clearing both goes back to
  /// loading a page at a time.
  void _backToFirstPage() {
    final tags = ref.read(homeTagFilterProvider);
    final sort = ref.read(homeSortProvider);
    if (tags.isEmpty && sort == HomeSort.standard) {
      ref.read(recommendedReviewsDisplayLimitProvider.notifier).state = 5;
    }
  }

  /// Shows the first [displayLimit] of [scored]; scrolling raises the limit.
  /// [total] is the whole list's length when [scored] is only the part
  /// loaded so far.
  Widget _feed({
    required String storageKey,
    required List<ScoredReview> scored,
    int? total,
    required int displayLimit,
    required Future<void> Function() onRefresh,
  }) {
    final displayed = scored.take(displayLimit);
    final reasons = {
      for (final s in scored)
        if (s.reason case final reason? when reason.isNotEmpty)
          s.reviewWithDocId.fullReviewId: reason,
    };
    return ReviewFeed(
      storageKey: storageKey,
      reviews: [for (final s in displayed) s.reviewWithDocId],
      hasMore: (total ?? scored.length) > displayLimit,
      onLoadMore: _loadMore,
      onRefresh: onRefresh,
      itemWrapper: (context, review, card) =>
          WithReason(reason: reasons[review.fullReviewId], child: card),
    );
  }
}
