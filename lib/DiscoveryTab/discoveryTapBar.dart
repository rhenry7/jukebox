import 'package:flutter/material.dart';
import 'package:flutter_test_project/MusicPreferences/spotifyRecommendations/helpers/recommendationGenerator.dart';

import '../News/NewsWidget.dart';
import 'discoveryFreshTrackCards.dart';
import 'discoveryTrackCards.dart';

class DiscoveryTapBar extends StatelessWidget {
  const DiscoveryTapBar({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      initialIndex: 0,
      length: 4, // Number of tabs
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize:
              const Size.fromHeight(100), // Set the AppBar height to 0
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TabBar(
              padding: const EdgeInsets.all(5.0),
              labelColor: Colors.white,
              isScrollable: true, // add this property
              indicator: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(25), // Creates pill-shaped indicator
                color: Colors.red[600], // Background color of the selected tab
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromARGB(255, 255, 9, 9).withAlpha(100),
                    blurRadius: 36.0,
                    spreadRadius: 10.0,
                    offset: const Offset(
                      1.0,
                      5.0,
                    ),
                  ),
                ],
              ),
              // TABS
              dividerColor: const Color.fromARGB(104, 78, 72, 72),

              tabs: const [
                Tab(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 0.0), // Padding around text
                    child: Text(
                      'Recommended',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                Tab(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 0.0), // Padding around text
                    child: Text(
                      'Playlists',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                Tab(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 0.0), // Padding around text
                    child: Text(
                      'Explore',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                Tab(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 0.0), // Padding around text
                    child: Text(
                      'Articles',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            RecommendedAlbumScreen(),
            PersonalizedPlaylistsList(),
            DiscoveryTrackCards(),
            MusicNewsWidget(
              filterKeywords: [
                'music album',
                'music artist',
                'music genre',
                'hip hop',
                'pop music',
                'rock music',
                'jazz music',
                'indie music',
                'electronic music',
              ],
            ),
          ],
        ),
      ),
    );
  }
}
