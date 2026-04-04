// Function that uses switch to return a Widget based on the string input
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test_project/MusicPreferences/MusicTaste.dart';
import 'package:flutter_test_project/ui/screens/Profile/ProfileSignIn.dart';
import 'package:flutter_test_project/ui/screens/Profile/auth/authService.dart';
import 'package:flutter_test_project/ui/screens/Profile/delete_account_screen.dart';
import 'package:flutter_test_project/ui/screens/Profile/legal_screen.dart';
import 'package:flutter_test_project/ui/screens/Profile/notifications_page.dart';
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
      return const NotificationsPage();
    case 'Preferences':
      if (auth.currentUser == null) {
        return const SignInScreen();
      }
      return MusicTasteProfileWidget(
        onPreferencesChanged: (EnhancedUserPreferences) {},
      );
    case 'Legal':
      return const LegalScreen();
    case 'Delete Account':
      return const DeleteAccountScreen();
    default:
      final user = auth.currentUser;
      if (user != null) {
        debugPrint('user signed in');
        return const UserProfileSummary();
      } else {
        debugPrint('no user — showing sign-in');
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

/// Returns true only if there is a signed-in user.
bool isRealUserSignedIn() {
  return FirebaseAuth.instance.currentUser != null;
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

/// Sign in (or sign up) with Apple.
/// If the user is new, a Firestore user document is created automatically.
/// Returns the [User] on success, or null if cancelled.
Future<User?> signInWithApple() async {
  final AuthService authService = AuthService();
  final userCredential = await authService.signInWithApple();

  if (userCredential == null) return null;

  final User? user = userCredential.user;
  if (user == null) return null;

  final userDoc =
      FirebaseFirestore.instance.collection('users').doc(user.uid);
  final docSnapshot = await userDoc.get();

  if (!docSnapshot.exists) {
    await userDoc.set({
      'email': user.email ?? '',
      'userId': user.uid,
      'displayName': user.displayName ?? user.email?.split('@').first ?? '',
      'joinDate': FieldValue.serverTimestamp(),
      'photoUrl': user.photoURL ?? '',
    });
  }

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
