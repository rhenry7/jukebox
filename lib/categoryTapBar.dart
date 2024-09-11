import 'package:flutter/material.dart';
import 'package:flutter_test_project/comments.dart';

class CategoryTapBar extends StatelessWidget {
  const CategoryTapBar({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      initialIndex: 0,
      length: 5, // Number of tabs

      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(100), // Set the AppBar height to 0
          child: TabBar(
            isScrollable: true, // Makes the TabBar scrollable
            padding: EdgeInsets.only(bottom: 5.0),
            // labelPadding:
            //     const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
            indicator: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(25), // Creates pill-shaped indicator
              color: Colors.red[600], // Background color of the selected tab
              boxShadow: [
                BoxShadow(
                  color: Color.fromARGB(255, 255, 9, 9).withAlpha(100),
                  blurRadius: 18.0,
                  spreadRadius: 10.0,
                  offset: const Offset(
                    0.0,
                    0.0,
                  ),
                ),
              ],
            ),
            tabs: const [
              Tab(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 10.0), // Padding around text
                  child: Text(
                    'Pop',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              Tab(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 0.0), // Padding around text
                  child: Text(
                    'Classical',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              Tab(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 0.0), // Padding around text
                  child: Text(
                    'Electronic',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              Tab(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 0.0), // Padding around text
                  child: Text(
                    'Rap',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              Tab(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 0.0), // Padding around text
                  child: Text(
                    'Rock',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            CommentWidget(),
            Center(child: Text('Tab 2 Content')),
            Center(child: Text('Tab 3 Content')),
            Center(child: Text('Tab 4 Content')),
            Center(child: Text('Tab 5 Content')),
          ],
        ),
      ),
    );
  }
}
