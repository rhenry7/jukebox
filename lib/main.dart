import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_test_project/comments.dart';
import 'package:flutter_test_project/trackCards.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

import 'addReviewsModal.dart';
import 'albumCards.dart';
import 'package:gap/gap.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jukeboxd',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue.shade300),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'jukeboxd'),
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
    const CommentWidget(),
    const TabBarExample(),
    AddReview(),
    Page3(),
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
        backgroundColor: Color.fromARGB(255, 18, 129, 233),
        title: Text(widget.title),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 28),
        toolbarHeight: 34.0,
        bottom: PreferredSize(
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
        indicatorColor: Color.fromRGBO(67, 146, 241, 1),
        destinations: const <Widget>[
          NavigationDestination(
            selectedIcon: Icon(Ionicons.home_outline),
            icon: Icon(Icons.home),
            label: "Home",
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.library_music_outlined),
            icon: Icon(Icons.library_music_rounded),
            label: 'Feed',
          ),
          NavigationDestination(
            selectedIcon: Icon(Ionicons.add_circle, size: 30.0),
            icon: Icon(
              Ionicons.add_circle_outline,
              size: 40,
            ),
            label: 'Add',
          ),
          NavigationDestination(
            selectedIcon: Icon(Ionicons.flash_outline),
            icon: Icon(Icons.bolt),
            label: 'Trending',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.account_circle_outlined),
            icon: Icon(Icons.account_circle),
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
    return const DefaultTabController(
      initialIndex: 0,
      length: 3,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(200), // Set the AppBar height to 0
          child: TabBar(
            labelPadding: EdgeInsets.all(10),
            labelColor: Colors.blue,
            //isScrollable: true, // add this property
            unselectedLabelColor: Color(0xff585861),
            indicatorColor: Color.fromARGB(225, 25, 118, 210),
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: TextStyle(
                fontSize: 14.0,
                fontWeight: FontWeight.bold,
                color: Color.fromRGBO(0, 115, 255, 1)),

            // TABS
            tabs: <Widget>[
              Tab(
                text: 'Songs',
              ),
              Tab(
                text: 'Albums',
              ),
              Tab(
                text: 'Artists',
              ),
            ],
          ),
        ),
        body: TabBarView(
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
