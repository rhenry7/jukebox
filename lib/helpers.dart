import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
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
  print(auth.currentUser?.email ?? '');
  if (auth.currentUser != null) {
    return ProfilePage();
  } else {
    return SignInScreen();
  }
}

void signUp(String email, String password) async {
  AuthService authService = AuthService();
  User? user = await authService.signUp(email, password);

  if (user != null) {
    String userId = user.uid;
    await FirebaseFirestore.instance.collection('users').doc(userId).set({
      'password': password,
      'email': email,
      'joinDate': FieldValue.serverTimestamp(),
      // Add any other fields you'd like to track
    });
    print("Sign-up successful! User ID: ${user.uid}");
  } else {
    print("Sign-up failed.");
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
