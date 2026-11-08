// Function that uses switch to return a Widget based on the string input
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_test_project/ui/screens/Profile/ProfileSignIn.dart';
import 'package:flutter_test_project/ui/screens/Profile/ProfileSignUpWidget.dart';
import 'package:flutter_test_project/ui/screens/Profile/auth/authService.dart';
import 'package:flutter_test_project/ui/screens/Profile/delete_account_screen.dart';
import 'package:flutter_test_project/ui/screens/Profile/legal_screen.dart';
import 'package:flutter_test_project/ui/screens/Profile/notifications_page.dart';
import 'package:flutter_test_project/ui/screens/Profile/profilePage.dart';
import 'package:flutter_test_project/services/demo_auto_sign_in.dart';
import 'package:flutter_test_project/ui/screens/onboarding/onboarding_flow.dart';

/// The side-menu pages (see the `ProfileButton`s in `MainNavigation`).
Widget profileRoute(String route) => switch (route) {
      'Notifications' => const NotificationsPage(),
      'Legal' => const LegalScreen(),
      'Delete Account' => const DeleteAccountScreen(),
      _ => throw ArgumentError.value(route, 'route', 'No such menu page'),
    };

/// Signs out of Firebase (and Google on mobile, so the next Google sign-in
/// asks which account), and stops the demo account signing back in.
Future<void> signOut() async {
  await DemoAutoSignIn.optOut();
  if (!kIsWeb) {
    try {
      await GoogleSignIn().signOut();
    } catch (e) {
      debugPrint('Google sign-out skipped: $e');
    }
  }
  await FirebaseAuth.instance.signOut();
  debugPrint('user signed out');
}

/// A reactive gate that shows [ProfilePage] for signed-in users and
/// [SignInScreen] for unauthenticated users. Rebuilds on auth state changes.
class ProfileGate extends StatelessWidget {
  const ProfileGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Fall back to the synchronous currentUser while the stream is warming
        // up. Without this, snapshot.data is null on first build which briefly
        // shows SignInScreen, whose _checkAuthState then pushes a new MainNav
        // and resets the tab to 0 (home).
        final user = snapshot.data ?? FirebaseAuth.instance.currentUser;
        return user != null ? const ProfilePage() : const SignInScreen();
      },
    );
  }
}

Widget profileRouter() {
  return const ProfileGate();
}

// ── Sign-in / sign-up routing ────────────────────────────────────────────────
//
// The signed-in user drives the UI: the Profile tab (ProfileGate) and the
// auth providers rebuild on auth changes by themselves. So after signing in
// these only need to close the sign-in screens and return the user to where
// they were — or show onboarding first if they haven't finished it.

/// Name given to the sign-in and sign-up routes, so they can all be closed
/// together after signing in.
const String authRouteName = '/auth';

/// Opens the sign-in screen on top of the current one.
Future<void> openSignIn(BuildContext context) => Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: authRouteName),
        builder: (_) => const SignInScreen(),
      ),
    );

/// Opens the sign-up screen on top of the current one.
Future<void> openSignUp(BuildContext context) => Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: authRouteName),
        builder: (_) => const ProfileSignUp(),
      ),
    );

/// Call once a user has signed in or signed up, from the sign-in or sign-up
/// screen. Shows onboarding if they haven't finished it; otherwise closes
/// the sign-in screens, back to where the user was.
Future<void> completeSignIn(BuildContext context, User user,
    {FirebaseFirestore? db}) async {
  // Captured now: in the Profile tab the sign-in screen is replaced as soon
  // as auth changes, so [context] may be gone after the await.
  final navigator = Navigator.of(context);
  if (!await hasCompletedOnboarding(user.uid, db: db)) {
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingFlow()),
      (_) => false,
    );
    return;
  }
  navigator.popUntil((route) => route.settings.name != authRouteName);
}

/// Whether the user finished (or skipped) onboarding. Accounts from before
/// the `onboardingComplete` flag count as done if they saved any genres or
/// artists. If the check fails, assume done rather than trap the user.
Future<bool> hasCompletedOnboarding(String userId,
    {FirebaseFirestore? db}) async {
  try {
    final data = (await (db ?? FirebaseFirestore.instance)
            .collection('users')
            .doc(userId)
            .collection('musicPreferences')
            .doc('profile')
            .get())
        .data();
    if (data == null) return false;
    if (data['onboardingComplete'] == true) return true;
    final genres = data['favoriteGenres'] as List?;
    final artists = data['favoriteArtists'] as List?;
    return (genres?.isNotEmpty ?? false) || (artists?.isNotEmpty ?? false);
  } catch (e) {
    debugPrint('Error checking onboarding: $e');
    return true;
  }
}

/// Creates an email/password account and its `users/{uid}` record.
/// Throws an [Exception] whose message is safe to show the user.
Future<User> signUp(String userName, String email, String password) async {
  final user = await AuthService().signUp(userName, email, password);
  await ensureUserDoc(user, displayName: userName);
  debugPrint('Sign-up successful! User ID: ${user.uid}');
  return user;
}

/// Creates the `users/{uid}` record (display name, email, join date) the
/// first time a user signs in, whichever way they signed up.
Future<void> ensureUserDoc(User user, {String? displayName}) async {
  final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
  if ((await userDoc.get()).exists) return;
  await userDoc.set({
    'email': user.email ?? '',
    'userId': user.uid,
    'displayName':
        displayName ?? user.displayName ?? user.email?.split('@').first ?? '',
    'joinDate': FieldValue.serverTimestamp(),
    'photoUrl': user.photoURL ?? '',
  });
}

/// Sign in (or sign up) with Apple.
/// If the user is new, a Firestore user document is created automatically.
/// Returns the [User] on success, or null if cancelled.
Future<User?> signInWithApple() async {
  final AuthService authService = AuthService();
  final userCredential = await authService.signInWithApple();

  if (userCredential == null) return null;

  final User? user = userCredential.user;
  if (user == null) return null;

  await ensureUserDoc(user);
  return user;
}

/// Sign in (or sign up) with Google.
/// If the user is new, a Firestore user document is created automatically.
/// Returns the [User] on success, or null if cancelled.
Future<User?> signInWithGoogle() async {
  final AuthService authService = AuthService();
  final userCredential = await authService.signInWithGoogle();

  if (userCredential == null) {
    // User cancelled the flow
    return null;
  }

  final User? user = userCredential.user;
  if (user == null) return null;

  await ensureUserDoc(user);
  return user;
}
