import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/providers/auth_provider.dart';
import 'package:flutter_test_project/providers/recommended_reviews_provider.dart';
import 'package:flutter_test_project/providers/reviews_provider.dart';
import 'package:flutter_test_project/ui/widgets/review_options.dart';

import '../helpers/screen_harness.dart';

void main() {
  late FakeFirebaseFirestore db;
  setUp(() => db = FakeFirebaseFirestore());

  Future<void> pump(WidgetTester tester, {required String author}) =>
      pumpScreen(
        tester,
        Scaffold(
          body: Center(
            child: NotForMeOptions(
              review: ReviewWithDocId(
                review: sampleReview(userId: author),
                docId: 'r1',
                fullReviewId: 'users/$author/reviews/r1',
              ),
              child: const SizedBox(
                width: 300,
                height: 120,
                child: Text('Card'),
              ),
            ),
          ),
        ),
        overrides: [
          currentUserProvider.overrideWithValue(testUser),
          firestoreProvider.overrideWithValue(db),
        ],
      );

  testWidgets('long-press → Not for me saves feedback and confirms', (
    tester,
  ) async {
    await pump(tester, author: 'someone');
    await tester.longPress(find.text('Card'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Not for me'), findsOneWidget);

    await tester.tap(find.text('Not for me'));
    await tester.pump(const Duration(milliseconds: 300));

    final doc = await db
        .doc('users/${testUser.uid}/forYouFeedback/users__someone__reviews__r1')
        .get();
    expect(doc.data()?['reason'], 'not_for_me');
    expect(doc.data()?['reviewPath'], 'users/someone/reviews/r1');
    expect(find.text("Got it. You'll see less like this."), findsOneWidget);
  });

  testWidgets('own reviews have no Not for me', (tester) async {
    await pump(tester, author: testUser.uid);
    await tester.longPress(find.text('Card'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Not for me'), findsNothing);
    expect(find.byType(Dismissible), findsNothing);
  });

  test('forYouDismissedProvider lists dismissed reviews', () async {
    await db.doc('users/me/forYouFeedback/x').set({
      'reviewPath': 'users/a/reviews/1',
      'reason': 'not_for_me',
    });
    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWithValue(testUser),
        firestoreProvider.overrideWithValue(db),
      ],
    );
    addTearDown(container.dispose);
    final dismissed = await container.read(forYouDismissedProvider.future);
    expect(dismissed, {'users/a/reviews/1'});
  });
}
