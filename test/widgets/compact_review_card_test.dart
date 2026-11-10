import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/ui/widgets/genre_pills.dart';
import 'package:flutter_test_project/ui/widgets/review_card.dart';

import '../helpers/screen_harness.dart';

void main() {
  testWidgets('single-line pills show only what fits, with no overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              height: 60, // one line of pills (44 px in the test font)
              child: GenrePills(
                tags: [
                  'alternative rock',
                  'classic rock',
                  'shoegaze',
                  'indie',
                  'dream pop',
                  'noise',
                ],
                maxTags: 5,
                topPadding: 0,
                singleLine: true,
                tappable: false,
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    // Five are laid out, but any pushed to a second line sits below the
    // box and is clipped away.
    const tags = [
      'alternative rock',
      'classic rock',
      'shoegaze',
      'indie',
      'dream pop',
    ];
    final box = tester.getRect(find.byType(GenrePills));
    var shown = 0;
    for (final t in tags) {
      final pill = tester.getRect(
        find.ancestor(of: find.text(t), matching: find.byType(TagPill)).first,
      );
      final inside = box.intersect(pill);
      final visible = inside.width > 0 && inside.height > 0;
      // Whole or not at all: never a pill cut in half.
      if (visible) {
        expect(
          inside.height,
          moreOrLessEquals(pill.height),
          reason: '"$t" is only partly visible',
        );
        shown++;
      }
    }
    expect(shown, inInclusiveRange(1, 4));
    expect(find.text('noise'), findsNothing, reason: 'over maxTags');
  });

  testWidgets('shows why it was suggested before the tags', (tester) async {
    await pumpScreen(
      tester,
      Center(
        child: CompactReviewCard(
          review: sampleReview(genres: const ['country', 'western']),
          reviewId: 'users/someone/reviews/1',
          reason: 'Similar artist',
        ),
      ),
      overrides: reviewScreenOverrides(),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    expect(find.text('Similar artist'), findsOneWidget);
    expect(find.text('country'), findsOneWidget);
    final reason = tester.getTopLeft(find.text('Similar artist'));
    final tag = tester.getTopLeft(find.text('country'));
    expect(reason.dx, lessThan(tag.dx), reason: 'reason comes first');
  });

  testWidgets('no reason: just the tags', (tester) async {
    await pumpScreen(
      tester,
      Center(
        child: CompactReviewCard(
          review: sampleReview(),
          reviewId: 'users/someone/reviews/1',
        ),
      ),
      overrides: reviewScreenOverrides(),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Similar artist'), findsNothing);
    expect(find.text('country'), findsOneWidget);
  });
}
