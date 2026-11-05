import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/providers/community_reviews_provider.dart';
import 'package:flutter_test_project/providers/reviews_provider.dart';
import 'package:flutter_test_project/providers/tag_reviews_provider.dart';
import 'package:flutter_test_project/ui/screens/tag/tag_reviews_page.dart';
import 'package:flutter_test_project/ui/widgets/genre_pills.dart';

ReviewWithDocId _r(String id, List<String> genres,
        {bool repost = false, int day = 1}) =>
    ReviewWithDocId(
      docId: id,
      fullReviewId: 'users/u/reviews/$id',
      review: Review(
        displayName: 'u',
        userId: 'u',
        artist: 'Artist',
        review: 'text',
        score: 4,
        likes: 0,
        replies: 0,
        reposts: 0,
        title: 'Song $id',
        genres: genres,
        date: DateTime(2026, 1, day),
        isRepost: repost,
      ),
    );

List<String> _ids(List<ReviewWithDocId> reviews) =>
    [for (final r in reviews) r.docId];

/// A review in [db], with the search keys the app writes when posting.
Future<void> _seed(
  FakeFirebaseFirestore db,
  String id, {
  List<String> genres = const [],
  String text = '',
  int day = 1,
  bool repost = false,
}) =>
    db.doc('users/u/reviews/$id').set({
      'userId': 'u',
      'displayName': 'u',
      'artist': 'Artist',
      'title': 'Song $id',
      'review': text,
      'score': 4,
      'genres': genres,
      'date': Timestamp.fromDate(DateTime(2026, 1, day)),
      if (repost) 'isRepost': true,
      ...searchKeysFor(genres: genres, review: text, isRepost: repost),
    });

ProviderContainer _container(FakeFirebaseFirestore db) {
  final container = ProviderContainer(
    overrides: [firestoreProvider.overrideWithValue(db)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('searchKeysFor', () {
    // Shared with the Cloud Functions tests, so both sides build the same
    // keys (functions/src/__tests__/searchKeys.test.ts).
    final fixtures = jsonDecode(
        File('functions/src/__tests__/fixtures/search_keys.json')
            .readAsStringSync()) as List<dynamic>;
    for (final f in fixtures.cast<Map<String, dynamic>>()) {
      test(f['name'], () {
        final review = f['review'] as Map<String, dynamic>;
        final keys = searchKeysFor(
          genres: (review['genres'] as List?)?.cast<String>(),
          tags: (review['tags'] as List?)?.cast<String>(),
          review: review['review'] as String? ?? '',
          isRepost: review['isRepost'] == true,
        );
        expect(keys, {
          for (final e in (f['keys'] as Map<String, dynamic>).entries)
            e.key: (e.value as List).cast<String>(),
        });
      });
    }

    test('indexes at most $maxTextWordKeys words of long reviews', () {
      final text = List.generate(400, (i) => 'word$i').join(' ');
      expect(searchKeysFor(review: text)['textWordKeys'],
          hasLength(maxTextWordKeys));
    });
  });

  group('mentionsTag', () {
    test('finds the tag as whole words, in any spelling', () {
      expect(mentionsTag('Loved the smooth R and B vibe', 'r&b'), isTrue);
      expect(mentionsTag('Pure hip-hop energy', 'hip hop'), isTrue);
    });

    test('not inside other words', () {
      expect(mentionsTag('rocking chair', 'rock'), isFalse);
      expect(mentionsTag('', 'rock'), isFalse);
    });
  });

  group('tag feed', () {
    test('tagged, then similar, then mentions — newest first, no reposts',
        () async {
      final db = FakeFirebaseFirestore();
      await _seed(db, 'e1', genres: ['R&B'], day: 1);
      await _seed(db, 'e2', genres: ['rnb', 'soul'], day: 3);
      await _seed(db, 's1', genres: ['alternative r&b'], day: 2);
      await _seed(db, 'm1',
          genres: ['pop'], text: 'Very R and B inspired', day: 4);
      await _seed(db, 'x1', genres: ['rock'], text: 'nothing here', day: 5);
      await _seed(db, 'rp', genres: ['r&b'], day: 6, repost: true);

      final feed = await _container(db).read(tagFeedProvider('R&B').future);

      expect(_ids(feed.exact), ['e2', 'e1']);
      expect(_ids(feed.similar), ['s1']);
      expect(_ids(feed.mentions), ['m1']);
      expect(feed.exactCount, 2);
      expect(feed.similarCount, 1);
      expect(feed.related, containsAll(['soul', 'alternative r&b']));
      expect(feed.hasMore, isFalse);
    });

    test('pages: Tagged fills first, then later sections', () async {
      final db = FakeFirebaseFirestore();
      for (var i = 1; i <= 25; i++) {
        await _seed(db, 'e$i', genres: ['jazz'], day: i);
      }
      await _seed(db, 's1', genres: ['smooth jazz'], day: 1);
      final container = _container(db);

      final first = await container.read(tagFeedProvider('jazz').future);
      expect(first.exact, hasLength(tagPageSize));
      expect(first.exact.first.docId, 'e25', reason: 'newest first');
      expect(first.similar, isEmpty);
      expect(first.hasMore, isTrue);

      await container.read(tagFeedProvider('jazz').notifier).loadMore();
      final second = container.read(tagFeedProvider('jazz')).requireValue;
      expect(second.exact, hasLength(25));
      expect(_ids(second.similar), ['s1']);
      expect(second.all.map((r) => r.docId).toSet(), hasLength(26),
          reason: 'no review appears twice');
    });

    test('shows Popular matches already in memory while the first page loads',
        () async {
      final db = FakeFirebaseFirestore();
      await _seed(db, 'db1', genres: ['house'], day: 2);
      final container = ProviderContainer(overrides: [
        firestoreProvider.overrideWithValue(db),
        communityReviewsProvider.overrideWith((ref) => Stream.value([
              _r('pop1', ['house'])
            ])),
      ]);
      addTearDown(container.dispose);
      // The Popular feed is open behind the tag page.
      container.listen(communityReviewsProvider, (_, __) {});
      await container.read(communityReviewsProvider.future);

      final states = <TagFeed>[];
      container.listen<AsyncValue<TagFeed>>(
          tagFeedProvider('house'), (_, next) => next.whenData(states.add),
          fireImmediately: true);
      await container.read(tagFeedProvider('house').future);
      expect(states.first.isPreview, isTrue);
      expect(_ids(states.first.exact), ['pop1']);

      // Then the real results replace it.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final real = container.read(tagFeedProvider('house')).requireValue;
      expect(real.isPreview, isFalse);
      expect(_ids(real.exact), ['db1']);
    });

    test('before the index exists, searches the newest reviews instead',
        () async {
      final db = FakeFirebaseFirestore();
      // Older reviews: no search keys yet.
      await db.doc('users/u/reviews/old').set({
        'userId': 'u',
        'review': 'great',
        'score': 4,
        'genres': ['funk'],
        'date': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });

      final feed = await _container(db).read(tagFeedProvider('funk').future);
      expect(_ids(feed.exact), ['old']);
    });
  });

  group('normalizeTag', () {
    test('folds spelling variants', () {
      expect(normalizeTag('R&B'), 'r&b');
      expect(normalizeTag('rnb'), 'r&b');
      expect(normalizeTag('R and B'), 'r&b');
      expect(normalizeTag('Alternative R & B'), 'alternative r&b');
      expect(normalizeTag('Hip-Hop'), 'hip hop');
      expect(normalizeTag('hiphop'), 'hip hop');
    });
  });

  group('tagsSimilar', () {
    test('one tag inside another, as whole words', () {
      expect(tagsSimilar('r&b', 'alternative r&b'), isTrue);
      expect(tagsSimilar('chill dance', 'chill'), isTrue);
    });

    test('a shared meaningful word', () {
      expect(tagsSimilar('chill dance', 'relaxing dance'), isTrue);
    });

    test('not on generic words or partial words', () {
      expect(tagsSimilar('soul music', 'dance music'), isFalse);
      expect(tagsSimilar('rock', 'rocksteady'), isFalse);
      expect(tagsSimilar('jazz', 'calm'), isFalse);
    });
  });

  test('groupByTag: exact first, then similar, newest first, no reposts', () {
    final result = groupByTag('R&B', [
      _r('exact-old', ['r&b', 'soul'], day: 1),
      _r('exact-new', ['RnB'], day: 5),
      _r('similar', ['alternative r&b', 'chill'], day: 3),
      _r('repost', ['r&b'], repost: true, day: 9),
      _r('unrelated', ['rock'], day: 9),
    ]);
    expect(_ids(result.exact), ['exact-new', 'exact-old']);
    expect(_ids(result.similar), ['similar']);
    expect(result.related, ['soul', 'alternative r&b', 'chill']);
  });

  testWidgets('tapping a pill opens that tag, but not the same tag twice',
      (tester) async {
    var pushes = 0;
    await tester.pumpWidget(ProviderScope(
        overrides: [
          // An empty database: the tag page opens with no reviews.
          firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
        ],
        child: MaterialApp(
          navigatorObservers: [_PushCounter(() => pushes++)],
          onGenerateRoute: (_) => MaterialPageRoute(
            settings: RouteSettings(name: tagRouteName('chill')),
            builder: (_) => const Scaffold(
              body: GenrePills(tags: ['chill', 'calm']),
            ),
          ),
        )));
    pushes = 0;

    await tester.tap(find.text('chill'));
    await tester.pump();
    expect(pushes, 0, reason: 'already on the chill page');

    await tester.tap(find.text('calm'));
    await tester.pump();
    expect(pushes, 1);
  });
}

class _PushCounter extends NavigatorObserver {
  _PushCounter(this.onPush);
  final VoidCallback onPush;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => onPush();
}
