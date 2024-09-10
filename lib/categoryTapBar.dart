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
          preferredSize: Size.fromHeight(50), // Set the AppBar height to 0
          child: TabBar(
            isScrollable: true, // Makes the TabBar scrollable
            labelPadding:
                const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
            indicator: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(25), // Creates pill-shaped indicator
              color:
                  Colors.amber.shade400, // Background color of the selected tab
            ),
            tabs: const [
              Tab(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 0.0), // Padding around text
                  child: Text('Pop'),
                ),
              ),
              Tab(text: 'Progressive Rock'),
              Tab(text: 'Soul Funk'),
              Tab(text: 'Electronic'),
              Tab(text: 'Jazz'),
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
