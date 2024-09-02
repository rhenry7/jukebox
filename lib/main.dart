import 'dart:convert';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'api_key.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/widgets.dart' as flutter;
import 'package:flutter_test_project/types/types.dart' as lastFM;
import 'package:spotify/src/models/_models.dart' as spotify;
import 'package:spotify/spotify.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple.shade50),
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
    Page1(),
    const TabBarExample(),
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
        indicatorColor: Color.fromRGBO(67, 146, 241, 1),
        destinations: const <Widget>[
          NavigationDestination(
            selectedIcon: Icon(Icons.home),
            icon: Icon(Icons.home),
            label: "Home",
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.library_music_outlined),
            icon: Icon(Icons.library_music_rounded),
            label: 'Feed',
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

Future<List<spotify.Track>> fetchSpotifyTracks() async {
  final credentials = SpotifyApiCredentials(clientId, clientSecret);
  final getFromSpotify = SpotifyApi(credentials);
  final tracks = await getFromSpotify.playlists
      .getTracksByPlaylistId('37i9dQZEVXbLRQDuF5jeBp')
      .all();
  return tracks.toList();
}

class CardTracks extends StatefulWidget {
  const CardTracks({super.key});

  @override
  State<CardTracks> createState() => ListOfTracks();
}

class ListOfTracks extends State<CardTracks> {
  late Future<List<spotify.Track>> spotifyTracks;
  double? _rating;

  @override
  void initState() {
    super.initState();
    spotifyTracks = fetchSpotifyTracks();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FutureBuilder<List<spotify.Track>>(
        future: spotifyTracks,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final track = snapshot.data![index];
                final albumImages = track.album!.images;
                final smallImageUrl =
                    albumImages!.isNotEmpty ? albumImages.last.url : null;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: ListTile(
                            leading: smallImageUrl != null
                                ? flutter.Image.network(smallImageUrl)
                                : const Icon(Icons
                                    .music_note), // Fallback if no image is available,
                            title: Text(track.name as String),
                            subtitle: Text(track.artists!
                                .map((artist) => artist.name)
                                .join(', ')),
                          ),
                        ),
                        RatingBar(
                          minRating: 0,
                          maxRating: 5,
                          allowHalfRating: true,
                          itemSize: 24,
                          itemPadding:
                              const EdgeInsets.symmetric(horizontal: 2.0),
                          ratingWidget: RatingWidget(
                            full: const Icon(Icons.star, color: Colors.amber),
                            empty: const Icon(Icons.star, color: Colors.grey),
                            half: const Icon(Icons.star_half,
                                color: Colors.amber),
                          ),
                          onRatingUpdate: (rating) {
                            _rating = rating;
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          } else if (snapshot.hasError) {
            print(snapshot);
            return Text('Error: ${snapshot.error}');
          }
          return const CircularProgressIndicator();
        },
      ),
    );
  }
}

HalfFilledIcon() {}

// TODO: rename, possibly
class TabBarExample extends StatelessWidget {
  const TabBarExample({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      initialIndex: 1,
      length: 3,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(200), // Set the AppBar height to 0
          child: TabBar(
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
              child: Text("It's rainy here"),
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
