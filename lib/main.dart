import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_test_project/comments.dart';
import 'package:flutter_test_project/trackCards.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

import 'addReviewsModal.dart';
import 'albumCards.dart';
import 'package:gap/gap.dart';

import 'albumGrid.dart';
import 'categoryTapBar.dart';

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
    const TabBarExample(),
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
        indicatorColor: Colors.amber.shade400,
        destinations: <Widget>[
          NavigationDestination(
            selectedIcon: Icon(Ionicons.home),
            icon: Icon(Ionicons.home),
            label: "Home",
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.library_music_outlined),
            icon: Icon(Icons.library_music_rounded),
            label: 'Charts',
          ),
          NavigationDestination(
            selectedIcon: Icon(Ionicons.add_circle,
                size: 30.0, color: Colors.greenAccent[400]),
            icon: Icon(Ionicons.add_circle_outline,
                size: 40, color: Colors.greenAccent[400]),
            label: 'Add',
          ),
          NavigationDestination(
            selectedIcon: Icon(Ionicons.flash),
            icon: Icon(Ionicons.flash),
            label: 'Trending',
          ),
          NavigationDestination(
            selectedIcon: Icon(Ionicons.person_circle),
            icon: Icon(Ionicons.person_circle),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// TODO: rename, possibly
class TabBarExample extends StatelessWidget {
  const TabBarExample({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      initialIndex: 0,
      length: 3,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(100), // Set the AppBar height to 0
          child: TabBar(
            padding: EdgeInsets.only(bottom: 5.0),
            labelColor: Colors.white,
            isScrollable: true, // add this property
            // unselectedLabelColor: Color(0xff585861),
            indicator: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(25), // Creates pill-shaped indicator
              color: Colors.red[600], // Background color of the selected tab
              boxShadow: [
                BoxShadow(
                  color: Color.fromARGB(255, 255, 9, 9).withAlpha(100),
                  blurRadius: 16.0,
                  spreadRadius: 10.0,
                  offset: const Offset(
                    1.0,
                    5.0,
                  ),
                ),
              ],
            ),

            // TABS
            tabs: const [
              Tab(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 0.0), // Padding around text
                  child: Text(
                    'Songs',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              Tab(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 0.0), // Padding around text
                  child: Text(
                    'Albums',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              Tab(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 0.0), // Padding around text
                  child: Text(
                    'Artists',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: <Widget>[
            Center(
              child: CardTracks(),
            ),
            Center(
              child: AlbumCard(),
            ),
            Center(
              child: Text("It's sunny here"),
            ),
          ],
        ),
      ),
    );
  }
}

// Test Pages for learning navigation
// TODO: Delete later
class Page1 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Home Page'),
    );
  }
}

class Page2 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CardTracks(),
    );
  }
}

class Page3 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Third Page'),
    );
  }
}

class Page4 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Fourth Page'),
    );
  }
}

class AddReview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        child: const Text('showModalBottomSheet'),
        onPressed: () {
          showModalBottomSheet<void>(
            context: context,
            builder: (BuildContext context) {
              return Container(
                height: 200,
                padding: const EdgeInsets.all(15),
                color: Colors.blueAccent,
                child: const Column(
                  children: [
                    Icon(Icons.info_outline),
                    Text('FYI'),
                    Text('Learn more about Modal Bottom Sheet here'),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
