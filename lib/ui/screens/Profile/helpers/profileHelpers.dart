// Function that uses switch to return a Widget based on the string input
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test_project/MusicPreferences/MusicTaste.dart';
import 'package:flutter_test_project/ui/screens/Profile/ProfileSignIn.dart';
import 'package:flutter_test_project/ui/screens/Profile/auth/authService.dart';
import 'package:flutter_test_project/ui/screens/Profile/profilePage.dart';
import 'package:flutter_test_project/ui/screens/feed/comments.dart';

Future<Map<String, dynamic>> getCurrentUser() async {
  User? user = FirebaseAuth.instance.currentUser;

  if (user != null) {
    try {
      var documentSnapshot = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      if (documentSnapshot.exists) {
        Map<String, dynamic> userData = documentSnapshot.data()!;
        print("User data: $userData");
        return userData; // Return the user data
        // Access specific data: userData['fieldName']
      } else {
        print("User document does not exist.");
      }
    } catch (e) {
      print("Error getting user data: $e");
    }
  } else {
    print("No user is signed in.");
  }
  throw Exception("Failed to get user data.");
}

Widget profileRoute(String route) {
  final FirebaseAuth auth = FirebaseAuth.instance;
  print(route);
  print(auth.currentUser?.email ?? '');
  switch (route) {
    case 'Reviews':
      return const CommentWidget();
    case 'Notifications':
      return ElevatedButton(
        onPressed: () {},
        child: const Text("This is a Button"),
      );
    case 'Preferences':
      return MusicTasteProfileWidget(
        onPreferencesChanged: (EnhancedUserPreferences) {},
      );
    default:
      if (auth.currentUser != null) {
        print("user signed in");
        return const Scaffold(body: Center(child: Text("coming soon")));
      } else {
        print("user NOT signed in");
        return const SignInScreen();
      }
  }
}

void signOut() async {
  try {
    FirebaseAuth.instance.signOut();
    print("user signed out");
  } catch (e) {
    print("Error signing out: $e");
  }
}

Widget profileRouter() {
  final FirebaseAuth auth = FirebaseAuth.instance;
  print(auth.currentUser);
  print(auth.currentUser?.displayName ?? "");
  print(auth.currentUser?.email ?? '');
  if (auth.currentUser != null) {
    return const ProfilePage();
  } else {
    return const SignInScreen();
  }
}

Future<void> signUp(String userName, String email, String password) async {
  AuthService authService = AuthService();
  User? user = await authService.signUp(userName, email, password);
  // add userId, userDisplay name

  if (user != null) {
    String userId = user.uid;
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
    print("Sign-up successful! User ID: ${user.uid}");
  } else {
    print("Sign-up failed.");
  }
}
