import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test_project/DiscoveryTab/discoveryTapBar.dart';
import 'package:flutter_test_project/MusicPreferences/MusicTaste.dart';
import 'package:flutter_test_project/Profile/helpers/profileHelpers.dart';
import 'package:flutter_test_project/MusicPreferences/spotifyRecommendations/helpers/recommendationGenerator.dart';
import 'package:flutter_test_project/albumGrid.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ionicons/ionicons.dart';

import 'addReviewWidget.dart';
import 'Home/categoryTapBar.dart';
import 'reviewSheetContentForm.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '',
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromRGBO(214, 40, 40, 80)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black, // Black background
        colorScheme: const ColorScheme.dark(
          primary: Colors.black, // Primary color
          surface: Colors.black, // Background color
        ),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'JUKEBOXD'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // backgroundColor: const Color.fromARGB(0, 255, 201, 40),
        title: Text(
          "JUKEBOXD",
          style: GoogleFonts.gasoekOne(
            textStyle: const TextStyle(
              color: Colors.red,
              //letterSpacing: .5,
            ),
          ),
        ),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 28),
        toolbarHeight: 34.0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(10.0),
          child: Padding(
            padding: EdgeInsets.all(8.0),
          ),
        ),
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
          const NavigationDestination(
            selectedIcon: Icon(Ionicons.person_circle),
            icon: Icon(Ionicons.person_circle_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
