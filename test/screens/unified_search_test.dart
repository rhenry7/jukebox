import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/providers/music_news_provider.dart';
import 'package:flutter_test_project/providers/reviews_provider.dart';
import 'package:flutter_test_project/providers/search_reviews_provider.dart';
import 'package:flutter_test_project/providers/unified_search_provider.dart';
import 'package:flutter_test_project/ui/screens/search/search_screen.dart';

import '../helpers/screen_harness.dart';

ReviewWithDocId _r(
  String id, {
  String title = 'Song',
  String artist = 'Artist',
  List<String> genres = const [],
  double score = 4,
}) => ReviewWithDocId(
  review: Review(
    displayName: 'someone',
    userId: 'u$id',
    artist: artist,
    review: 'Good.',
    score: score,
    likes: 0,
    replies: 0,
    reposts: 0,
    title: title,
    genres: genres,
    date: DateTime(2026, 1, int.parse(id)),
  ),
  docId: id,
  fullReviewId: 'users/u$id/reviews/$id',
);

final _pool = [
  _r(
    '1',
    title: 'TELL EM IN BRAZIL',
    artist: 'MLQ 2N, JP Nogueira',
    genres: ['phonk', 'brazil'],
  ),
  _r(
    '2',
    title: 'Murder in My Mind',
    artist: 'Kordhell',
    genres: ['phonk', 'night phonk'],
  ),
  _r(
    '3',
    title: 'Birds of a Feather',
    artist: 'Billie Eilish',
    genres: ['pop'],
    score: 5,
  ),
  _r('4', title: 'Lunch', artist: 'Billie Eilish', genres: ['pop'], score: 4),
];

const _music = [
  MusicResult(
    title: 'Birds of a Feather',
    artist: 'Billie Eilish',
    isAlbum: false,
    spotifyUrl: 'https://open.spotify.com/track/x',
  ),
  MusicResult(
    title: 'Hit Me Hard and Soft',
    artist: 'Billie Eilish',
    isAlbum: true,
    spotifyUrl: 'https://open.spotify.com/album/y',
  ),
];

Future<void> _search(
  WidgetTester tester,
  String query, {
  List<ReviewWithDocId>? pool,
  List<MusicResult> music = _music,
}) async {
  await pumpScreen(
    tester,
    const SearchScreen(),
    overrides: [
      ...reviewScreenOverrides(user: testUser),
      searchPoolProvider.overrideWith((ref) async => pool ?? _pool),
      musicSearchProvider.overrideWith((ref, q) async => music),
      musicNewsProvider.overrideWith((ref) => Stream.value(const [])),
    ],
  );
  await tester.pump();
  await tester.enterText(find.byType(TextField), query);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('matching', () {
    test('tags: exact first, then by use; words inside tags count', () {
      final tags = matchTags(_pool, 'phonk');
      expect(tags.first, const TagMatch('phonk', 2));
      expect(tags.map((t) => t.tag), contains('night phonk'));
      expect(matchTags(_pool, 'p'), isEmpty, reason: 'too short');
    });

    test('artist: a word starting with the query; rating and count', () {
      final a = matchArtist(_pool, 'billie')!;
      expect(a.name, 'Billie Eilish');
      expect(a.reviewCount, 2);
      expect(a.averageScore, 4.5);
      expect(
        matchArtist(_pool, 'jp')!.name,
        'JP Nogueira',
        reason: 'each name in "A, B" counts',
      );
      expect(matchArtist(_pool, 'zzz'), isNull);
    });

    test('articles: every word in album, artist, tags or genres', () {
      final albums = groupNewsAlbums([
        MusicNewsItem(
          id: '1',
          source: 'nme',
          sourceName: 'NME',
          label: 'Album Review',
          title: 'x',
          album: 'Hit Me Hard and Soft',
          artist: 'Billie Eilish',
          summary: '',
          author: '',
          url: 'https://a',
          publishedAt: DateTime(2026),
          genres: ['Pop'],
        ),
      ]);
      expect(matchArticles(albums, 'billie'), hasLength(1));
      expect(matchArticles(albums, 'billie pop'), hasLength(1));
      expect(matchArticles(albums, 'billie metal'), isEmpty);
    });
  });

  testWidgets('"phonk": the tag on top, then tags, reviews and music', (
    tester,
  ) async {
    await _search(tester, 'phonk', music: const []);
    expect(find.text('#phonk'), findsOneWidget);
    expect(find.text('Open tag page'), findsOneWidget);
    expect(find.text('night phonk'), findsWidgets);
    expect(find.textContaining('REVIEWS'), findsWidgets);
    expect(find.text('TELL EM IN BRAZIL'), findsOneWidget);
  });

  testWidgets('"billie": the artist on top with REVERB rating', (tester) async {
    await _search(tester, 'billie');
    expect(find.text('ARTIST'), findsOneWidget);
    expect(find.text('Billie Eilish'), findsWidgets);
    expect(find.text('★ 4.5 · 2 reviews on REVERB'), findsOneWidget);
    expect(find.text('Review a song'), findsOneWidget);
    expect(find.text('Hit Me Hard and Soft'), findsOneWidget);
  });

  testWidgets('no reviews: music first, inviting the first review', (
    tester,
  ) async {
    await _search(tester, 'feather', pool: const []);
    expect(find.text('BE THE FIRST TO REVIEW  ·  2'), findsOneWidget);
    expect(find.text('Birds of a Feather'), findsOneWidget);
    expect(find.text('Review'), findsNWidgets(2));
  });

  testWidgets('scope pills narrow to one kind', (tester) async {
    await _search(tester, 'billie');
    expect(find.text('Music'), findsOneWidget);
    await tester.tap(find.text('Music'));
    await tester.pump();
    expect(find.text('ARTIST'), findsNothing);
    expect(find.text('Hit Me Hard and Soft'), findsOneWidget);
    await tester.tap(find.text('Reviews'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Lunch'), findsOneWidget);
  });

  testWidgets('nothing anywhere: a helpful empty state', (tester) async {
    await _search(tester, 'zzzz', music: const []);
    expect(find.text('Nothing found for "zzzz"'), findsOneWidget);
  });
}
