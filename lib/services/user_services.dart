import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/models/user_models.dart';
import 'package:flutter_test_project/ui/screens/Home/_comments.dart';

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
          reviews: reviews,
          id: '',
          // use avatar imaage URL
        );
      } else {
        return UserReviewInfo(
          displayName: 'Undefined',
          joinDate: null,
          reviews: [],
          id: '',
        );
      }
    } catch (e) {
      print('Error fetching user info: $e');
      return UserReviewInfo(
        displayName: 'Undefined',
        joinDate: null,
        reviews: [],
        id: '',
      );
    }
  }

  Future<UserReviewInfo> fetchCurrentUserInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No user is currently signed in.');
        return UserReviewInfo(
          displayName: 'Undefined',
          joinDate: null,
          reviews: [],
          id: '',
        );
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('reviews')
          .orderBy('date', descending: true)
          .get();

      final List<ReviewWithDocId> reviewsWithDocIds = snapshot.docs.map((doc) {
        final review = Review.fromFirestore(doc.data());
        final docId = doc.id;
        return ReviewWithDocId(review: review, docId: docId);
      }).toList();

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      return UserReviewInfo(
        displayName: userDoc.data()?['displayName'] ?? '',
        joinDate: userDoc.data()?['joinDate']?.toDate(),
        reviews: reviewsWithDocIds.map((r) => r.review).toList(),
        id: user.uid,
        // use avatar image URL if available
      );
    } catch (e) {
      print('Error fetching current user info: $e');
      return UserReviewInfo(
        displayName: 'Undefined',
        joinDate: null,
        reviews: [],
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

  double getAverageRating(List<Review> reviews) {
    if (reviews.isEmpty) return 0.0;
    double total = 0.0;
    for (var review in reviews) {
      total += review.score;
    }
    return total / reviews.length;
  }
}
