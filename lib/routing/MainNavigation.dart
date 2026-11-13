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
import 'package:ionicons/ionicons.dart';
import 'package:flutter_test_project/ui/screens/search/search_screen.dart';
import 'package:flutter_test_project/ui/screens/Profile/ProfileButton.dart';
import 'package:flutter_test_project/ui/widgets/glass.dart';
import 'package:flutter_test_project/ui/widgets/round_icon_button.dart';
import 'package:flutter_test_project/ui/widgets/auth_gate_modal.dart';

class MainNav extends ConsumerStatefulWidget {
  const MainNav({super.key, required this.title});
  final String title;

  @override
  ConsumerState<MainNav> createState() => MainNavState();
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
        },
      );
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
      // Home draws its own header row (menu, tabs, search) instead of the
      // REVERB bar.
      CategoryTapBar(
        onChromeVisibilityChanged: _onChromeVisibilityChanged,
        onOpenMenu: _openMenu,
      ),
      const MyReviewSheetContentForm(
        title: 'track-title',
        artist: 'artist',
        albumImageUrl: '',
      ),
      profileRouter(),
    ];
  }

  void _openMenu() => _scaffoldKey.currentState?.openDrawer();

  Widget _buildTopBar(BuildContext context) {
    return AppBar(
      backgroundColor: const Color.fromARGB(4, 131, 131, 131),
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Center(
          child: RoundIconButton(
            icon: Icons.menu,
            tooltip: 'Menu',
            onTap: _openMenu,
          ),
        ),
      ),
      // Profile: menu, then a wide "Search your reviews" bar.
      toolbarHeight: 56.0,
      titleSpacing: AppSpacing.sm,
      title: const _MyReviewsSearchBar(),
      actions: const [SizedBox(width: 12)],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Home has its own header (menu · tabs · search); other pages get the
    // REVERB bar.
    final showTopBar = currentPageIndex != homeTab;
    // While typing, the dock gets out of the way of the keyboard and fields.
    final typing = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      // Only the page with the text field makes room for the keyboard (its
      // own Scaffold or scroll view); the shell doesn't shrink as well, which
      // on iPhones left almost no height for the page (a black screen under
      // the top bar).
      resizeToAvoidBottomInset: false,
      drawer: _AppDrawer(),
      // Lighter than the default, so the glass drawer has the feed to blur.
      drawerScrimColor: Colors.black26,
      // The top bar sits in the body (not Scaffold.appBar) so it can fade and
      // collapse with the bottom dock when the feed scrolls down, instead of
      // popping out and making the page jump.
      body: Column(
        children: [
          if (showTopBar)
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
            // the pages pad for it again. Home pads for it itself.
            child: MediaQuery.removePadding(
              context: context,
              removeTop: showTopBar,
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
        tween: Tween<double>(
          end: _isNavigationChromeVisible && !typing ? 1.0 : 0.0,
        ),
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
    return GlassSurface(
      borderRadius: _shape,
      shadow: true,
      child: Padding(
        padding: const EdgeInsets.all(_inset),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DockButton(
              tooltip: 'Home',
              selected: selectedIndex == MainNavState.homeTab,
              icon: Ionicons.homeOutline,
              selectedIcon: Ionicons.home,
              onTap: () => onSelected(MainNavState.homeTab),
            ),
            const SizedBox(width: _gap),
            _DockButton(
              tooltip: 'New review',
              selected: false, // An action, never a tab.
              icon: Ionicons.addCircleOutline,
              selectedIcon: Ionicons.addCircleOutline,
              iconSize: 34,
              color: Colors.greenAccent[700],
              onTap: () => onSelected(MainNavState.addTab),
            ),
            const SizedBox(width: _gap),
            _DockButton(
              tooltip: 'Profile',
              selected: selectedIndex == MainNavState.profileTab,
              icon: Ionicons.personCircleOutline,
              selectedIcon: Ionicons.personCircle,
              onTap: () => onSelected(MainNavState.profileTab),
            ),
          ],
        ),
      ),
    );
  }
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
                color:
                    color ??
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
      child: GlassSurface(
        borderRadius: shape,
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
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      const ProfileButton(
                        name: 'Notifications',
                        icon: Ionicons.notificationsOutline,
                      ),
                      Divider(
                        color: Colors.white.withValues(alpha: 0.05),
                        height: 1,
                      ),
                      const ProfileButton(
                        name: 'Legal',
                        icon: Ionicons.documentTextOutline,
                      ),
                      if (signedIn) ...[
                        Divider(
                          color: Colors.white.withValues(alpha: 0.05),
                          height: 1,
                        ),
                        const ProfileButton(
                          name: 'LogOut',
                          icon: Ionicons.exitOutline,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Danger zone
                if (canDeleteAccount)
                  Card(
                    color: Colors.red.withValues(alpha: 0.08),
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Colors.red.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: const ProfileButton(
                      name: 'Delete Account',
                      icon: Ionicons.trashOutline,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The Profile page's search: a wide rounded bar that opens a search of the
/// signed-in user's own reviews (artist, song, tags, text). Signed out, it
/// asks to sign in.
class _MyReviewsSearchBar extends ConsumerWidget {
  const _MyReviewsSearchBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      button: true,
      label: 'Search your reviews',
      child: Material(
        color: Colors.grey[850],
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            if (ref.read(currentUserIdProvider) == null ||
                ref.read(isAnonymousUserProvider)) {
              showAuthGateModal(context);
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SearchScreen(ownReviewsOnly: true),
              ),
            );
          },
          child: const SizedBox(
            height: RoundIconButton.size,
            child: Row(
              children: [
                SizedBox(width: AppSpacing.md),
                Icon(Icons.search, color: Colors.white70, size: 20),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Search your reviews',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white60, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
