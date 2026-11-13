import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../providers/reviews_provider.dart' show ReviewWithDocId;
import '../theme/tokens.dart';
import 'app_states.dart';
import 'review_card.dart';
import 'skeleton_loader.dart';

/// Where a [ReviewFeed] sits, which decides its outer spacing.
enum ReviewFeedLayout {
  /// A tab under the floating nav dock — bottom padding clears the dock.
  tab,

  /// A pushed full-screen page with no dock.
  pushed,
}

/// The one widget that lays out a scrollable list of review cards.
///
/// Owns everything about list presentation: page gutter, card gap, top and
/// bottom spacing, pull-to-refresh, infinite scroll and the loading footer.
/// Screens only supply data and callbacks — never padding.
///
/// For the loading state use [ReviewFeedSkeleton]; for empty / error states
/// use [AppEmptyState] / [AppErrorState].
class ReviewFeed extends StatefulWidget {
  const ReviewFeed({
    super.key,
    required this.reviews,
    required this.onRefresh,
    required this.storageKey,
    this.onLoadMore,
    this.hasMore = false,
    this.layout = ReviewFeedLayout.tab,
    this.itemWrapper,
    this.reasonFor,
  });

  final List<ReviewWithDocId> reviews;
  final Future<void> Function() onRefresh;

  /// Called when the user scrolls near the bottom and [hasMore] is true.
  final Future<void> Function()? onLoadMore;
  final bool hasMore;

  /// Preserves scroll position across tab switches.
  final String storageKey;
  final ReviewFeedLayout layout;

  /// Wraps each card (e.g. in a Dismissible). Must not add padding.
  final Widget Function(
      BuildContext context, ReviewWithDocId review, Widget card)? itemWrapper;

  /// Why each review is shown (For You), drawn at the top of its card.
  final String? Function(ReviewWithDocId review)? reasonFor;

  /// Tells the [ReviewFeedLayout.tab] feed on screen to scroll to the top
  /// and refresh (the Home button tapped while already on Home).
  static void scrollToTopAndRefresh() => _homeReselected.value++;
  static final ValueNotifier<int> _homeReselected = ValueNotifier(0);

  @override
  State<ReviewFeed> createState() => _ReviewFeedState();
}

class _ReviewFeedState extends State<ReviewFeed> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey();
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (widget.layout == ReviewFeedLayout.tab) {
      ReviewFeed._homeReselected.addListener(_onHomeReselected);
    }
  }

  @override
  void dispose() {
    ReviewFeed._homeReselected.removeListener(_onHomeReselected);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore || !widget.hasMore || widget.onLoadMore == null) return;
    final position = _scrollController.position;
    // Load more only while actively scrolling down near the bottom.
    if (position.userScrollDirection == ScrollDirection.reverse &&
        position.pixels >= position.maxScrollExtent * 0.8) {
      _loadMore();
    }
  }

  Future<void> _onHomeReselected() async {
    if (!_isOnScreen() || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels > 0) {
      // Long way down: jump most of it so the trip back stays short.
      if (position.pixels > position.viewportDimension * 3) {
        _scrollController.jumpTo(position.viewportDimension);
      }
      await _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic);
    }
    if (mounted) await _refreshKey.currentState?.show();
  }

  /// Whether this is the Home tab being looked at: the current route, and
  /// not a neighbouring tab kept alive off to the side.
  bool _isOnScreen() {
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    final box = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
    if (box == null || !box.attached || overlay == null) return false;
    final dx = box.localToGlobal(Offset.zero, ancestor: overlay).dx;
    return dx.abs() < box.size.width / 2;
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    await widget.onLoadMore!();
    if (mounted) setState(() => _isLoadingMore = false);
  }

  @override
  Widget build(BuildContext context) {
    final reviews = widget.reviews;
    // On Home the tabs float over the feed; they report their height as
    // the top padding, and the feed starts (and refreshes) below them.
    final topInset = MediaQuery.paddingOf(context).top;

    return RefreshIndicator(
      key: _refreshKey,
      onRefresh: widget.onRefresh,
      color: AppColors.primary,
      edgeOffset: topInset,
      child: ListView.builder(
        key: PageStorageKey(widget.storageKey),
        // Cache more items to prevent scroll jumps.
        scrollCacheExtent: const ScrollCacheExtent.pixels(500),
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: reviewFeedPadding(widget.layout, topInset: topInset),
        itemCount: reviews.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == reviews.length) return const AppLoadingFooter();

          final review = reviews[index];
          final Widget card = ReviewCardWithGenres(
            // Keyed by review, so a refresh or reshuffle never hands one
            // review's card state (tags, loading) to another.
            key: ValueKey(review.fullReviewId ?? review.docId),
            review: review.review,
            reviewId: review.fullReviewId,
            showLikeButton: true,
            reason: widget.reasonFor?.call(review),
          );
          return Padding(
            padding: AppSpacing.cardListItem,
            child: widget.itemWrapper?.call(context, review, card) ?? card,
          );
        },
      ),
    );
  }
}

/// Placeholder cards with the same spacing as [ReviewFeed], so nothing
/// shifts when the real cards arrive.
class ReviewFeedSkeleton extends StatelessWidget {
  const ReviewFeedSkeleton({super.key, this.layout = ReviewFeedLayout.tab});

  final ReviewFeedLayout layout;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: reviewFeedPadding(
        layout,
        topInset: MediaQuery.paddingOf(context).top,
      ),
      itemCount: 3,
      itemBuilder: (_, __) => const ReviewCardSkeleton(),
    );
  }
}

/// Outer list padding. Each card adds [AppSpacing.cardGap] / 2 above and
/// below, so the first card sits [AppSpacing.lg] below the top edge, plus
/// [topInset] (a header floating over the feed, e.g. Home's tabs).
EdgeInsets reviewFeedPadding(ReviewFeedLayout layout, {double topInset = 0}) {
  return EdgeInsets.only(
    top: topInset + AppSpacing.lg - AppSpacing.cardGap / 2,
    bottom: switch (layout) {
      ReviewFeedLayout.tab => AppSpacing.dockClearance,
      ReviewFeedLayout.pushed => AppSpacing.lg,
    },
  );
}
