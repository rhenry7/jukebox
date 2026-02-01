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
          preferredSize: const Size.fromHeight(72.0),
          child: Container(
            padding: const EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              top: 8.0,
              bottom: 16.0,
            ),
            alignment: Alignment.centerLeft,
            child: TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                color: Colors.red[600],
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromARGB(255, 255, 9, 9).withAlpha(100),
                    blurRadius: 36.0,
                    spreadRadius: 10.0,
                    offset: const Offset(1.0, 5.0),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelPadding: const EdgeInsets.symmetric(horizontal: 16.0),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.rocket_outlined, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Recommended',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_circle_fill_outlined, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Playlists',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.explore, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Explore',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.article, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Articles',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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
