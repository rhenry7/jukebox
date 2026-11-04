import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/ui/widgets/review_feed.dart';

void main() {
  Widget feed(ReviewFeedLayout layout, VoidCallback onRefresh) => MaterialApp(
        home: Scaffold(
          body: ReviewFeed(
            reviews: const [],
            storageKey: 'test',
            layout: layout,
            onRefresh: () async => onRefresh(),
          ),
        ),
      );

  testWidgets('tapping Home again refreshes the Home feed', (tester) async {
    var refreshes = 0;
    await tester.pumpWidget(feed(ReviewFeedLayout.tab, () => refreshes++));

    ReviewFeed.scrollToTopAndRefresh();
    await tester.pumpAndSettle();

    expect(refreshes, 1);
  });

  testWidgets('pushed feeds (tag pages) ignore it', (tester) async {
    var refreshes = 0;
    await tester.pumpWidget(feed(ReviewFeedLayout.pushed, () => refreshes++));

    ReviewFeed.scrollToTopAndRefresh();
    await tester.pumpAndSettle();

    expect(refreshes, 0);
  });
}
