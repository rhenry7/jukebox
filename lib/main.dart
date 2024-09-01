import 'dart:convert';

import 'package:flutter_test_project/types/types.dart';

import 'api_key.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  // This widget is the root of your application.

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightGreen),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Page'),
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
    Page1(),
    const CardTracks(),
    Page3(),
    Page4(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
        indicatorColor: Colors.green,
        destinations: const <Widget>[
          NavigationDestination(
            selectedIcon: Icon(Icons.home),
            icon: Icon(Icons.home),
            label: "Home",
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.library_music_outlined),
            icon: Icon(Icons.library_music_rounded),
            label: 'Tracks',
          ),
          NavigationDestination(
            icon: Badge(child: Icon(Icons.notifications_sharp)),
            label: 'Notifications',
          ),
          NavigationDestination(
            icon: Badge(
              label: Text('2'),
              child: Icon(Icons.messenger_sharp),
            ),
            label: 'Messages',
          ),
        ],
      ),
    );
  }
}

Future<List<Track>> fetchTopTracks() async {
  const String lastfm = apikey;
  final uri = Uri.parse(
      'https://ws.audioscrobbler.com/2.0/?method=geo.gettoptracks&country=spain&api_key=$lastfm&format=json');

  http.Response response = await http.get(uri);

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final List<dynamic> tracksJson = data['tracks']['track'];

    List<Track> tracks = tracksJson.map((trackJson) {
      return Track.fromJson(trackJson);
    }).toList();
    return tracks;
  } else {
    throw Exception(
        'Failed to load top tracks. Status code: ${response.statusCode}');
  }
}

class CardTracks extends StatefulWidget {
  const CardTracks({super.key});

  @override
  State<CardTracks> createState() => CardExample();
}

class CardExample extends State<CardTracks> {
  late Future<List<Track>> futureTracks;
  @override
  void initState() {
    super.initState();
    futureTracks = fetchTopTracks();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
        child: FutureBuilder<List<Track>>(
            future: futureTracks,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return ListView.builder(itemBuilder: (context, index) {
                  final track = snapshot.data![index];
                  return Card(
                      child: Column(
                    children: <Widget>[
                      ListTile(
                        leading: Icon(Icons.album),
                        title: Text(track.name),
                      )
                    ],
                  ));
                });
              } else if (snapshot.hasError) {
                print(snapshot);
                return Text('error found ${snapshot.error}');
              }
              // By default, show a loading spinner.
              return const CircularProgressIndicator();
            }));
  }
}

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
