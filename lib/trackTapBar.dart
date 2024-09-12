import 'package:flutter/material.dart';

import 'albumCards.dart';
import 'trackCards.dart';

class TracksTapBar extends StatelessWidget {
  const TracksTapBar({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      initialIndex: 0,
      length: 3,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(100), // Set the AppBar height to 0
          child: TabBar(
            padding: const EdgeInsets.only(bottom: 5.0),
            labelColor: Colors.white,
            isScrollable: true, // add this property
            // unselectedLabelColor: Color(0xff585861),
            indicator: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(25), // Creates pill-shaped indicator
              color: Colors.red[600], // Background color of the selected tab
              boxShadow: [
                BoxShadow(
                  color: const Color.fromARGB(255, 255, 9, 9).withAlpha(100),
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
                  padding: EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 0.0), // Padding around text
                  child: Text(
                    'Songs',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              Tab(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 0.0), // Padding around text
                  child: Text(
                    'Albums',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              Tab(
                child: Padding(
                  padding: EdgeInsets.symmetric(
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
