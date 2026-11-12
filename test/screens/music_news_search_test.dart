import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/providers/music_news_provider.dart';
import 'package:flutter_test_project/providers/reviews_provider.dart';
import 'package:flutter_test_project/providers/search_reviews_provider.dart';
import 'package:flutter_test_project/ui/screens/search/search_screen.dart';
import 'package:flutter_test_project/ui/widgets/music_news_feed.dart';

import '../helpers/screen_harness.dart';

MusicNewsItem _news(
  String id,
  String source,
  String name,
  String title, {
  String album = '',
  String artist = '',
  String verdict = '',
  int daysAgo = 2,
}) => MusicNewsItem(
  id: id,
  source: source,
  sourceName: name,
  label: 'Album Review',
  title: title,
  album: album,
  artist: artist,
  verdict: verdict,
  summary: 'A summary of $title.',
  author: 'A Critic',
  url: 'https://example.com/$id',
  publishedAt: DateTime.now().subtract(Duration(days: daysAgo)),
);

final _items = [
  _news(
    '1',
    'pitchfork',
    'Pitchfork',
    'On Tha Run',
    album: 'On Tha Run',
    artist: 'Baby Osamaa',
  ),
  _news(
    '2',
    'nme',
    'NME',
    'U2 – ‘Carnaval de Luz’ review: brighter, poppier',
    album: 'Carnaval de Luz',
    artist: 'U2',
    verdict: 'Brighter, poppier',
  ),
  _news('3', 'stereogum', 'Stereogum', 'Krill Secret Language'),
];

void main() {
  testWidgets('before typing: Best New Music rows, filtered by source pills', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const SearchScreen(),
      overrides: [
        ...reviewScreenOverrides(user: testUser),
        musicNewsProvider.overrideWith((ref) => Stream.value(_items)),
      ],
    );
    await tester.pump();
    expect(find.text('Best New Music'), findsOneWidget);
    expect(find.byType(MusicNewsRow), findsNWidgets(3));
    // Album and artist where the headline was split; the headline otherwise.
    expect(find.text('Carnaval de Luz'), findsOneWidget);
    expect(find.text('U2'), findsOneWidget);
    expect(find.text('Brighter, poppier'), findsOneWidget);
    expect(find.text('Krill Secret Language'), findsOneWidget);
    // Only sources with reviews get a pill (no Billboard here).
    expect(find.text('Billboard'), findsNothing);

    // The pill row scrolls sideways; NME starts just off screen.
    await tester.ensureVisible(find.text('NME'));
    await tester.pump();
    await tester.tap(find.text('NME'));
    await tester.pump();
    expect(find.byType(MusicNewsRow), findsOneWidget);
    expect(find.text('Carnaval de Luz'), findsOneWidget);

    await tester.ensureVisible(find.text('All'));
    await tester.pump();
    await tester.tap(find.text('All'));
    await tester.pump();
    expect(find.byType(MusicNewsRow), findsNWidgets(3));
  });

  testWidgets('tapping a row opens its sheet with what to do next', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const SearchScreen(),
      overrides: [
        ...reviewScreenOverrides(user: testUser),
        musicNewsProvider.overrideWith((ref) => Stream.value(_items)),
      ],
    );
    await tester.pump();
    await tester.tap(find.text('Carnaval de Luz'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('“Brighter, poppier”'), findsOneWidget);
    expect(find.textContaining('A summary of U2'), findsOneWidget);
    expect(find.text('By A Critic · 2d'), findsOneWidget);
    expect(find.text('Review it'), findsOneWidget);
    expect(find.text('Read on NME'), findsOneWidget);
  });

  testWidgets('a short headline that could not be split: searched as is', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const SearchScreen(),
      overrides: [
        ...reviewScreenOverrides(user: testUser),
        musicNewsProvider.overrideWith((ref) => Stream.value(_items)),
      ],
    );
    await tester.pump();
    await tester.tap(find.text('Krill Secret Language'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Read on Stereogum'), findsOneWidget);
    expect(find.text('Review it'), findsOneWidget);
    expect(find.text('Play on Spotify'), findsOneWidget);
  });

  test('lookup: album + artist, a short headline, never a long one', () {
    expect(_items[1].lookup, (title: 'Carnaval de Luz', artist: 'U2'));
    expect(_items[2].lookup, (title: 'Krill Secret Language', artist: ''));
    final article = _news(
      '9',
      'billboard',
      'Billboard',
      'Olivia Rodrigo Rocks Out at Surprise Underplay in Brooklyn',
    );
    expect(article.lookup, isNull);
  });

  testWidgets('typing replaces the news with search results', (tester) async {
    final result = ReviewWithDocId(
      review: sampleReview(title: 'Nights', artist: 'Frank Ocean'),
      docId: 'r1',
      fullReviewId: 'users/u/reviews/r1',
    );
    await pumpScreen(
      tester,
      const SearchScreen(),
      overrides: [
        ...reviewScreenOverrides(user: testUser),
        musicNewsProvider.overrideWith((ref) => Stream.value(_items)),
        searchReviewsProvider.overrideWith((ref, q) async => [result]),
      ],
    );
    await tester.pump();
    expect(find.text('Best New Music'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'frank');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Best New Music'), findsNothing);
    expect(find.text('1 result'), findsOneWidget);
    expect(find.text('Nights'), findsOneWidget);
  });

  testWidgets('no news yet: the search prompt', (tester) async {
    await pumpScreen(
      tester,
      const SearchScreen(),
      overrides: [
        ...reviewScreenOverrides(user: testUser),
        musicNewsProvider.overrideWith((ref) => Stream.value(const [])),
      ],
    );
    await tester.pump();
    expect(find.text('Best New Music'), findsNothing);
    expect(find.textContaining('Search reviews by artist'), findsOneWidget);
  });

  testWidgets('news fails to load: the search prompt, no error text', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const SearchScreen(),
      overrides: [
        ...reviewScreenOverrides(user: testUser),
        musicNewsProvider.overrideWith(
          (ref) => Stream.error(Exception('permission-denied')),
        ),
      ],
    );
    await tester.pump();
    expect(find.textContaining('Search reviews by artist'), findsOneWidget);
    expect(find.textContaining('permission'), findsNothing);
  });

  testWidgets('your own reviews: the prompt, never the news', (tester) async {
    await pumpScreen(
      tester,
      const SearchScreen(ownReviewsOnly: true),
      overrides: [
        ...reviewScreenOverrides(user: testUser),
        musicNewsProvider.overrideWith((ref) => Stream.value(_items)),
      ],
    );
    await tester.pump();
    expect(find.text('Best New Music'), findsNothing);
    expect(find.textContaining('Find your reviews'), findsOneWidget);
  });

  group('filterMusicNews', () {
    test('one source: just its reviews', () {
      expect(filterMusicNews(_items, 'nme').single.id, '2');
    });

    test('All: the sites take turns, each newest first', () {
      final items = [
        for (var d = 0; d < 4; d++)
          _news('n$d', 'nme', 'NME', 'n$d', daysAgo: d),
        _news('p0', 'pitchfork', 'Pitchfork', 'p0', daysAgo: 5),
        _news('p1', 'pitchfork', 'Pitchfork', 'p1', daysAgo: 9),
        _news('s0', 'stereogum', 'Stereogum', 's0', daysAgo: 1),
      ];
      expect(
        [for (final i in filterMusicNews(items, null)) i.id],
        ['n0', 's0', 'p0', 'n1', 'p1', 'n2', 'n3'],
      );
    });
  });
}
