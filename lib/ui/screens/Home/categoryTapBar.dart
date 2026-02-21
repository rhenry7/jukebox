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
  static const Duration _headerTweenDuration = Duration(milliseconds: 280);
  static const double _scrollToggleThreshold = 14.0;
  static const List<String> _genreOptions = <String>[
    'All',
    'Chill',
    'Rap',
    'Rock',
    'Electronic',
    'Classy',
    'Reggae',
    'Soul Funk',
    'Jazz',
    'Acoustic',
  ];

  bool _isTabBarVisible = true;
  final Set<String> _selectedGenres = <String>{};
  double _accumulatedScrollDelta = 0.0;
  double? _lastScrollPixels;

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
          color: Colors.white10,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Colors.white.withOpacity(0.12),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.28),
              blurRadius: 18,
              spreadRadius: 1,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: TabBar(
            labelColor: Colors.black,
            unselectedLabelColor: Colors.white.withOpacity(0.92),
            isScrollable: false,
            tabAlignment: TabAlignment.fill,
            splashFactory: NoSplash.splashFactory,
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: Colors.grey.shade300,
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelPadding: EdgeInsets.zero,
            tabs: [
              _buildPillTab('Friends'),
              _buildPillTab('Community'),
              _buildPillTab('For You'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenreFilterRow() {
    return Container(
      padding: const EdgeInsets.only(
        left: 14.0,
        right: 14.0,
        bottom: 12.0,
      ),
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _genreOptions.map((genre) {
            final key = genre.toLowerCase();
            final selected = key == 'all'
                ? _selectedGenres.isEmpty
                : _selectedGenres.contains(key);

            return Padding(
              padding: const EdgeInsets.only(right: 10.0),
              child: FilterChip(
                label: Text(
                  genre,
                  style: TextStyle(
                    color: selected ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                selected: selected,
                onSelected: (_) => _toggleGenreFilter(genre),
                showCheckmark: false,
                backgroundColor: Colors.white10,
                selectedColor: Colors.grey.shade300,
                side: BorderSide(
                  color: Colors.white.withOpacity(0.12),
                  width: 0.8,
                ),
                shape: const StadiumBorder(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _toggleGenreFilter(String genre) {
    final key = genre.toLowerCase();
    setState(() {
      if (key == 'all') {
        _selectedGenres.clear();
        return;
      }

      if (_selectedGenres.contains(key)) {
        _selectedGenres.remove(key);
      } else {
        _selectedGenres.add(key);
      }
    });
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

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }

    if (notification is ScrollStartNotification) {
      _lastScrollPixels = notification.metrics.pixels;
      _accumulatedScrollDelta = 0.0;
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      final currentPixels = notification.metrics.pixels;
      final lastPixels = _lastScrollPixels;
      _lastScrollPixels = currentPixels;
      if (lastPixels == null) {
        return false;
      }

      final delta = currentPixels - lastPixels;
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

    if (notification is ScrollEndNotification) {
      _accumulatedScrollDelta = 0.0;
      _lastScrollPixels = null;
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
                    _buildGenreFilterRow(),
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
                  children: [
                    FriendsReviewsCollection(
                      selectedGenres: Set<String>.from(_selectedGenres),
                    ),
                    CommunityReviewsCollection(
                      selectedGenres: Set<String>.from(_selectedGenres),
                    ),
                    RecommendedReviewsCollection(
                      selectedGenres: Set<String>.from(_selectedGenres),
                    ),
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
