import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/providers/auth_provider.dart';
import 'package:flutter_test_project/providers/recommended_reviews_provider.dart';
import 'package:flutter_test_project/providers/reviews_provider.dart';
import 'package:flutter_test_project/services/for_you_service.dart';

Map<String, dynamic> _review(String title, String userId) => {
      'displayName': 'someone',
      'userId': userId,
      'artist': 'Artist',
      'title': title,
      'review': 'Great tape hiss and lazy drums.',
      'score': 4.5,
      'likes': 0,
      'replies': 0,
      'reposts': 0,
    };

void main() {
  late FakeFirebaseFirestore db;

  setUp(() async {
    db = FakeFirebaseFirestore();
    await db.doc('users/b/reviews/r1').set(_review('Neon Rain', 'b'));
    await db.doc('users/c/reviews/r2').set(_review('Subway Shimmer', 'c'));
  });

  group('ForYouService', () {
    test('emits null when no server-built list exists (caller falls back)',
        () async {
      expect(await ForYouService.watchEntries('a', db: db).first, isNull);
    });

    test('reads the list in server order, with scores and reasons', () async {
      await db.doc('users/a/forYou/current').set({
        'items': [
          {
            'reviewPath': 'users/c/reviews/r2',
            'score': 0.9,
            'reason': 'Also praises crisp drums'
          },
          {'reviewPath': 'users/b/reviews/r1', 'score': 0.7},
        ],
      });

      final entries = (await ForYouService.watchEntries('a', db: db).first)!;
      expect(entries.map((e) => e.reviewPath),
          ['users/c/reviews/r2', 'users/b/reviews/r1']);
      expect(entries.first.score, 0.9);
      expect(entries.first.reason, 'Also praises crisp drums');
      expect(entries.last.reason, isNull);
    });

    test('fetchReviews keeps order and skips deleted reviews', () async {
      final reviews = await ForYouService.fetchReviews(
        ['users/c/reviews/r2', 'users/b/reviews/gone', 'users/b/reviews/r1'],
        db: db,
      );
      expect(
          reviews.map((r) => r.review.title), ['Subway Shimmer', 'Neon Rain']);
      expect(reviews.first.fullReviewId, 'users/c/reviews/r2');
    });
  });

  group('recommendedReviewsProvider', () {
    late ProviderContainer container;

    setUp(() async {
      // 12 recommendations; only the first 5 reviews exist so far.
      await db.doc('users/a/forYou/current').set({
        'items': [
          for (var i = 0; i < 12; i++)
            {'reviewPath': 'users/x/reviews/p$i', 'score': 1 - i / 100},
        ],
      });
      for (var i = 0; i < 5; i++) {
        await db.doc('users/x/reviews/p$i').set(_review('Song $i', 'x'));
      }
      container = ProviderContainer(overrides: [
        currentUserIdProvider.overrideWithValue('a'),
        firestoreProvider.overrideWithValue(db),
      ]);
      container.listen(recommendedReviewsProvider, (_, __) {});
    });

    tearDown(() => container.dispose());

    /// Every state the feed shows until [count] cards are in.
    Future<List<ForYouFeed>> statesUntil(int count) async {
      final states = <ForYouFeed>[];
      final done = Completer<void>();
      final sub = container.listen<AsyncValue<ForYouFeed>>(
        recommendedReviewsProvider,
        (_, next) {
          final feed = next.valueOrNull;
          if (feed == null) return;
          if (states.isEmpty || !identical(states.last, feed)) states.add(feed);
          if (feed.loaded.length >= count && !done.isCompleted) done.complete();
        },
        fireImmediately: true,
      );
      await done.future.timeout(const Duration(seconds: 5));
      sub.close();
      return states;
    }

    List<String> titles(ForYouFeed f) =>
        [for (final s in f.loaded) s.reviewWithDocId.review.title];

    test('loads only the reviews on screen, then more as the limit grows',
        () async {
      final first = (await statesUntil(5)).last;
      expect(first.total, 12);
      expect(titles(first), ['Song 0', 'Song 1', 'Song 2', 'Song 3', 'Song 4']);

      // Reviews 5–11 appear only now. Had the first load fetched them, they'd
      // be remembered as deleted and stay missing.
      for (var i = 5; i < 12; i++) {
        await db.doc('users/x/reviews/p$i').set(_review('Song $i', 'x'));
      }
      container.read(loadMoreRecommendedReviewsProvider)();
      final more = (await statesUntil(12)).last;
      expect(more.loaded, hasLength(12));
      expect(more.loaded.last.reviewWithDocId.review.title, 'Song 11');
      expect(more.loaded.first.finalScore, 1.0);
    });

    test('cards appear top-down as they arrive, never out of order or empty',
        () async {
      final states = await statesUntil(5);
      final finalTitles = titles(states.last);
      for (final state in states) {
        expect(state.loaded, isNotEmpty);
        expect(finalTitles.take(state.loaded.length), titles(state),
            reason: 'each step is the top of the final list');
      }
    });
  });
}
