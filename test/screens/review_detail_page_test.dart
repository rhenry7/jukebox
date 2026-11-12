import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/ui/screens/review_detail/review_detail_page.dart';
import 'package:flutter_test_project/ui/widgets/review_comments.dart'
    show CommentComposer;

import '../helpers/screen_harness.dart';

const _path = 'users/someone/reviews/r1';

/// The page's own scroll view (the comment box has one too).
final _page = find.byType(Scrollable).first;

void main() {
  testWidgets('shows the review: song, artist, reviewer, text, like count', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      ReviewDetailPage(review: sampleReview(), reviewId: _path),
      overrides: reviewScreenOverrides(user: testUser, likeCount: 3),
    );
    await tester.pump();

    expect(find.text('Bang Bang'), findsOneWidget);
    expect(find.text('Nancy Sinatra'), findsOneWidget);
    expect(find.text('wuTangFan'), findsOneWidget);
    expect(find.textContaining('haunting guitar'), findsOneWidget);
    expect(find.text('3'), findsOneWidget, reason: 'like count');
  });

  testWidgets('signed out: comments say to sign in, never spin', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      ReviewDetailPage(review: sampleReview(), reviewId: _path),
      // A comments read that never answers, like the old permission error.
      overrides: reviewScreenOverrides(
        user: null,
        comments: StreamController<Never>().stream,
      ),
    );
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('Sign in to read the comments.'),
      200,
      scrollable: _page,
    );
    expect(find.text('Sign in to read the comments.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('signed in: lists the comments with a count', (tester) async {
    await pumpScreen(
      tester,
      ReviewDetailPage(review: sampleReview(), reviewId: _path),
      overrides: reviewScreenOverrides(
        user: testUser,
        comments: Stream.value([
          sampleComment('c1', 'Love the reverb'),
          sampleComment('c2', 'Classic'),
        ]),
      ),
    );
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('Comments (2)'),
      200,
      scrollable: _page,
    );
    expect(find.text('Love the reverb'), findsOneWidget);
    expect(find.text('Classic'), findsOneWidget);
  });

  testWidgets('a failed comments load says so instead of spinning', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      ReviewDetailPage(review: sampleReview(), reviewId: _path),
      overrides: reviewScreenOverrides(
        user: testUser,
        comments: Stream.error('permission-denied'),
      ),
    );
    await tester.pump();

    await tester.scrollUntilVisible(
      find.textContaining("Couldn't load the comments"),
      200,
      scrollable: _page,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('the comment box sits right on top of the keyboard, and grows', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      ReviewDetailPage(review: sampleReview(), reviewId: _path),
      overrides: reviewScreenOverrides(user: testUser),
    );
    await tester.pump();
    final box = find.byType(CommentComposer);
    expect(
      tester.getRect(box).bottom,
      closeTo(844, 1),
      reason: 'at rest: at the bottom',
    );
    expect(find.textContaining('Comment on'), findsNothing);
    final restingTyping = tester.getSize(find.byType(TextField).last).height;

    // The phone keyboard opens: 300 px tall.
    await tester.tap(find.byType(TextField).last);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final open = tester.getRect(box);
    // Open, the typing area is ~70% taller than at rest.
    final typing = tester.getSize(find.byType(TextField).last).height;
    expect(typing / restingTyping, greaterThan(1.6));
    expect(
      open.bottom,
      closeTo(844 - 300, 1),
      reason: 'directly above the keyboard',
    );
    expect(open.top, greaterThan(0), reason: 'fully on screen');
    expect(find.text('Bang Bang'), findsWidgets);
    expect(find.textContaining('Comment on'), findsOneWidget);

    // Several lines of text: the box grows upward, still above the keyboard.
    await tester.enterText(
      find.byType(TextField).last,
      'one\ntwo\nthree\nfour',
    );
    await tester.pump();
    final grown = tester.getRect(box);
    expect(grown.height, greaterThan(open.height));
    expect(grown.bottom, closeTo(844 - 300, 1));
    expect(find.text('one\ntwo\nthree\nfour'), findsOneWidget);
  });
}
