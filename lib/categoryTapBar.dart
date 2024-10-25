import 'package:flutter/material.dart';
import 'package:flutter_test_project/comments.dart';

import 'albumCards.dart';

class CategoryTapBar extends StatelessWidget {
  const CategoryTapBar({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      initialIndex: 0,
      length: 5, // Number of tabs
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize:
              const Size.fromHeight(350), // Set the AppBar height to 0
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
              tabs: const [
                Tab(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 0.0), // Padding around text
                    child: Text(
                      'Reviews',
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
                      'News',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                Tab(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 0.0), // Padding around text
                    child: Text(
                      'Upcoming',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                Tab(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 0.0), // Padding around text
                    child: Text(
                      'Concerts',
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
            AlbumCard(),
            CommentWidget(),
            Center(child: Text('Tab 3 Content')),
            Center(child: Text('Tab 4 Content')),
            Center(child: Text('Tab 5 Content')),
          ],
        ),
      ),
    );
  }
}
