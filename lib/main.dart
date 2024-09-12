import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_test_project/comments.dart';
import 'package:flutter_test_project/trackCards.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

import 'addReviewWidget.dart';
import 'addReviewsModal.dart';
import 'albumCards.dart';
import 'package:gap/gap.dart';

import 'albumGrid.dart';
import 'categoryTapBar.dart';
import 'exampleTestPages.dart';
import 'trackTapBar.dart';

void main() {
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
        colorScheme:
            ColorScheme.fromSeed(seedColor: Color.fromRGBO(214, 40, 40, 80)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black, // Black background
        colorScheme: ColorScheme.dark(
          primary: Colors.black, // Primary color
          background: Colors.black, // Background color
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

  final List<Widget> _pages = [
    const CategoryTapBar(),
    const TracksTapBar(),
    AddReview(),
    const AlbumGrid(),
    Page4(),
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

            return Container(
              height: 500,
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Padding(
                              padding: EdgeInsets.all(8.0),
                              child: BackButton(
                                style: ButtonStyle(
                                    elevation:
                                        MaterialStateProperty.all<double>(1.0)),
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                              )),
                          //child: const Icon(Ionicons.close))),
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              'New Review',
                              style: TextStyle(
                                fontSize: 18.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(Ionicons.person_circle_outline,
                              color: Colors.blueGrey)),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  const TextField(
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.search, color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(
                          Radius.circular(30),
                        ),
                      ),
                      hintText: 'What to review?',
                    ),
                  ),
                  Gap(20),
                  TextField(
                    controller: _controller,
                    keyboardType: TextInputType.multiline,
                    maxLines: null, // Allows the TextField to expand as needed
                    decoration: const InputDecoration(
                      //hintText: 'Enter your text here...',
                      labelText: 'Add your review',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 14.0,
                      left: 2.0,
                    ),
                    child: RatingBar(
                      minRating: 0,
                      maxRating: 5,
                      allowHalfRating: true,
                      itemSize: 24,
                      itemPadding: const EdgeInsets.symmetric(horizontal: 5.0),
                      ratingWidget: RatingWidget(
                        full: const Icon(Icons.star, color: Colors.amber),
                        empty: const Icon(Icons.star, color: Colors.grey),
                        half: const Icon(Icons.star_half, color: Colors.amber),
                      ),
                      // TODO convert to state or send to DB or something..
                      onRatingUpdate: (rating) {
                        print(rating);
                        setState(() {});
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      //Expanded
                    ],
                  )
                ],
              ),
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
        backgroundColor: const Color.fromARGB(0, 255, 201, 40),
        title: Text(widget.title),
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
          NavigationDestination(
            selectedIcon: Icon(Ionicons.home),
            icon: Icon(Ionicons.home_outline),
            label: "Home",
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.library_music_rounded),
            icon: Icon(Icons.library_music_outlined),
            label: 'Charts',
          ),
          NavigationDestination(
            selectedIcon: Icon(Ionicons.add_circle,
                size: 30.0, color: Colors.greenAccent[700]),
            icon: Icon(Ionicons.add_circle_outline,
                size: 40, color: Colors.greenAccent[700]),
            label: 'Add',
          ),
          NavigationDestination(
            selectedIcon: Icon(Ionicons.flash),
            icon: Icon(Ionicons.flash_outline),
            label: 'Trending',
          ),
          NavigationDestination(
            selectedIcon: Icon(Ionicons.person_circle),
            icon: Icon(Ionicons.person_circle_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
