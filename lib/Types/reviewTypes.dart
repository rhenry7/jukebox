import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String userName;
  final String email;
  final String userId;
  final String artist;
  final String title;
  final String review;
  final double score;
  final bool liked;
  final DateTime? date;
  final String? albumImageUrl;

  Review({
    required this.userName,
    required this.email,
    required this.userId,
    required this.artist,
    required this.title,
    required this.review,
    required this.score,
    required this.liked,
    this.date,
    this.albumImageUrl,
  });

  // Factory method to create a Review from Firestore document data
  factory Review.fromFirestore(Map<String, dynamic> data) {
    return Review(
      userName: data['userName'] ?? '',
      email: data['email'] ?? '',
      userId: data['userId'] ?? '',
      artist: data['artist'] ?? '',
      title: data['title'] ?? '',
      review: data['review'] ?? '',
      score: data['score'] ?? 0,
      liked: data['liked'] ?? false,
      date: (data['date'] as Timestamp?)
          ?.toDate(), // Convert Firestore timestamp to DateTime
      albumImageUrl: data['albumImageUrl'],
    );
  }
}
