import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/models/user_models.dart';

class UserServices {
  // The difference between the two is that one returns a single instance, based on userId, and the
  // the other returns a list of users
  Future<UserReviewInfo> fetchUserInfo(String userId) async {
    try {
      final List<Review> reviews = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reviews')
          .orderBy('date', descending: true)
          .get()
          .then((snapshot) => snapshot.docs
              .map((doc) => Review.fromFirestore(doc.data()))
              .toList());

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (reviews.isNotEmpty) {
        return UserReviewInfo(
          displayName: userDoc.data()?['displayName'] ?? '',
          joinDate: userDoc.data()?['joinDate'] ?? '',
          reviewsCount: reviews.length, id: '',
          // use avatar imaage URL
        );
      } else {
        return UserReviewInfo(
          displayName: 'Undefined',
          joinDate: 'Undefined',
          reviewsCount: 0,
          id: '',
        );
      }
    } catch (e) {
      print('Error fetching user info: $e');
      return UserReviewInfo(
        displayName: 'Undefined',
        joinDate: 'Undefined',
        reviewsCount: 0,
        id: '',
      );
    }
  }

  Future<List<Review>> fetchUserReviews(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reviews')
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Review.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching user reviews: $e');
      return [];
    }
  }

  Future<List<UserReviewInfo>> fetchUsers() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('users').get();

      return snapshot.docs
          .map((doc) => UserReviewInfo.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching users: $e');
      return [];
    }
  }
}
