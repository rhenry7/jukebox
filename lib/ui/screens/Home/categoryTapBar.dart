import 'package:flutter/material.dart';
import 'package:flutter_test_project/ui/theme/tokens.dart';
import 'package:flutter_test_project/ui/widgets/home_feed_controls.dart';
import 'package:flutter_test_project/ui/widgets/round_icon_button.dart';
import 'package:flutter_test_project/ui/screens/search/search_screen.dart';
import 'package:flutter/rendering.dart';

import 'community_reviews.dart';
import 'friends_reviews.dart';
import 'recommended_reviews.dart';

class CategoryTapBar extends StatefulWidget {
  const CategoryTapBar({
    super.key,
    this.onChromeVisibilityChanged,
    this.onOpenMenu,
  });

  final ValueChanged<bool>? onChromeVisibilityChanged;

  /// Opens the side menu (MainNav's drawer).
  final VoidCallback? onOpenMenu;

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

  /// The Home header: side-menu button, the three tabs (flat text, evenly
  /// spread, underline under the selected one), search button.
  Widget _buildTabBarHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageGutter,
        AppSpacing.sm,
        AppSpacing.pageGutter,
        0,
      ),
      child: Row(
        children: [
          RoundIconButton(
            icon: Icons.menu,
            tooltip: 'Menu',
            onTap: () => widget.onOpenMenu?.call(),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: _buildTabs()),
          const SizedBox(width: AppSpacing.sm),
          RoundIconButton(
            icon: Icons.search,
            tooltip: 'Search',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return TabBar(
        isScrollable: false,
        tabAlignment: TabAlignment.fill,
        labelPadding: EdgeInsets.zero,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.onSurfaceVariant,
        labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        indicatorSize: TabBarIndicatorSize.label,
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: Colors.white, width: 3),
          borderRadius: BorderRadius.all(Radius.circular(2)),
        ),
        dividerColor: Colors.transparent,
        dividerHeight: 0,
        tabs: [
          _buildTab('Popular'),
          _buildTab('Friends'),
          _buildTab('For You'),
        ],
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

      final sameDirection =
          _accumulatedScrollDelta == 0.0 ||
          (_accumulatedScrollDelta.isNegative == delta.isNegative);
      _accumulatedScrollDelta = sameDirection
          ? (_accumulatedScrollDelta + delta)
          : delta;

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

  /// Height of the floating header (status bar + tabs + tag row), measured.
  /// Only grows, so collapsing the header never shifts the feed.
  double _headerHeight = 0;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return DefaultTabController(
      initialIndex: 0,
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // The feed fills the screen and scrolls under the header; its
            // top padding is the header's height, so it starts below it.
            Positioned.fill(
              child: MediaQuery(
                data: mq.copyWith(
                  padding: mq.padding.copyWith(top: _headerHeight),
                ),
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onScrollNotification,
                  child: const TabBarView(
                    children: [
                      CommunityReviewsCollection(),
                      FriendsReviewsCollection(),
                      RecommendedReviewsCollection(),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _ReportHeight(
                onHeight: (h) {
                  if (h > _headerHeight) setState(() => _headerHeight = h);
                },
                // A see-through dark tint, no blur: at this darkness a blur
                // was barely visible but cost a full-width backdrop pass on
                // every scroll frame.
                child: DecoratedBox(
                  decoration: const BoxDecoration(gradient: _headerTint),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Status bar / notch; stays when the header collapses.
                      SizedBox(height: mq.padding.top),
                      ClipRect(
                        child: TweenAnimationBuilder<double>(
                          duration: _headerTweenDuration,
                          curve: _isTabBarVisible
                              ? Curves.easeOutCubic
                              : Curves.easeInCubic,
                          tween:
                              Tween<double>(end: _isTabBarVisible ? 1.0 : 0.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildTabBarHeader(),
                              // Tag filters and sort for all three tabs;
                              // hides with the tabs while scrolling down.
                              const Padding(
                                padding: EdgeInsets.only(
                                  top: AppSpacing.lg,
                                  bottom: AppSpacing.md,
                                ),
                                child: HomeFeedControls(),
                              ),
                            ],
                          ),
                          builder: (context, value, child) {
                            final visibility = value.clamp(0.0, 1.0);
                            return Align(
                              alignment: Alignment.topCenter,
                              heightFactor:
                                  visibility == 0 ? 0.0001 : visibility,
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
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Black at 85% at the top, fading to 80% at the bottom: cards scrolling
  /// underneath show faintly through.
  static const LinearGradient _headerTint = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xD9000000), Color(0xCC000000)],
  );
}

/// Reports its child's height after each layout.
class _ReportHeight extends SingleChildRenderObjectWidget {
  const _ReportHeight({required this.onHeight, required super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderReportHeight(onHeight);

  @override
  void updateRenderObject(
          BuildContext context, _RenderReportHeight renderObject) =>
      renderObject.onHeight = onHeight;
}

class _RenderReportHeight extends RenderProxyBox {
  _RenderReportHeight(this.onHeight);

  ValueChanged<double> onHeight;
  double? _last;

  @override
  void performLayout() {
    super.performLayout();
    final h = size.height;
    if (h != _last) {
      _last = h;
      WidgetsBinding.instance.addPostFrameCallback((_) => onHeight(h));
    }
  }
}
