import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/providers/music_news_provider.dart';
import 'package:flutter_test_project/providers/reviews_provider.dart';
import 'package:flutter_test_project/providers/search_reviews_provider.dart';
import 'package:flutter_test_project/providers/unified_search_provider.dart';
import 'package:flutter_test_project/ui/screens/search/search_screen.dart';
import 'package:flutter_test_project/ui/widgets/music_news_feed.dart';

import '../helpers/screen_harness.dart';

MusicNewsItem _news(
  String id,
  String source,
  String name,
  String album, {
  String artist = 'Someone',
  String verdict = '',
  String label = 'Album Review',
  int daysAgo = 2,
  List<String> genres = const [],
  List<String> tags = const [],
  List<String> artistMbids = const [],
}) => MusicNewsItem(
  id: id,
  source: source,
  sourceName: name,
  label: label,
  title: '$artist – $album',
  album: album,
  artist: artist,
  verdict: verdict,
  summary: 'A summary of $album.',
  author: 'A Critic',
  url: 'https://example.com/$id',
  publishedAt: DateTime.now().subtract(Duration(days: daysAgo)),
  genres: genres,
  tags: tags,
  artistMbids: artistMbids,
);

final _items = [
  _news(
    '1',
    'pitchfork',
    'Pitchfork',
    'On Tha Run',
    artist: 'Baby Osamaa',
    label: 'Best New Album',
    genres: const ['Hip-hop'],
    tags: const ['hip hop'],
    artistMbids: const ['mb-osamaa'],
  ),
  _news(
    '2',
    'nme',
    'NME',
    'Carnaval de Luz',
    artist: 'U2',
    verdict: 'Brighter, poppier',
    genres: const ['Rock'],
    tags: const ['rock'],
  ),
  // The Guardian reviewed the same album: one row, "critics agree".
  _news(
    '3',
    'guardian',
    'The Guardian',
    'Carnaval de Luz',
    artist: 'U2',
    verdict: 'Stadium-sized',
    daysAgo: 1,
    genres: const ['Rock'],
  ),
  _news(
    '4',
    'quietus',
    'The Quietus',
    'Warm Ground',
    artist: 'Tara Cunningham',
    daysAgo: 20,
    genres: const ['Experimental'],
  ),
];

List<Override> _overrides({
  List<MusicNewsItem>? items,
  NewsTaste taste = NewsTaste.empty,
}) => [
  ...reviewScreenOverrides(user: testUser),
  musicNewsProvider.overrideWith((ref) => Stream.value(items ?? _items)),
  newsTasteProvider.overrideWith((ref) async => taste),
];

/// Scrolls the pill row sideways until [text] is built and on screen.
Future<void> _scrollTo(
  WidgetTester tester,
  String text, {
  bool back = false,
}) async {
  await tester.scrollUntilVisible(
    find.text(text),
    back ? -80 : 80,
    // The pill row (the search field scrolls sideways too).
    scrollable: find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pump();
}

void main() {
  testWidgets('one row per album; same album from two sites merges', (
    tester,
  ) async {
    await pumpScreen(tester, const SearchScreen(), overrides: _overrides());
    await tester.pump();
    expect(find.text('Best New Music'), findsOneWidget);
    expect(find.byType(MusicNewsRow), findsNWidgets(3));
    expect(find.text('Carnaval de Luz'), findsOneWidget);
    expect(find.textContaining('THE GUARDIAN + NME'), findsOneWidget);
  });

  testWidgets('pills: All, Critics agree, This week, then genres; no sites', (
    tester,
  ) async {
    await pumpScreen(tester, const SearchScreen(), overrides: _overrides());
    await tester.pump();
    for (final label in ['All', 'Critics agree', 'This week']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    await _scrollTo(tester, 'Rock');
    expect(find.text('Rock'), findsOneWidget);
    await _scrollTo(tester, 'All', back: true);
    expect(find.text('For you'), findsNothing, reason: 'no taste to go on');
    expect(find.text('Pitchfork'), findsNothing, reason: 'sites are in ⚙');

    await tester.tap(find.text('Critics agree'));
    await tester.pump();
    expect(find.byType(MusicNewsRow), findsOneWidget);

    await tester.tap(find.text('This week'));
    await tester.pump();
    expect(find.byType(MusicNewsRow), findsNWidgets(2), reason: 'not 20d old');

    await _scrollTo(tester, 'Experimental');
    await tester.tap(find.text('Experimental'));
    await tester.pump();
    expect(find.byType(MusicNewsRow), findsOneWidget);
    expect(find.text('Warm Ground'), findsOneWidget);

    // Tapping the picked pill goes back to All.
    await tester.tap(find.text('Experimental'));
    await tester.pump();
    expect(find.byType(MusicNewsRow), findsNWidgets(3));
  });

  testWidgets('For you: albums by artists the user loves, best first', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const SearchScreen(),
      overrides: _overrides(
        taste: const NewsTaste(artists: {'mb-osamaa'}, tags: {'rock'}),
      ),
    );
    await tester.pump();
    await tester.pump(); // the user's taste loads
    await tester.tap(find.text('For you'));
    await tester.pump();
    final rows = tester
        .widgetList<MusicNewsRow>(find.byType(MusicNewsRow))
        .map((r) => r.album.primary.album)
        .toList();
    expect(rows, ['On Tha Run', 'Carnaval de Luz']);
  });

  testWidgets('the site picker switches sites off (never the last one)', (
    tester,
  ) async {
    await pumpScreen(tester, const SearchScreen(), overrides: _overrides());
    await tester.pump();
    await tester.tap(find.byTooltip('Choose sites'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('SITES'), findsOneWidget);
    await tester.tap(find.text('The Quietus'));
    await tester.pump();
    await tester.tapAt(const Offset(20, 800)); // close
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Warm Ground'), findsNothing);
    expect(find.byType(MusicNewsRow), findsNWidgets(2));
  });

  testWidgets('a merged album sheet shows each site and its Read link', (
    tester,
  ) async {
    await pumpScreen(tester, const SearchScreen(), overrides: _overrides());
    await tester.pump();
    await tester.tap(find.text('Carnaval de Luz'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('“Brighter, poppier”'), findsOneWidget);
    expect(find.text('“Stadium-sized”'), findsOneWidget);
    expect(find.text('Read on NME'), findsOneWidget);
    expect(find.text('Read on The Guardian'), findsOneWidget);
    expect(find.text('Review it'), findsOneWidget);
    expect(find.text('Play on Spotify'), findsOneWidget);
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
        ..._overrides(),
        searchReviewsProvider.overrideWith((ref, q) async => [result]),
        searchPoolProvider.overrideWith((ref) async => [result]),
        musicSearchProvider.overrideWith((ref, q) async => const []),
      ],
    );
    await tester.pump();
    expect(find.text('Best New Music'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'frank');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Best New Music'), findsNothing);
    expect(find.textContaining('REVIEWS'), findsOneWidget);
    expect(find.text('Nights'), findsOneWidget);
  });

  testWidgets('no news yet: the search prompt', (tester) async {
    await pumpScreen(
      tester,
      const SearchScreen(),
      overrides: _overrides(items: const []),
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
      overrides: _overrides(),
    );
    await tester.pump();
    expect(find.text('Best New Music'), findsNothing);
    expect(find.textContaining('Find your reviews'), findsOneWidget);
  });

  group('albums and filters', () {
    test('grouping: first-named artist and title, case and punctuation', () {
      final albums = groupNewsAlbums([
        _news('a', 'nme', 'NME', 'ZIRP!', artist: 'DIIV'),
        _news(
          'b',
          'stereogum',
          'Stereogum',
          'Zirp',
          artist: 'Diiv',
          label: 'Album of the Week',
        ),
        _news(
          'c',
          'nme',
          'NME',
          'Before the World Blows',
          artist: 'Erykah Badu & The Alchemist',
        ),
        _news(
          'd',
          'guardian',
          'The Guardian',
          'Before the World Blows',
          artist: 'Erykah Badu',
        ),
      ]);
      expect(albums.length, 2);
      final zirp = albums.firstWhere((a) => a.primary.album.contains('Z'));
      expect(zirp.primary.source, 'stereogum', reason: "the site's pick leads");
      expect(zirp.criticsAgree, isTrue);
    });

    test('All: the sites take turns, each newest first', () {
      final albums = groupNewsAlbums([
        for (var d = 0; d < 3; d++)
          _news('n$d', 'nme', 'NME', 'n$d', artist: 'n$d', daysAgo: d),
        _news('p0', 'pitchfork', 'Pitchfork', 'p0', artist: 'p', daysAgo: 5),
      ]);
      expect(
        [
          for (final a in applyNewsFilter(
            albums,
            NewsFilter.all,
            NewsTaste.empty,
          ))
            a.primary.id,
        ],
        ['n0', 'p0', 'n1', 'n2'],
      );
    });

    test('taste: a loved artist beats a similar one beats shared tags', () {
      const taste = NewsTaste(
        artists: {'loved'},
        similar: {'alike': 0.8},
        tags: {'shoegaze'},
      );
      final loved = NewsAlbum([
        _news('1', 'nme', 'NME', 'a', artistMbids: ['loved']),
      ]);
      final alike = NewsAlbum([
        _news('2', 'nme', 'NME', 'b', artistMbids: ['alike']),
      ]);
      final tagged = NewsAlbum([
        _news('3', 'nme', 'NME', 'c', tags: ['shoegaze']),
      ]);
      final none = NewsAlbum([_news('4', 'nme', 'NME', 'd')]);
      expect(taste.score(loved), greaterThan(taste.score(alike)));
      expect(taste.score(alike), greaterThan(taste.score(tagged)));
      expect(taste.score(tagged), greaterThan(0));
      expect(taste.score(none), 0);
    });

    test("genres: the user's first, then the biggest", () {
      final albums = groupNewsAlbums([
        _news(
          '1',
          'nme',
          'NME',
          'a',
          artist: 'a',
          genres: ['Rock'],
          tags: ['rock'],
        ),
        _news('2', 'nme', 'NME', 'b', artist: 'b', genres: ['Rock']),
        _news(
          '3',
          'nme',
          'NME',
          'c',
          artist: 'c',
          genres: ['Jazz'],
          tags: ['jazz'],
        ),
      ]);
      expect(newsGenres(albums, NewsTaste.empty), ['Rock', 'Jazz']);
      expect(newsGenres(albums, const NewsTaste(tags: {'jazz'})), [
        'Jazz',
        'Rock',
      ]);
    });

    test('the first named artist', () {
      expect(newsMainArtist('Erykah Badu & The Alchemist'), 'Erykah Badu');
      expect(
        newsMainArtist('Crystal Waters, The Basement Boys'),
        'Crystal Waters',
      );
    });
  });
}
