import 'package:flutter_test_project/comments.dart';
import 'package:flutter_test_project/trackCards.dart';
import 'package:flutter/material.dart';

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
      home: const MyHomePage(title: 'Jukeboxd'),
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

  final List<Widget> _pages = [
    const CommentWidget(),
    const TabBarExample(),
    Page3(),
    Page4(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color.fromARGB(255, 18, 129, 233),
        title: Text(widget.title),
      ),
      body: _pages[currentPageIndex],
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() {
            currentPageIndex = index;
          });
        },
        selectedIndex: currentPageIndex,
        indicatorColor: Color.fromRGBO(67, 146, 241, 1),
        destinations: const <Widget>[
          NavigationDestination(
            selectedIcon: Icon(Icons.home_outlined),
            icon: Icon(Icons.home),
            label: "Home",
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.library_music_outlined),
            icon: Icon(Icons.library_music_rounded),
            label: 'Feed',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.bolt_outlined),
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
            labelColor: Colors.black,
            //isScrollable: true, // add this property
            unselectedLabelColor: Color(0xff585861),
            indicatorColor: Colors.greenAccent,
            indicatorSize: TabBarIndicatorSize.label,
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
