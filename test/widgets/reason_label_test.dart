import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/ui/theme/tokens.dart';
import 'package:flutter_test_project/ui/widgets/reason_label.dart';

void main() {
  testWidgets('the reason is a grey pill above the card, no icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WithReason(
            reason: 'Also praises great bassline, like your review of X',
            child: SizedBox(height: 100, child: Placeholder()),
          ),
        ),
      ),
    );
    expect(
      find.text('Also praises great bassline, like your review of X'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.auto_awesome), findsNothing);
    final box = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(ReasonLabel),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect((box.decoration as BoxDecoration).color, AppColors.pill);
    // As wide as its text, not the whole row.
    expect(
      tester.getSize(find.byType(DecoratedBox).first).width,
      lessThan(tester.getSize(find.byType(Placeholder)).width),
    );
  });

  testWidgets('no reason: just the card', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: WithReason(reason: null, child: Placeholder())),
    );
    expect(find.byType(ReasonLabel), findsNothing);
  });
}
