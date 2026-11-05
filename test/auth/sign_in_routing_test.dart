import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/ui/screens/Profile/auth/authService.dart';
import 'package:flutter_test_project/ui/screens/Profile/helpers/profileHelpers.dart';

void main() {
  group('authErrorMessage', () {
    test('a wrong password or unknown email says so', () {
      for (final code in [
        'invalid-credential',
        'INVALID_LOGIN_CREDENTIALS',
        'wrong-password',
        'user-not-found',
      ]) {
        expect(authErrorMessage(code), 'Wrong email or password.');
      }
    });

    test('sign-up problems are explained', () {
      expect(authErrorMessage('email-already-in-use'), contains('already'));
      expect(authErrorMessage('weak-password'), contains('stronger'));
      expect(
          authErrorMessage('network-request-failed'), contains('connection'));
    });

    test('unknown codes get a friendly fallback, never the raw code', () {
      expect(authErrorMessage('some-new-code'),
          'Something went wrong. Please try again.');
    });
  });

  group('hasCompletedOnboarding', () {
    Future<FakeFirebaseFirestore> withProfile(
        Map<String, dynamic>? data) async {
      final db = FakeFirebaseFirestore();
      if (data != null) {
        await db.doc('users/u1/musicPreferences/profile').set(data);
      }
      return db;
    }

    test('a new account has not', () async {
      expect(await hasCompletedOnboarding('u1', db: await withProfile(null)),
          isFalse);
    });

    test('skipping (the flag, no picks) counts as done', () async {
      final db = await withProfile({'onboardingComplete': true});
      expect(await hasCompletedOnboarding('u1', db: db), isTrue);
    });

    test('older accounts with saved genres count as done', () async {
      final db = await withProfile({
        'favoriteGenres': ['jazz']
      });
      expect(await hasCompletedOnboarding('u1', db: db), isTrue);
    });

    test('empty picks without the flag have not', () async {
      final db =
          await withProfile({'favoriteGenres': [], 'favoriteArtists': []});
      expect(await hasCompletedOnboarding('u1', db: db), isFalse);
    });
  });

  testWidgets('signing in returns to the screen the user was on',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await db
        .doc('users/u1/musicPreferences/profile')
        .set({'onboardingComplete': true});
    final user = MockUser(uid: 'u1');

    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('Popular feed')),
    ));

    // Feed → sign-in → sign-up, as from the sign-up prompt.
    for (final name in ['Sign in', 'Sign up']) {
      navigatorKey.currentState!.push(MaterialPageRoute(
        settings: const RouteSettings(name: authRouteName),
        builder: (_) => Scaffold(body: Text(name)),
      ));
    }
    await tester.pumpAndSettle();
    expect(find.text('Sign up'), findsOneWidget);

    await tester.runAsync(
        () => completeSignIn(navigatorKey.currentContext!, user, db: db));
    await tester.pumpAndSettle();

    expect(find.text('Popular feed'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
    expect(find.text('Sign up'), findsNothing);
  });
}
