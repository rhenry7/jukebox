import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test_project/models/review.dart';

Future<List<Review>> fetchUserReviews() async {
  final snapshot = await FirebaseFirestore.instance
      .collectionGroup('reviews')
      .orderBy('date', descending: true)
      .get();

  return snapshot.docs.map((doc) => Review.fromFirestore(doc.data())).toList();
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
        'displayName': user.displayName,
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

void addUserReview() async {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final database = FirebaseFirestore.instance.collection('users');
  DatabaseReference ref = FirebaseDatabase.instance.ref();
  if (auth.currentUser != null) {
    final db = Firebase.app('jukeboxd');
  }
}
