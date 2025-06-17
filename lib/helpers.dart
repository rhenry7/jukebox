import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';


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
class Review {
  final String? userName;
  final String? email;
  final String userId;
  final String artist;
  final String title;
  final String review;
  final double score;
  final bool liked;
  final dynamic date; // Can be Timestamp or DateTime
  final String albumImageUrl;

  Review({
    required this.userName,
    required this.email,
    required this.userId,
    required this.artist,
    required this.title,
    required this.review,
    required this.score,
    required this.liked,
    required this.date,
    required this.albumImageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'userName': userName,
      'email': email,
      'userId': userId,
      'artist': artist,
      'title': title,
      'review': review,
      'score': score,
      'liked': liked,
      'date': date,
      'albumImageUrl': albumImageUrl,
    };
  }

  factory Review.fromMap(Map<String, dynamic> map) {
    return Review(
      userName: map['userName'],
      email: map['email'],
      userId: map['userId'],
      artist: map['artist'],
      title: map['title'],
      review: map['review'],
      score: (map['score'] as num).toDouble(),
      liked: map['liked'],
      date: map['date'],
      albumImageUrl: map['albumImageUrl'],
    );
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



void addUserReview() async {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final database = FirebaseFirestore.instance.collection('users');
  DatabaseReference ref = FirebaseDatabase.instance.ref();
  if (auth.currentUser != null) {
    final db = Firebase.app('jukeboxd');
  }
}


