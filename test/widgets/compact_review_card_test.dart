import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/ui/widgets/genre_pills.dart';

void main() {
  testWidgets('single-line pills show only what fits, with no overflow',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 200,
            height: 40,
            child: GenrePills(
              tags: [
                'alternative rock',
                'classic rock',
                'shoegaze',
                'indie',
                'dream pop',
                'noise'
              ],
              maxTags: 5,
              topPadding: 0,
              singleLine: true,
              tappable: false,
            ),
          ),
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    // Five are laid out, but a pill pushed to a second line is clipped away.
    final shown = find.byType(Chip).evaluate().where((e) {
      final box = e.renderObject! as RenderBox;
      return box.localToGlobal(Offset.zero).dy < 400;
    });
    expect(shown.length, lessThan(5));
    expect(find.text('noise'), findsNothing);
  });
}
