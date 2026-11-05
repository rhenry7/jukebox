import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/providers/auth_provider.dart';
import 'package:flutter_test_project/providers/reviews_provider.dart';
import 'package:flutter_test_project/ui/widgets/review_options.dart';

ReviewWithDocId _review(String userId) => ReviewWithDocId(
      docId: 'r1',
      review: Review(
        displayName: 'Someone',
        userId: userId,
        artist: 'Artist',
        review: 'Great record',
        score: 4,
        likes: 0,
        replies: 0,
        reposts: 0,
        title: 'Album',
      ),
    );

Future<FakeFirebaseFirestore> _pump(WidgetTester tester, String owner,
    {VoidCallback? onDeleted}) async {
  final db = FakeFirebaseFirestore();
  await db.doc('users/me/reviews/r1').set({'title': 'Album'});
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWithValue('me'),
      firestoreProvider.overrideWithValue(db),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: OwnReviewOptions(
          review: _review(owner),
          onDeleted: onDeleted,
          child: const SizedBox(width: 400, height: 120, child: Text('card')),
        ),
      ),
    ),
  ));
  return db;
}

void main() {
  testWidgets("other people's reviews don't swipe", (tester) async {
    await _pump(tester, 'someone-else');
    expect(find.byType(Dismissible), findsNothing);
  });

  testWidgets('swiping your own review opens its options', (tester) async {
    await _pump(tester, 'me');
    await tester.drag(find.text('card'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Edit review'), findsOneWidget);
    expect(find.text('Delete review'), findsOneWidget);
    // The card stays in place.
    expect(find.text('card'), findsOneWidget);
  });

  testWidgets('delete removes the review after confirming', (tester) async {
    var deleted = false;
    final db = await _pump(tester, 'me', onDeleted: () => deleted = true);
    await tester.longPress(find.text('card'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect((await db.doc('users/me/reviews/r1').get()).exists, isFalse);
    expect(deleted, isTrue);
  });
}
