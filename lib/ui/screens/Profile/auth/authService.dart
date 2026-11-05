import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Creates an email/password account and sets its display name.
  /// Throws an [Exception] whose message is safe to show the user.
  Future<User> signUp(String displayName, String email, String password) async {
    final UserCredential credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
    } on FirebaseAuthException catch (e) {
      debugPrint('Sign-up failed: ${e.code} – ${e.message}');
      throw Exception(authErrorMessage(e.code));
    }
    final user = credential.user!;
    // The account exists now; a failed name update mustn't fail sign-up.
    try {
      await user.updateDisplayName(displayName);
      await user.reload();
    } catch (e) {
      debugPrint('Could not set display name: $e');
    }
    return _auth.currentUser ?? user;
  }

  /// Signs in with email and password.
  /// Throws an [Exception] whose message is safe to show the user.
  Future<User> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      return credential.user!;
    } on FirebaseAuthException catch (e) {
      debugPrint('Sign-in failed: ${e.code} – ${e.message}');
      throw Exception(authErrorMessage(e.code));
    }
  }

  /// Sign in with Google.
  /// Works on web (via signInWithPopup) and mobile (via google_sign_in package).
  /// Returns the [UserCredential] on success, or null if the user cancelled.
  /// Throws an exception with a user-friendly message on failure.
  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        return await _signInWithGoogleWeb();
      } else {
        return await _signInWithGoogleMobile();
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Google sign-in Firebase error: ${e.code} – ${e.message}');
      if (e.code == 'account-exists-with-different-credential') {
        throw Exception(
            'An account already exists with this email using a different sign-in method.');
      }
      throw Exception('Google sign-in failed. Please try again.');
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      rethrow;
    }
  }

  /// Web: Use Firebase Auth popup flow (no google_sign_in package needed).
  Future<UserCredential?> _signInWithGoogleWeb() async {
    final GoogleAuthProvider googleProvider = GoogleAuthProvider();
    googleProvider.addScope('email');
    googleProvider.addScope('profile');

    final UserCredential userCredential =
        await _auth.signInWithPopup(googleProvider);
    debugPrint(
        'Google sign-in (web) successful: ${userCredential.user?.email}');
    return userCredential;
  }

  /// Sign in with Apple (iOS only).
  /// Returns the [UserCredential] on success, or null if the user cancelled.
  /// Throws an exception with a user-friendly message on failure.
  Future<UserCredential?> signInWithApple() async {
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);

      // Apple only sends the name on the very first sign-in.
      // If we got a name, update the Firebase display name.
      final fullName = appleCredential.givenName != null
          ? '${appleCredential.givenName} ${appleCredential.familyName ?? ''}'
              .trim()
          : null;
      if (fullName != null &&
          fullName.isNotEmpty &&
          userCredential.user?.displayName == null) {
        await userCredential.user?.updateDisplayName(fullName);
      }

      return userCredential;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        // User cancelled — not an error
        return null;
      }
      debugPrint('Apple sign-in error: ${e.code} – ${e.message}');
      throw Exception('Apple sign-in failed. Please try again.');
    } on FirebaseAuthException catch (e) {
      debugPrint('Apple sign-in Firebase error: ${e.code} – ${e.message}');
      if (e.code == 'account-exists-with-different-credential') {
        throw Exception(
            'An account already exists with this email using a different sign-in method.');
      }
      throw Exception('Apple sign-in failed. Please try again.');
    } catch (e) {
      debugPrint('Apple sign-in unexpected error: $e');
      rethrow;
    }
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Mobile (Android / iOS): Use the google_sign_in package to get credentials,
  /// then pass them to Firebase Auth.
  Future<UserCredential?> _signInWithGoogleMobile() async {
    // Trigger the Google Sign-In flow
    final GoogleSignIn googleSignIn = GoogleSignIn();
    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

    if (googleUser == null) {
      // User cancelled the sign-in flow
      debugPrint('Google sign-in cancelled by user.');
      return null;
    }

    // Obtain the auth details from the Google Sign-In
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    // Create a Firebase credential from the Google tokens
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // Sign in to Firebase with the Google credential
    final UserCredential userCredential =
        await _auth.signInWithCredential(credential);
    debugPrint(
        'Google sign-in (mobile) successful: ${userCredential.user?.email}');
    return userCredential;
  }
}

/// A message for a Firebase Auth error code that's safe to show the user.
@visibleForTesting
String authErrorMessage(String code) => switch (code) {
      // Current Firebase reports a wrong password or unknown email as one
      // code, so it can't say which.
      'invalid-credential' ||
      'INVALID_LOGIN_CREDENTIALS' ||
      'wrong-password' ||
      'user-not-found' =>
        'Wrong email or password.',
      'email-already-in-use' =>
        'An account with this email already exists. Try signing in.',
      'weak-password' => 'Choose a stronger password (at least 6 characters).',
      'invalid-email' => "That email address doesn't look right.",
      'user-disabled' => 'This account has been disabled.',
      'too-many-requests' => 'Too many attempts. Please wait and try again.',
      'network-request-failed' =>
        'No connection. Check your internet and try again.',
      'operation-not-allowed' => 'This sign-in method is not available.',
      _ => 'Something went wrong. Please try again.',
    };
