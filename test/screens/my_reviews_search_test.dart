import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/providers/reviews_provider.dart';
import 'package:flutter_test_project/providers/search_reviews_provider.dart';
import 'package:flutter_test_project/ui/screens/search/search_screen.dart';

import '../helpers/screen_harness.dart';

ReviewWithDocId _mine(String id, Review review) => ReviewWithDocId(
  review: review,
  docId: id,
  fullReviewId: 'users/me/reviews/$id',
);

void main() {
  group('matchesReviewQuery', () {
    final r = sampleReview(
      title: 'Thinkin Bout You',
      artist: 'Frank Ocean',
      text: 'The falsetto in the chorus wrecks me.',
      genres: const ['R&B', 'neo soul'],
    );

    test('artist, song, tags and text', () {
      for (final q in ['frank', 'OCEAN', 'thinkin', 'neo soul', 'falsetto']) {
        expect(matchesReviewQuery(r, q), isTrue, reason: q);
      }
    });

    test('every word must match somewhere; spellings fold like tags', () {
      expect(matchesReviewQuery(r, 'frank falsetto'), isTrue);
      expect(matchesReviewQuery(r, 'frank metal'), isFalse);
      expect(matchesReviewQuery(r, 'rnb'), isTrue, reason: '"rnb" finds R&B');
      expect(matchesReviewQuery(r, '   '), isFalse);
    });
  });

  testWidgets('searches only my reviews, not reposts', (tester) async {
    final mine = [
      _mine(
        '1',
        sampleReview(title: 'Nights', artist: 'Frank Ocean', userId: 'me'),
      ),
      _mine(
        '2',
        sampleReview(title: 'Bang Bang', artist: 'Nancy Sinatra', userId: 'me'),
      ),
      _mine(
        '3',
        Review(
          displayName: 'x',
          userId: 'me',
          artist: 'Frank Ocean',
          review: 'repost',
          score: 5,
          likes: 0,
          replies: 0,
          reposts: 0,
          title: 'Pink + White',
          isRepost: true,
        ),
      ),
    ];
    await pumpScreen(
      tester,
      const SearchScreen(ownReviewsOnly: true),
      overrides: [
        ...reviewScreenOverrides(user: testUser),
        userReviewsProvider.overrideWith((ref) => Stream.value(mine)),
      ],
    );
    await tester.pump();
    expect(find.text('Search your reviews'), findsOneWidget);
    expect(find.textContaining('Find your reviews'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'frank');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('1 of your review'), findsOneWidget);
    expect(find.text('Nights'), findsOneWidget);
    expect(find.text('Pink + White'), findsNothing, reason: 'reposts left out');

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.textContaining('None of your reviews match'), findsOneWidget);
  });
}
