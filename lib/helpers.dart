import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test_project/ProfileSignIn.dart';
import 'package:flutter_test_project/authService.dart';

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
    return SignInScreen();
  }
}

void signUp(String email, String password) async {
  AuthService authService = AuthService();
  User? user = await authService.signUp(email, password);

  if (user != null) {
    print("Sign-up successful! User ID: ${user.uid}");
  } else {
    print("Sign-up failed.");
  }
}
