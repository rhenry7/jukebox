import 'package:flutter/material.dart';
import 'package:flutter_test_project/ui/screens/feed/comments.dart';

import '_comments.dart';

class CategoryTapBar extends StatelessWidget {
  const CategoryTapBar({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      initialIndex: 0,
      length: 2,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(56.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
              dividerColor: const Color.fromARGB(104, 78, 72, 72),
              labelPadding: const EdgeInsets.symmetric(horizontal: 16.0),
              tabs: const [
                Tab(
                  child: Text(
                    'Friends',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Tab(
                  child: Text(
                    'Community',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            UserReviewsCollection(),
            CommentWidget(),
          ],
        ),
      ),
    );
  }
}
