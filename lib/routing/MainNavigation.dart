import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/DiscoveryTab/discoveryTapBar.dart';
import 'package:flutter_test_project/ui/screens/Home/categoryTapBar.dart';
import 'package:flutter_test_project/ui/screens/Profile/helpers/profileHelpers.dart';
import 'package:flutter_test_project/ui/screens/Trending/trending_tracks.dart';
import 'package:flutter_test_project/models/music_preferences.dart';
import 'package:flutter_test_project/ui/screens/addReview/reviewSheetContentForm.dart';
import 'package:flutter_test_project/providers/auth_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ionicons/ionicons.dart';

class MainNav extends ConsumerStatefulWidget {
  const MainNav(
      {super.key, required this.title, this.navigateToPreferences = false});
  final String title;
  final bool navigateToPreferences;

  @override
  ConsumerState<MainNav> createState() => MainNavState();
}

class MainNavState extends ConsumerState<MainNav> {
  static const Duration _bottomNavTweenDuration = Duration(milliseconds: 260);
  int currentPageIndex = 0;
  bool _isNavigationChromeVisible = true;
  final TextEditingController _controller = TextEditingController();
  late Future<MusicPreferences?> _preferencesFuture;
  late final List<Widget> _pages;

  void _onItemTapped(int index) {
    if (index == 2) {
      // Assume the third item triggers the bottom sheet
      showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (BuildContext context) {
            initialChildSize:
            0.9; // Takes up 90% of the screen

            return const MyReviewSheetContentForm(
              title: 'track-title',
              artist: 'artist',
              albumImageUrl: '',
            );
          });
    } else {
      setState(() {
        currentPageIndex = index;
        _isNavigationChromeVisible = true;
      });
    }
  }

  void _onChromeVisibilityChanged(bool visible) {
    if (!mounted || (currentPageIndex != 0 && currentPageIndex != 1)) {
      return;
    }
    if (_isNavigationChromeVisible == visible) {
      return;
    }
    setState(() {
      _isNavigationChromeVisible = visible;
    });
  }

  // Public method to change tab from child widgets
  void navigateToTab(int index) {
    _onItemTapped(index);
  }

  // Get profile label - show username if logged in, otherwise "Profile"
  String _getProfileLabel() {
    //TODO: handle username display so that text doesn't overflow
    // final user = ref.read(currentUserProvider);
    // if (user != null &&
    //     user.displayName != null &&
    //     user.displayName!.isNotEmpty) {
    //   return user.displayName!;
    // }
    return 'Profile';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _pages = [
      CategoryTapBar(onChromeVisibilityChanged: _onChromeVisibilityChanged),
      DiscoveryTapBar(onChromeVisibilityChanged: _onChromeVisibilityChanged),
      const MyReviewSheetContentForm(
        title: 'track-title',
        artist: 'artist',
        albumImageUrl: '',
      ),
      const TrendingTracksWidget(),
      profileRouter(),
    ];
    // If navigateToPreferences is true, navigate after first frame
    if (widget.navigateToPreferences) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Navigate to profile tab first
          setState(() {
            currentPageIndex = 4;
          });
          // Then navigate to preferences
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => Scaffold(
                    body: profileRoute('Preferences'),
                  ),
                ),
              );
            }
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: _isNavigationChromeVisible
          ? AppBar(
              backgroundColor: const Color.fromARGB(4, 131, 131, 131),
              elevation: 0,
              title: Padding(
                padding: const EdgeInsets.all(0.0),
                child: Text(
                  'MIXTAKES',
                  style: GoogleFonts.gasoekOne(
                    textStyle: TextStyle(
                      color: Colors.red,
                      shadows: [
                        Shadow(
                          blurRadius: 15.0, // shadow blur
                          color: Colors.red[600]!, // shadow color
                          offset: const Offset(2.0, 2.0), // shadow displacement
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              titleTextStyle:
                  const TextStyle(color: Colors.white, fontSize: 46),
              toolbarHeight: 70.0,
            )
          : null,
      body: _pages[currentPageIndex],
      bottomNavigationBar: TweenAnimationBuilder<double>(
        duration: _bottomNavTweenDuration,
        curve: _isNavigationChromeVisible
            ? Curves.easeOutCubic
            : Curves.easeInCubic,
        tween: Tween<double>(end: _isNavigationChromeVisible ? 1.0 : 0.0),
        child: SafeArea(
          top: false,
          left: false,
          right: false,
          minimum: const EdgeInsets.all(15),
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(100)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withOpacity(0.18),
                      width: 0.8,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.03),
                      blurRadius: 18,
                      spreadRadius: 0.5,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: NavigationBar(
                  onDestinationSelected: _onItemTapped,
                  selectedIndex: currentPageIndex,
                  indicatorColor: Colors.white.withOpacity(0.7),
                  indicatorShape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(16), // Set the border radius
                  ),
                  backgroundColor: Colors.transparent,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
                  destinations: <Widget>[
                    const NavigationDestination(
                      selectedIcon: Icon(Ionicons.home),
                      icon: Icon(Ionicons.home_outline),
                      label: '',
                    ),
                    const NavigationDestination(
                      selectedIcon: Icon(Ionicons.planet_outline),
                      icon: Icon(Ionicons.planet),
                      label: '',
                    ),
                    NavigationDestination(
                      selectedIcon: Icon(Ionicons.add_circle,
                          size: 30.0, color: Colors.greenAccent[700]),
                      icon: Icon(Ionicons.add_circle_outline,
                          size: 40, color: Colors.greenAccent[700]),
                      label: '',
                    ),
                    const NavigationDestination(
                      selectedIcon: Icon(Ionicons.flash),
                      icon: Icon(Ionicons.flash_outline),
                      label: '',
                    ),
                    const NavigationDestination(
                      selectedIcon: Icon(Ionicons.person_circle),
                      icon: Icon(Ionicons.person_circle_outline),
                      label: '',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        builder: (context, value, child) {
          final visibility = value.clamp(0.0, 1.0);
          return ClipRect(
            child: Align(
              alignment: Alignment.bottomCenter,
              heightFactor: visibility == 0 ? 0.0001 : visibility,
              child: IgnorePointer(
                ignoring: visibility < 0.05,
                child: Opacity(
                  opacity: visibility,
                  child: Transform.translate(
                    offset: Offset(0, (1 - visibility) * 40),
                    child: child,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
