import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/ui/widgets/card_surface.dart';
import 'package:flutter_test_project/ui/widgets/review_card.dart';

import '../helpers/screen_harness.dart';

const _reason = 'Sounds like Candi Staton, which you rated highly';

void main() {
  testWidgets("a recommendation's reason sits inside its card, no icon", (
    tester,
  ) async {
    await pumpScreen(
      tester,
      SingleChildScrollView(
        child: ReviewCardWithGenres(
          review: sampleReview(),
          reviewId: 'users/someone/reviews/1',
          reason: _reason,
        ),
      ),
      overrides: reviewScreenOverrides(user: testUser),
    );
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(CardSurface),
        matching: find.text(_reason),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.auto_awesome), findsNothing);
    // Above the song, at the top of the card.
    expect(
      tester.getTopLeft(find.text(_reason)).dy,
      lessThan(tester.getTopLeft(find.text('Bang Bang')).dy),
    );
  });

  testWidgets('no reason: no header', (tester) async {
    await pumpScreen(
      tester,
      SingleChildScrollView(
        child: ReviewCardWithGenres(
          review: sampleReview(),
          reviewId: 'users/someone/reviews/1',
        ),
      ),
      overrides: reviewScreenOverrides(user: testUser),
    );
    await tester.pump();
    expect(find.text(_reason), findsNothing);
  });
}
