import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/ui/widgets/genre_pills.dart';

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
        find.ancestor(of: find.text(t), matching: find.byType(ClipRRect)).first,
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
}
