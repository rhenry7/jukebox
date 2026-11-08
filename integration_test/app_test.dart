import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/main.dart' as app;
import 'package:flutter_test_project/ui/widgets/review_card.dart';
import 'package:flutter_test_project/utils/cached_image.dart';
import 'package:integration_test/integration_test.dart';

/// End-to-end checks of the main signed-out flows, against the real app and
/// live (read-only) data. Run with scripts/run_integration_tests.sh.
///
/// Checks structure, not content: the reviews change all the time. Nothing
/// here signs in or writes data.

/// Pumps until [finder] shows up. (pumpAndSettle never settles here: images
/// and loading indicators keep animating.)
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

/// Closes the page showing [onPage]. (The app draws its own back buttons, so
/// `tester.pageBack()` can't find one.)
Future<void> goBack(WidgetTester tester, Finder onPage) async {
  Navigator.of(tester.element(onPage.first)).pop();
  await settle(tester);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

/// Album art on review cards has loaded: none of the thumbnails on screen is
/// still loading (spinner) or failed (music note). Album art that went
/// missing is the bug this guards against (see docs/image-rendering.md).
///
/// It can't see art drawn as a black square: re-drawing the page off screen
/// draws the art fine even when the browser shows black, and real browser
/// screenshots failed under flutter drive here. test/images/image_loading_guard_test
/// blocks the cause of that instead.
Future<void> expectAlbumArtLoaded(WidgetTester tester) async {
  final thumbs = find.descendant(
    of: find.byType(ReviewCardWithGenres),
    matching: find.byType(AppCachedImage),
  );
  expect(thumbs, findsWidgets, reason: 'No album art on screen');
  bool stillLoadingOrFailed() =>
      find
          .descendant(
            of: thumbs,
            matching: find.byType(CircularProgressIndicator),
          )
          .evaluate()
          .isNotEmpty ||
      find
          .descendant(of: thumbs, matching: find.byIcon(Icons.music_note))
          .evaluate()
          .isNotEmpty;
  final end = DateTime.now().add(const Duration(seconds: 20));
  while (stillLoadingOrFailed()) {
    if (DateTime.now().isAfter(end)) {
      throw TestFailure('Album art still loading or failed after 20s');
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // One journey: main() starts Firebase, which can only happen once per run.
  testWidgets('signed-out journey: feeds, a review, search, a tag, sign-in', (
    tester,
  ) async {
    await app.main();

    // ── Home: Popular loads review cards ──────────────────────────────────
    final cards = find.byType(ReviewCardWithGenres);
    await pumpUntilFound(tester, cards);
    expect(find.text('Popular'), findsOneWidget);
    await expectAlbumArtLoaded(tester);

    // ── Friends and For You ask signed-out users to sign in ──────────────
    await tester.tap(find.text('Friends'));
    await pumpUntilFound(tester, find.text('Sign In Required'));
    await tester.tap(find.text('For You'));
    await pumpUntilFound(tester, find.text('Sign In Required'));
    await tester.tap(find.text('Popular'));
    await pumpUntilFound(tester, cards);
    await settle(tester); // let the tab switch finish before tapping a card

    // ── A review's page: the review, and comments asking to sign in ──────
    final title = tester.widget<ReviewCardWithGenres>(cards.first).review.title;
    await tester.tap(find.text(title).first);
    await pumpUntilFound(tester, find.text('Play on Spotify'));
    await tester.scrollUntilVisible(
      find.text('Sign in to read the comments.'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Sign in to read the comments.'), findsOneWidget);
    await goBack(tester, find.text('Play on Spotify'));
    await pumpUntilFound(tester, cards);
    await settle(tester);
    // Art that loaded before must still be there after coming back.
    await expectAlbumArtLoaded(tester);

    // ── Search finds reviews; a tag pill opens that tag's page ────────────
    await tester.tap(find.byIcon(Icons.search));
    await pumpUntilFound(tester, find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'rock');
    await pumpUntilFound(tester, find.textContaining('results'));
    // A "rock" tag pill on a result (not the search box's own text).
    final rockPill = find.widgetWithText(ActionChip, 'rock');
    await pumpUntilFound(tester, rockPill);
    await tester.tap(rockPill.first);
    final tagHeader = find.textContaining('reviews');
    await pumpUntilFound(tester, tagHeader);
    await goBack(tester, tagHeader);
    await goBack(tester, find.byType(TextField));
    await pumpUntilFound(tester, cards);

    // ── Profile, signed out: the sign-in screen, then Create Account ─────
    await tester.tap(find.byTooltip('Profile'));
    await pumpUntilFound(tester, find.text('Sign Up'));
    await tester.tap(find.text('Sign Up'));
    await pumpUntilFound(tester, find.text('Create Account'));
  });
}
