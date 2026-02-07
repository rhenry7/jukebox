// Function that uses switch to return a Widget based on the string input
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test_project/MusicPreferences/MusicTaste.dart';
import 'package:flutter_test_project/ui/screens/Profile/ProfileSignIn.dart';
import 'package:flutter_test_project/ui/screens/Profile/auth/authService.dart';
import 'package:flutter_test_project/ui/screens/Profile/profilePage.dart';
import 'package:flutter_test_project/ui/screens/Profile/user_profile_summary.dart';
import 'package:flutter_test_project/ui/screens/feed/comments.dart';

Future<Map<String, dynamic>> getCurrentUser() async {
  final User? user = FirebaseAuth.instance.currentUser;

  if (user != null) {
    try {
      final documentSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (documentSnapshot.exists) {
        final Map<String, dynamic> userData = documentSnapshot.data()!;
        debugPrint('User data: $userData');
        return userData; // Return the user data
        // Access specific data: userData['fieldName']
      } else {
        debugPrint('User document does not exist.');
      }
    } catch (e) {
      debugPrint('Error getting user data: $e');
    }
  } else {
    debugPrint('No user is signed in.');
  }
  throw Exception('Failed to get user data.');
}

Widget profileRoute(String route) {
  final FirebaseAuth auth = FirebaseAuth.instance;
  debugPrint(route);
  debugPrint(auth.currentUser?.email ?? '');
  switch (route) {
    case 'Reviews':
      return const CommentWidget();
    case 'Notifications':
      return ElevatedButton(
        onPressed: () {},
        child: const Text('This is a Button'),
      );
    case 'Preferences':
      return MusicTasteProfileWidget(
        onPreferencesChanged: (EnhancedUserPreferences) {},
      );
    default:
      if (auth.currentUser != null) {
        debugPrint('user signed in');
        return const UserProfileSummary();
      } else {
        debugPrint('user NOT signed in');
        return const SignInScreen();
      }
  }
}

void signOut() async {
  try {
    FirebaseAuth.instance.signOut();
    debugPrint('user signed out');
  } catch (e) {
    debugPrint('Error signing out: $e');
  }
}

// Note: This function is used in MainNavigation, which is not yet a ConsumerWidget
// For now, we'll keep the direct Firebase call, but this should be migrated to use providers
// TODO: Migrate MainNavigation to ConsumerWidget and use currentUserProvider
Widget profileRouter() {
  final FirebaseAuth auth = FirebaseAuth.instance;
  debugPrint('Current user: ${auth.currentUser?.uid ?? 'null'}');
  debugPrint(auth.currentUser?.displayName ?? '');
  debugPrint(auth.currentUser?.email ?? '');
  if (auth.currentUser != null) {
    return const ProfilePage();
  } else {
    return const SignInScreen();
  }
}

/// Check if user has music preferences set up
Future<bool> hasUserPreferences(String userId) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('musicPreferences')
        .doc('profile')
        .get();
    
    if (!doc.exists) {
      return false;
    }
    
    final data = doc.data();
    if (data == null) {
      return false;
    }
    
    // Check if they have at least some preferences set
    final favoriteGenres = data['favoriteGenres'] as List?;
    final favoriteArtists = data['favoriteArtists'] as List?;
    
    return (favoriteGenres != null && favoriteGenres.isNotEmpty) ||
           (favoriteArtists != null && favoriteArtists.isNotEmpty);
  } catch (e) {
    debugPrint('Error checking user preferences: $e');
    return false;
  }
}

Future<void> signUp(String userName, String email, String password) async {
  final AuthService authService = AuthService();
  final User? user = await authService.signUp(userName, email, password);
  // add userId, userDisplay name

  if (user != null) {
    final String userId = user.uid;
    await FirebaseFirestore.instance.collection('users').doc(userId).set({
      'password': password,
      'email': email,
      'userId': userId,
      'displayName': userName,
      'joinDate': FieldValue.serverTimestamp(),
      // for some reason we dont add them here
      //'friends': [],
      //'reviews': []
    });
    debugPrint('Sign-up successful! User ID: ${user.uid}');
  } else {
    debugPrint('Sign-up failed.');
  }
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

  // Check if this is a new user — create Firestore doc if it doesn't exist
  final userDoc =
      FirebaseFirestore.instance.collection('users').doc(user.uid);
  final docSnapshot = await userDoc.get();

  if (!docSnapshot.exists) {
    // First-time Google sign-in: create the user document
    await userDoc.set({
      'email': user.email ?? '',
      'userId': user.uid,
      'displayName': user.displayName ?? user.email?.split('@').first ?? '',
      'joinDate': FieldValue.serverTimestamp(),
      'photoUrl': user.photoURL ?? '',
    });
    debugPrint('New Google user created: ${user.uid}');
  } else {
    debugPrint('Existing Google user signed in: ${user.uid}');
  }

  return user;
}
