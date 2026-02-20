import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test_project/MusicPreferences/spotifyRecommendations/helpers/recommendationGenerator.dart';

import '../ui/screens/DiscoveryTab/playlist_discovery.dart';
import 'explore_tracks.dart';

class DiscoveryTapBar extends StatefulWidget {
  const DiscoveryTapBar({
    super.key,
    this.onChromeVisibilityChanged,
  });

  final ValueChanged<bool>? onChromeVisibilityChanged;

  @override
  State<DiscoveryTapBar> createState() => _DiscoveryTapBarState();
}

class _DiscoveryTapBarState extends State<DiscoveryTapBar> {
  static const Duration _headerTweenDuration = Duration(milliseconds: 280);
  bool _isTabBarVisible = true;

  Widget _buildPillTab(String label) {
    return Tab(
      child: SizedBox(
        height: 42,
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBarHeader() {
    return Container(
      padding: const EdgeInsets.only(
        left: 14.0,
        right: 14.0,
        top: 8.0,
        bottom: 16.0,
      ),
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF17181D),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 18,
              spreadRadius: 1,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: TabBar(
            labelColor: const Color(0xFF17181D),
            unselectedLabelColor: Colors.white.withValues(alpha: 0.92),
            isScrollable: false,
            tabAlignment: TabAlignment.fill,
            splashFactory: NoSplash.splashFactory,
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: Colors.white,
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelPadding: EdgeInsets.zero,
            tabs: [
              _buildPillTab('Recommended'),
              _buildPillTab('Playlists'),
              _buildPillTab('Explore'),
            ],
          ),
        ),
      ),
    );
  }

  void _setChromeVisible(bool visible) {
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
      _setChromeVisible(false);
    } else if (notification.direction == ScrollDirection.forward) {
      _setChromeVisible(true);
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
                    RecommendedAlbumScreen(),
                    PlaylistDiscoveryScreen(),
                    ExploreTracks(),
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
