import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/providers/auth_provider.dart';
import 'package:flutter_test_project/providers/tag_suggestions_provider.dart';
import 'package:flutter_test_project/ui/widgets/app_states.dart';
import 'package:flutter_test_project/ui/screens/addReview/reviewSheetContentForm.dart';

import '../helpers/screen_harness.dart';

const _form = MyReviewSheetContentForm(
  title: 'Bang Bang',
  artist: 'Nancy Sinatra',
  albumImageUrl: 'https://i.scdn.co/image/test',
);

/// A save that waits until the test lets it finish, counting calls.
class _FakeSave {
  final calls = <String>[];
  final done = Completer<String?>();

  Future<String?> call(
    String review,
    double score,
    String artist,
    String title,
    bool liked,
    String albumImageUrl,
    List<String>? genres, {
    required String reviewId,
    String? spotifyUrl,
  }) {
    calls.add(review);
    return done.future;
  }
}

Future<void> _pumpForm(
  WidgetTester tester, {
  required bool signedIn,
  _FakeSave? save,
  List<String> suggestions = const [],
  Completer<List<String>>? pendingSuggestions,
}) async {
  await pumpScreen(
    tester,
    const Scaffold(body: _form),
    overrides: [
      currentUserProvider.overrideWithValue(signedIn ? testUser : null),
      if (save != null) reviewSubmitterProvider.overrideWithValue(save.call),
      tagSuggestionsProvider.overrideWith(
        (ref, track) => pendingSuggestions?.future ?? Future.value(suggestions),
      ),
    ],
  );
  await tester.pump();
}

Future<void> _writeReview(WidgetTester tester, String text) async {
  await tester.tap(
    find.text(
      'Better reviews lead to better recommendations, '
      'so tell me how you feel, how you really-really feel',
    ),
  );
  await _settle(tester);
  await tester.enterText(find.byType(TextField).last, text);
  await tester.tap(find.text('Done'));
  await _settle(tester);
}

Finder get _save => find.text('Save Review');

/// Lets taps, page transitions and snackbars finish. (pumpAndSettle never
/// returns here: the album art's placeholder keeps animating, since tests
/// can't download images.)
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('signed out: Save Review asks to sign in, saves nothing', (
    tester,
  ) async {
    final save = _FakeSave();
    await _pumpForm(tester, signedIn: false, save: save);

    await tester.tap(_save);
    await _settle(tester);

    expect(find.textContaining("crates don't open themselves"), findsOneWidget);
    expect(save.calls, isEmpty);
  });

  testWidgets('needs a review and a tag before saving', (tester) async {
    final save = _FakeSave();
    await _pumpForm(tester, signedIn: true, save: save);

    await tester.tap(_save);
    await tester.pump();

    expect(
      find.text('Please write your review and add at least one tag'),
      findsOneWidget,
    );
    expect(save.calls, isEmpty);
  });

  testWidgets('one tap, one review: Save is locked while it saves', (
    tester,
  ) async {
    final save = _FakeSave();
    await _pumpForm(tester, signedIn: true, save: save);
    await tester.enterText(find.widgetWithText(TextField, 'Tags'), 'country');
    await _writeReview(tester, 'Haunting and gorgeous.');

    await tester.tap(_save);
    await tester.pump();
    // A slow network: the save hasn't finished. More taps change nothing.
    await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
    await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
    await tester.pump();

    expect(save.calls, ['Haunting and gorgeous.']);
    expect(_save, findsNothing, reason: 'spinner in place of the label');
    expect(
      find.descendant(
        of: find.byType(ElevatedButton),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull, reason: 'disabled while saving');
  });

  testWidgets('a failed save re-enables the button and says so', (
    tester,
  ) async {
    final save = _FakeSave();
    await _pumpForm(tester, signedIn: true, save: save);
    await tester.enterText(find.widgetWithText(TextField, 'Tags'), 'country');
    await _writeReview(tester, 'Haunting.');

    await tester.tap(_save);
    await tester.pump();
    save.done.completeError(Exception('offline'));
    await _settle(tester);

    expect(find.textContaining("Couldn't save your review"), findsOneWidget);
    expect(_save, findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('suggested tags: tap to add; typed ones drop out', (
    tester,
  ) async {
    await _pumpForm(
      tester,
      signedIn: true,
      suggestions: const ['darkwave', 'synthpop', 'soul'],
    );
    await _settle(tester);
    expect(find.text('Suggested tags'), findsOneWidget);
    expect(find.text('+ darkwave'), findsOneWidget);

    await tester.tap(find.text('+ darkwave'));
    await _settle(tester);
    final field = find.widgetWithText(TextField, 'Tags');
    expect(tester.widget<TextField>(field).controller!.text, 'darkwave');
    expect(find.text('+ darkwave'), findsNothing, reason: 'already added');

    await tester.tap(find.text('+ soul'));
    await _settle(tester);
    expect(tester.widget<TextField>(field).controller!.text, 'darkwave, soul');

    // Typing a suggested tag by hand hides it too.
    await tester.enterText(field, 'darkwave, soul, Synthpop');
    await _settle(tester);
    expect(find.text('Suggested tags'), findsNothing);
  });

  testWidgets('shows an animated loading line while suggestions load', (
    tester,
  ) async {
    final pending = Completer<List<String>>();
    await _pumpForm(tester, signedIn: true, pendingSuggestions: pending);
    await tester.pump(const Duration(milliseconds: 100));
    // The visible dots: the span after the text.
    String dots() {
      final text = tester.widget<Text>(
        find.textContaining('Finding suggested tags'),
      );
      return ((text.textSpan! as TextSpan).children![1] as TextSpan).text!;
    }

    final seen = <String>{dots()};
    for (var i = 0; i < 3; i++) {
      await tester.pump(AppLoadingText.step);
      seen.add(dots());
    }
    expect(seen, {'.', '..', '...'});

    pending.complete(const ['darkwave']);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Finding suggested tags'), findsNothing);
    expect(find.text('+ darkwave'), findsOneWidget);
  });

  testWidgets('says so when no suggested tags are found', (tester) async {
    await _pumpForm(tester, signedIn: true);
    await _settle(tester);
    expect(
      find.text("Couldn't find any suggested tags for this song"),
      findsOneWidget,
    );
    expect(find.text('Suggested tags'), findsNothing);
  });
}
