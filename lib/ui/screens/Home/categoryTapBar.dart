import 'package:flutter/material.dart';
import 'package:flutter_test_project/ui/theme/tokens.dart';
import 'package:flutter/rendering.dart';

import 'community_reviews.dart';
import 'friends_reviews.dart';
import 'recommended_reviews.dart';

class CategoryTapBar extends StatefulWidget {
  const CategoryTapBar({
    super.key,
    this.onChromeVisibilityChanged,
  });

  final ValueChanged<bool>? onChromeVisibilityChanged;

  @override
  State<CategoryTapBar> createState() => _CategoryTapBarState();
}

class _CategoryTapBarState extends State<CategoryTapBar> {
  static const Duration _headerTweenDuration = Duration(milliseconds: 280);
  static const double _scrollToggleThreshold = 14.0;
  static const double _topLockThreshold = 8.0;
  bool _isTabBarVisible = true;
  double _accumulatedScrollDelta = 0.0;

  Widget _buildTab(String label) => Tab(height: 36, text: label);

  /// Flat text tabs spread evenly across the width, with an underline under
  /// the selected one and a hairline divider across the page.
  Widget _buildTabBarHeader() {
    return Padding(
      // The feed already starts its first card AppSpacing.lg below the
      // divider. The top is 6px less than that because the logo's letters end
      // ~6px above the app bar's edge (at fontSize 64).
      padding: const EdgeInsets.only(top: AppSpacing.lg - 6),
      child: TabBar(
        isScrollable: false,
        tabAlignment: TabAlignment.fill,
        // Same side margins as the cards.
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageGutter),
        labelPadding: EdgeInsets.zero,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.onSurfaceVariant,
        labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        indicatorSize: TabBarIndicatorSize.label,
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: Colors.white, width: 3),
          borderRadius: BorderRadius.all(Radius.circular(2)),
        ),
        dividerColor: Colors.white.withValues(alpha: 0.12),
        dividerHeight: 1,
        tabs: [
          _buildTab('Popular'),
          _buildTab('Friends'),
          _buildTab('For You'),
        ],
      ),
    );
  }

  void _setBarsVisible(bool visible) {
    if (_isTabBarVisible == visible) {
      return;
    }
    setState(() {
      _isTabBarVisible = visible;
    });
    widget.onChromeVisibilityChanged?.call(visible);
  }

  bool _isNearTop(ScrollMetrics metrics) {
    return metrics.extentBefore <= _topLockThreshold ||
        metrics.pixels <= metrics.minScrollExtent + _topLockThreshold;
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }

    if (_isNearTop(notification.metrics)) {
      _accumulatedScrollDelta = 0.0;
      _setBarsVisible(true);
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      // Use the update's own delta: mouse-wheel / trackpad scrolling on web
      // arrives as separate start/update/end bursts per step, so comparing
      // positions between notifications always read zero there.
      final delta = notification.scrollDelta ?? 0.0;
      if (delta.abs() < 0.1) {
        return false;
      }

      final sameDirection = _accumulatedScrollDelta == 0.0 ||
          (_accumulatedScrollDelta.isNegative == delta.isNegative);
      _accumulatedScrollDelta =
          sameDirection ? (_accumulatedScrollDelta + delta) : delta;

      if (_accumulatedScrollDelta.abs() >= _scrollToggleThreshold) {
        if (_accumulatedScrollDelta > 0) {
          _setBarsVisible(false);
        } else {
          _setBarsVisible(true);
        }
        _accumulatedScrollDelta = 0.0;
      }
      return false;
    }

    // If user settles at the end of a list, bring chrome back automatically.
    // Restrict to idle to avoid animation jitter while actively dragging.
    if (notification is UserScrollNotification &&
        notification.metrics.extentAfter <= 1.0 &&
        notification.direction == ScrollDirection.idle) {
      _accumulatedScrollDelta = 0.0;
      _setBarsVisible(true);
      return false;
    }

    return false;
  }

  @override
  void dispose() {
    widget.onChromeVisibilityChanged?.call(true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      initialIndex: 0,
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            ClipRect(
              child: TweenAnimationBuilder<double>(
                duration: _headerTweenDuration,
                curve:
                    _isTabBarVisible ? Curves.easeOutCubic : Curves.easeInCubic,
                tween: Tween<double>(end: _isTabBarVisible ? 1.0 : 0.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTabBarHeader(),
                  ],
                ),
                builder: (context, value, child) {
                  final visibility = value.clamp(0.0, 1.0);
                  return Align(
                    alignment: Alignment.topCenter,
                    heightFactor: visibility == 0 ? 0.0001 : visibility,
                    child: Opacity(
                      opacity: visibility,
                      child: Transform.translate(
                        offset: Offset(0, -(1 - visibility) * 10),
                        child: child,
                      ),
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScrollNotification,
                child: TabBarView(
                  children: const [
                    CommunityReviewsCollection(selectedGenres: {}),
                    FriendsReviewsCollection(selectedGenres: {}),
                    RecommendedReviewsCollection(selectedGenres: {}),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
