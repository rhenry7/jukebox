import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Sign up function
  Future<User?> signUp(
      String displayName, String email, String password) async {
    try {
      // Attempt to create a new user
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Get the current user
      User? user = userCredential.user;

      // Check if user is not null and update the displayName
      if (user != null) {
        await user.updateDisplayName(displayName);
        await user.reload();
        user = _auth.currentUser; // Refresh the user instance after update
      }

      return user;
    } on FirebaseAuthException catch (e) {
      // Handle different error codes from Firebase
      if (e.code == 'email-already-in-use') {
        debugPrint('This email address is already in use.');
      } else if (e.code == 'weak-password') {
        debugPrint('The password is too weak.');
      } else if (e.code == 'invalid-email') {
        debugPrint('The email address is not valid.');
      } else {
        debugPrint('Sign-up failed: ${e.message}');
      }
      return null;
    } catch (e) {
      debugPrint('An unexpected error occurred: $e');
      return null;
    }
  }

  /// Sign in with email and password
  /// Returns true if successful, false if failed
  /// Throws exception with error message if failed
  Future<bool> signIn(String email, String password) async {
    try {
      debugPrint(email);
      // Attempt to sign in with Firebase
      await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      debugPrint('successfully signed in!');
      return true; // Sign-in successful
    } on FirebaseAuthException catch (e) {
      // Handle errors
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password.';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many requests. Please try again later.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'This operation is not allowed.';
          break;
        default:
          errorMessage = 'An error occurred. Please try again.';
      }
      debugPrint(errorMessage); // Print to console for debugging
      throw Exception(errorMessage); // Throw exception with error message
    } catch (e) {
      debugPrint('Sign-in error: $e');
      rethrow; // Re-throw to be handled by caller
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
    debugPrint('Google sign-in (web) successful: ${userCredential.user?.email}');
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
          ? '${appleCredential.givenName} ${appleCredential.familyName ?? ''}'.trim()
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
    return List.generate(
        length, (_) => charset[random.nextInt(charset.length)]).join();
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
