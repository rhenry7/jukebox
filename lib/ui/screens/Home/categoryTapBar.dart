import 'package:flutter/material.dart';
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
  static const Duration _headerTweenDuration = Duration(milliseconds: 100);
  bool _isTabBarVisible = true;

  Widget _buildTabBarHeader() {
    return Container(
      padding: const EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 8.0,
        bottom: 24.0,
      ),
      alignment: Alignment.centerLeft,
      child: TabBar(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.red[600],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelPadding: const EdgeInsets.symmetric(horizontal: 16.0),
        tabs: const [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 6),
                Text(
                  'Friends',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 6),
                Text(
                  'Community',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 6),
                Text(
                  'For You',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
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

  bool _onScrollNotification(UserScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }

    if (notification.direction == ScrollDirection.reverse) {
      _setBarsVisible(false);
    } else if (notification.direction == ScrollDirection.forward) {
      _setBarsVisible(true);
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
                child: _buildTabBarHeader(),
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
              child: NotificationListener<UserScrollNotification>(
                onNotification: _onScrollNotification,
                child: const TabBarView(
                  children: [
                    FriendsReviewsCollection(),
                    CommunityReviewsCollection(),
                    RecommendedReviewsCollection(),
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
