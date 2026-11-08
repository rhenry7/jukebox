import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/services/demo_auto_sign_in.dart';
import 'package:flutter_test_project/ui/theme/tokens.dart';
import 'package:flutter_test_project/ui/widgets/review_feed.dart';
import 'package:flutter_test_project/ui/screens/Home/categoryTapBar.dart';
import 'package:flutter_test_project/ui/screens/Profile/helpers/profileHelpers.dart';
import 'package:flutter_test_project/ui/screens/addReview/reviewSheetContentForm.dart';
import 'package:flutter_test_project/providers/auth_provider.dart';
import 'package:flutter_test_project/services/data_preloader.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ionicons/ionicons.dart';
import 'package:flutter_test_project/ui/screens/search/search_screen.dart';
import 'package:flutter_test_project/ui/screens/Profile/ProfileButton.dart';

class MainNav extends ConsumerStatefulWidget {
  const MainNav({super.key, required this.title});
  final String title;

  @override
  ConsumerState<MainNav> createState() => MainNavState();
}

/// Looping neon-sign glow effect for the app bar title.
///
/// Mimics an old neon tube by cycling through three states:
///   bright  → dim flicker  → bright  → dim  → repeat
/// The shadow blur radius and opacity shift together so the "tube"
/// appears to pulse and occasionally stutter like aging neon.
class _NeonTitle extends StatelessWidget {
  const _NeonTitle();

  // Dim glow — tube at rest
  static const TextStyle _dimStyle = TextStyle(
    color: Color(0xFFCC1111),
    shadows: [
      Shadow(blurRadius: 4, color: Color(0x88CC0000)),
      Shadow(blurRadius: 8, color: Color(0x44CC0000)),
    ],
  );

  // Bright glow — tube fully lit
  static const TextStyle _brightStyle = TextStyle(
    color: Color.fromARGB(255, 214, 30, 30),
    shadows: [
      Shadow(blurRadius: 12, color: Color.fromARGB(172, 221, 25, 25)),
      Shadow(blurRadius: 24, color: Color.fromARGB(153, 187, 12, 12)),
      Shadow(blurRadius: 40, color: Color(0x55FF2200)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final base = Text(
      'REVERB',
      style: GoogleFonts.gasoekOne(textStyle: _dimStyle),
    );

    // Shrinks the logo to fit the space between the menu and search buttons
    // on narrow screens; never grows it past the app bar's font size.
    return FittedBox(
        fit: BoxFit.scaleDown,
        child: base
            // Slow fade up to full brightness
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .custom(
              duration: 2800.ms,
              curve: Curves.easeInOut,
              builder: (context, value, child) {
                // value goes 0 → 1 → 0 on each cycle
                final style = TextStyle.lerp(_dimStyle, _brightStyle, value)!;
                return Text(
                  'REVERB',
                  style: GoogleFonts.gasoekOne(textStyle: style),
                );
              },
            )
            // Brief stutter flicker on top — like a dying neon tube
            .then(delay: 1400.ms)
            .shimmer(
              duration: 120.ms,
              color: const Color.fromARGB(61, 172, 49, 49),
              angle: 0,
            ));
  }
}

class MainNavState extends ConsumerState<MainNav> {
  static const Duration _bottomNavTweenDuration = Duration(milliseconds: 260);

  int currentPageIndex = 0;
  bool _isNavigationChromeVisible = true;
  final TextEditingController _controller = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final List<Widget> _pages;

  /// Bottom nav destinations, in order.
  static const int homeTab = 0;
  static const int addTab = 1;
  static const int profileTab = 2;

  void _onItemTapped(int index) {
    if (index == addTab) {
      // The add button opens the review sheet instead of switching tabs
      showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (BuildContext context) {
            //initialChildSize: 0.9; // Takes up 90% of the screen

            return const MyReviewSheetContentForm(
              title: 'track-title',
              artist: 'artist',
              albumImageUrl: '',
            );
          });
    } else if (index == homeTab && currentPageIndex == homeTab) {
      // Already home: back to the top of the feed, refreshed.
      setState(() => _isNavigationChromeVisible = true);
      ReviewFeed.scrollToTopAndRefresh();
    } else {
      setState(() {
        currentPageIndex = index;
        _isNavigationChromeVisible = true;
      });
    }
  }

  void _onChromeVisibilityChanged(bool visible) {
    if (!mounted || currentPageIndex != homeTab) {
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
      const MyReviewSheetContentForm(
        title: 'track-title',
        artist: 'artist',
        albumImageUrl: '',
      ),
      profileRouter(),
    ];
  }

  Widget _buildTopBar(BuildContext context) {
    return AppBar(
      backgroundColor: const Color.fromARGB(4, 131, 131, 131),
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: InkWell(
          borderRadius: BorderRadius.circular(50),
          onTap: () => _scaffoldKey.currentState?.openDrawer(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[850],
            ),
            child: const Icon(Icons.menu, color: Colors.white, size: 22),
          ),
        ),
      ),
      title: const _NeonTitle(),
      titleTextStyle: const TextStyle(color: Colors.white, fontSize: 64),
      toolbarHeight: 70.0,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(50),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[850],
              ),
              child: const Icon(Icons.search, color: Colors.white, size: 22),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      drawer: _AppDrawer(),
      // Lighter than the default, so the glass drawer has the feed to blur.
      drawerScrimColor: Colors.black26,
      // The top bar sits in the body (not Scaffold.appBar) so it can fade and
      // collapse with the bottom dock when the feed scrolls down, instead of
      // popping out and making the page jump.
      body: Column(
        children: [
          TweenAnimationBuilder<double>(
            duration: _bottomNavTweenDuration,
            curve: _isNavigationChromeVisible
                ? Curves.easeOutCubic
                : Curves.easeInCubic,
            tween: Tween<double>(end: _isNavigationChromeVisible ? 1.0 : 0.0),
            child: _buildTopBar(context),
            builder: (context, value, child) {
              final visibility = value.clamp(0.0, 1.0);
              return ClipRect(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  heightFactor: visibility == 0 ? 0.0001 : visibility,
                  child: IgnorePointer(
                    ignoring: visibility < 0.05,
                    child: Opacity(opacity: visibility, child: child),
                  ),
                ),
              );
            },
          ),
          Expanded(
            // The top bar already pads for the status bar / notch; don't let
            // the pages pad for it again.
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: DataPreloader(child: _pages[currentPageIndex]),
            ),
          ),
        ],
      ),
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
          minimum: const EdgeInsets.fromLTRB(15, 0, 15, 12),
          child: Center(
            heightFactor: 1,
            child: _GlassDock(
              selectedIndex: currentPageIndex,
              onSelected: _onItemTapped,
            ),
          ),
        ),
        builder: (context, value, child) {
          final visibility = value.clamp(0.0, 1.0);
          // Fully shown: no clip, so the dock's shadow isn't cut off.
          if (visibility == 1) return child!;
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

// ── Bottom dock ───────────────────────────────────────────────────────────────

/// The floating nav dock (design_system.md → "The Floating Dock"): a frosted
/// glass pill holding three identical circular buttons, evenly spaced.
class _GlassDock extends StatelessWidget {
  const _GlassDock({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Every button gets the same round hit area, so the three line up exactly
  /// and the gaps between them are equal.
  static const double buttonSize = 56;
  static const double _gap = AppSpacing.lg;
  static const double _inset = AppSpacing.sm;
  static const BorderRadius _shape = AppRadius.pillAll;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      // Outside the clip, so the shadow lifts the dock off the feed.
      decoration: const BoxDecoration(
        borderRadius: _shape,
        boxShadow: [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: _shape,
        child: BackdropFilter(
          // Blur plus a little extra saturation, so colours behind the glass
          // glow through instead of turning grey.
          filter: ImageFilter.compose(
            outer: const ColorFilter.matrix(_saturate),
            inner: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: _shape,
              // Tinted glass, lighter at the top where light catches it.
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.surfaceContainerHighest.withValues(alpha: 0.62),
                  AppColors.surfaceContainerHighest.withValues(alpha: 0.48),
                ],
              ),
              border: Border.all(color: AppColors.ghostBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(_inset),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DockButton(
                    tooltip: 'Home',
                    selected: selectedIndex == MainNavState.homeTab,
                    icon: Ionicons.home_outline,
                    selectedIcon: Ionicons.home,
                    onTap: () => onSelected(MainNavState.homeTab),
                  ),
                  const SizedBox(width: _gap),
                  _DockButton(
                    tooltip: 'New review',
                    selected: false, // An action, never a tab.
                    icon: Ionicons.add_circle_outline,
                    selectedIcon: Ionicons.add_circle_outline,
                    iconSize: 34,
                    color: Colors.greenAccent[700],
                    onTap: () => onSelected(MainNavState.addTab),
                  ),
                  const SizedBox(width: _gap),
                  _DockButton(
                    tooltip: 'Profile',
                    selected: selectedIndex == MainNavState.profileTab,
                    icon: Ionicons.person_circle_outline,
                    selectedIcon: Ionicons.person_circle,
                    onTap: () => onSelected(MainNavState.profileTab),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Saturation 1.3 (standard luminance weights).
  static const List<double> _saturate = [
    1.2364, -0.2145, -0.0219, 0, 0, //
    -0.0636, 1.0855, -0.0219, 0, 0,
    -0.0636, -0.2145, 1.2781, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.tooltip,
    required this.selected,
    required this.icon,
    required this.selectedIcon,
    required this.onTap,
    this.iconSize = 28,
    this.color,
  });

  final String tooltip;
  final bool selected;
  final IconData icon;
  final IconData selectedIcon;
  final VoidCallback onTap;
  final double iconSize;

  /// Fixed colour (the add button); otherwise white when selected, grey not.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: tooltip,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: Material(
          // The selected tab sits in a soft lighter circle.
          color: selected
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox.square(
              dimension: _GlassDock.buttonSize,
              child: Icon(
                selected ? selectedIcon : icon,
                size: iconSize,
                color: color ??
                    (selected ? Colors.white : AppColors.onSurfaceVariant),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── App drawer (hamburger menu) ───────────────────────────────────────────────

class _AppDrawer extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Log out and Delete Account only mean something when signed in, and
    // the shared demo account can't be deleted.
    final user = ref.watch(currentUserProvider);
    final signedIn = user != null;
    final canDeleteAccount = signedIn && !DemoAutoSignIn.isDemoUser(user.email);
    const shape = BorderRadius.horizontal(right: Radius.circular(AppRadius.xl));
    return Drawer(
      // Frosted glass, like the dock: the feed shows through, blurred.
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: shape),
      clipBehavior: Clip.antiAlias,
      width: MediaQuery.of(context).size.width * 0.82,
      child: BackdropFilter(
        filter: ImageFilter.compose(
          outer: const ColorFilter.matrix(_GlassDock._saturate),
          inner: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: shape,
            // Tinted glass, lit from the top-left.
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(Colors.white.withValues(alpha: 0.08),
                    AppColors.surfaceContainerHighest.withValues(alpha: 0.62)),
                AppColors.surfaceContainerHighest.withValues(alpha: 0.48),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  const Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 24),
                    child: Text(
                      'MENU',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                  ),

                  // Settings card
                  Card(
                    color: Colors.grey[900],
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                          color: Colors.white.withOpacity(0.1), width: 1),
                    ),
                    child: Column(
                      children: [
                        const ProfileButton(
                          name: 'Notifications',
                          icon: Ionicons.notifications_outline,
                        ),
                        Divider(
                            color: Colors.white.withOpacity(0.05), height: 1),
                        const ProfileButton(
                          name: 'Legal',
                          icon: Ionicons.document_text_outline,
                        ),
                        if (signedIn) ...[
                          Divider(
                              color: Colors.white.withOpacity(0.05), height: 1),
                          const ProfileButton(
                            name: 'LogOut',
                            icon: Ionicons.exit_outline,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Danger zone
                  if (canDeleteAccount)
                    Card(
                      color: Colors.red.withOpacity(0.08),
                      elevation: 0,
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                            color: Colors.red.withOpacity(0.25), width: 1),
                      ),
                      child: const ProfileButton(
                        name: 'Delete Account',
                        icon: Ionicons.trash_outline,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
