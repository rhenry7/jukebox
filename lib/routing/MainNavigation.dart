import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/DiscoveryTab/discoveryTapBar.dart';
import 'package:flutter_test_project/ui/screens/Home/categoryTapBar.dart';
import 'package:flutter_test_project/ui/screens/Profile/helpers/profileHelpers.dart';
import 'package:flutter_test_project/ui/screens/albumDiscovery/albumGrid.dart';
import 'package:flutter_test_project/models/music_preferences.dart';
import 'package:flutter_test_project/ui/screens/addReview/reviewSheetContentForm.dart';
import 'package:flutter_test_project/providers/auth_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ionicons/ionicons.dart';

class MainNav extends ConsumerStatefulWidget {
  const MainNav({super.key, required this.title});
  final String title;

  @override
  ConsumerState<MainNav> createState() => MainNavState();
}

class MainNavState extends ConsumerState<MainNav> {
  int currentPageIndex = 0;
  final TextEditingController _controller = TextEditingController();
  late Future<MusicPreferences?> _preferencesFuture;

  final List<Widget> _pages = [
    const CategoryTapBar(),
    const DiscoveryTapBar(),
    const MyReviewSheetContentForm(
      title: 'track-title',
      artist: 'artist',
      albumImageUrl: "",
    ),
    const AlbumGrid(),
    profileRouter(),
  ];

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
              albumImageUrl: "",
            );
          });
    } else {
      setState(() {
        currentPageIndex = index;
      });
    }
  }

  // Public method to change tab from child widgets
  void navigateToTab(int index) {
    _onItemTapped(index);
  }

  // Get profile label - show username if logged in, otherwise "Profile"
  String _getProfileLabel() {
    final user = ref.read(currentUserProvider);
    if (user != null && user.displayName != null && user.displayName!.isNotEmpty) {
      return user.displayName!;
    }
    return 'Profile';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "MIXTAKES",
          style: GoogleFonts.gasoekOne(
            textStyle: const TextStyle(
              color: Colors.red,
            ),
          ),
        ),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 28),
        toolbarHeight: 56.0,
      ),
      body: _pages[currentPageIndex],
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: _onItemTapped,
        selectedIndex: currentPageIndex,
        indicatorColor: Colors.white,
        destinations: <Widget>[
          const NavigationDestination(
            selectedIcon: Icon(Ionicons.home),
            icon: Icon(Ionicons.home_outline),
            label: "Home",
          ),
          const NavigationDestination(
            selectedIcon: Icon(Ionicons.planet_outline),
            icon: Icon(Ionicons.planet),
            label: 'Discovery',
          ),
          NavigationDestination(
            selectedIcon: Icon(Ionicons.add_circle,
                size: 30.0, color: Colors.greenAccent[700]),
            icon: Icon(Ionicons.add_circle_outline,
                size: 40, color: Colors.greenAccent[700]),
            label: 'Add',
          ),
          const NavigationDestination(
            selectedIcon: Icon(Ionicons.flash),
            icon: Icon(Ionicons.flash_outline),
            label: 'Trending',
          ),
          NavigationDestination(
            selectedIcon: Icon(Ionicons.person_circle),
            icon: Icon(Ionicons.person_circle_outline),
            label: _getProfileLabel(),
          ),
        ],
      ),
    );
  }
}
