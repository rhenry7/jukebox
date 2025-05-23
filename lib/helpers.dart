import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test_project/ProfileSignIn.dart';
import 'package:flutter_test_project/ProfileSignUpWidget.dart';
import 'package:flutter_test_project/authService.dart';
import 'package:flutter_test_project/profilePage.dart';

import 'comments.dart';

class DateHelper {
  String formatDateTimeDifference(String isoDateTime) {
    DateTime dateTime = DateTime.parse(isoDateTime);
    Duration difference = DateTime.now().difference(dateTime);

    if (difference.inDays >= 1) {
      return '${difference.inDays}d';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes}m';
    } else {
      return '${difference.inSeconds}s';
    }
  }
}

String formatDateTimeDifference(String isoDateTime) {
  DateTime dateTime = DateTime.parse(isoDateTime);
  Duration difference = DateTime.now().difference(dateTime);

  if (difference.inDays >= 1) {
    return '${difference.inDays}d';
  } else if (difference.inHours >= 1) {
    return '${difference.inHours}h';
  } else if (difference.inMinutes >= 1) {
    return '${difference.inMinutes}m';
  } else {
    return '${difference.inSeconds}s';
  }
}

String getCurrentDate() {
  final date = DateTime.now().toString();
  final dateParse = DateTime.parse(date);
  return "${dateParse.day}-${dateParse.month}-${dateParse.year}";
}

Widget routeToPage(String name) {
  if (name == "Reviews") {
    return const CommentWidget();
  } else {
    return ProfileSignUp();
  }
}

Widget profileRouter() {
  final FirebaseAuth auth = FirebaseAuth.instance;
  print(auth.currentUser);
  print(auth.currentUser?.displayName ?? "");
  print(auth.currentUser?.email ?? '');
  if (auth.currentUser != null) {
    return ProfilePage();
  } else {
    return SignInScreen();
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
      'friends': []
      // Add any other fields you'd like to track
    });
    print("Sign-up successful! User ID: ${user.uid}");
  } else {
    print("Sign-up failed.");
  }
}

Future<List<Map<String, dynamic>>> fetchUserReviews(String userId) async {
  QuerySnapshot snapshot = await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('reviews')
      .orderBy('date', descending: true) // Optional: orders by timestamp
      .get();

  return snapshot.docs
      .map((doc) => doc.data() as Map<String, dynamic>)
      .toList();
}

Future<void> submitReview(String review, double score, String artist,
    String title, bool liked, String albumImageUrl) async {
  // album display image url
  print(artist);
  User? user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    print(review.toString());
    String userId = user.uid;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reviews')
          .add({
        'userName': user.displayName,
        'email': user.email,
        'userId': userId,
        'artist': artist,
        'title': title,
        'review': review,
        'score': score,
        'liked': liked,
        'date': FieldValue.serverTimestamp(), // Adds server timestamp
        'albumImageUrl': albumImageUrl,
      });
    } catch (e) {
      print("could not post review");
      print(e.toString());
    }
  } else {
    print('could not place review, user not signed in');
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

void addUserReview() async {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final database = FirebaseFirestore.instance.collection('users');
  DatabaseReference ref = FirebaseDatabase.instance.ref();
  if (auth.currentUser != null) {
    final db = Firebase.app('jukeboxd');
  }
}

// Function that uses switch to return a Widget based on the string input
Widget profileRoute(String route) {
  final FirebaseAuth auth = FirebaseAuth.instance;
  print(route);
  print(auth.currentUser?.email ?? '');
  switch (route) {
    case 'Reviews':
      return Scaffold(
          appBar: PreferredSize(
              preferredSize: Size.fromHeight(675),
              child: Column(
                children: [
                  Expanded(child: CommentWidget()),
                ],
              )));
    case 'Notifications':
      return ElevatedButton(
        onPressed: () {},
        child: Text("This is a Button"),
      );
    default:
      if (auth.currentUser != null) {
        print("user signed in");
        return const Scaffold(body: Center(child: Text("coming soon")));
      } else {
        print("user NOT signed in");
        return SignInScreen();
      }
  }
}
