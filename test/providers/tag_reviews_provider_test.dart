import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/models/review.dart';
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

void main() {
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
          tagReviewsProvider.overrideWith((ref, tag) async => (
                exact: <ReviewWithDocId>[],
                similar: <ReviewWithDocId>[],
                related: <String>[]
              )),
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
