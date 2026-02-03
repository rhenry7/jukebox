import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String displayName;
  final String userId;
  final String artist;
  final String review;
  final double score;
  final String? albumImageUrl;
  final String? userImageUrl;
  final DateTime? date;
  final int likes;
  final int replies;
  final int reposts;
  final String title;
  final List<String>? genres; // Optional genres for the track

  Review({
    required this.displayName,
    required this.userId,
    required this.artist,
    required this.review,
    required this.score,
    this.date,
    this.albumImageUrl,
    this.userImageUrl,
    required this.likes,
    required this.replies,
    required this.reposts,
    required this.title,
    this.genres,
  });

  // Factory method to create a Review from Firestore document data
  factory Review.fromFirestore(Map<String, dynamic> data) {
    return Review(
      displayName: data['displayName'] ?? '',
      title: data['title'] ?? '',
      userId: data['userId'] ?? '',
      artist: data['artist'] ?? '',
      review: data['review'] ?? '',
      score: (data['score'] as num?)?.toDouble() ?? 0.0,
      date: (data['date'] as Timestamp?)
          ?.toDate(), // Convert Firestore timestamp to DateTime
      albumImageUrl: data['albumImageUrl'],
      userImageUrl: data['userImageUrl'],
      likes: data['likes'] ?? 0,
      replies: data['replies'] ?? 0,
      reposts: data['reposts'] ?? 0,
      genres: data['genres'] != null 
          ? List<String>.from(data['genres'] as List)
          : null,
    );
  }

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      displayName: json['displayName'] ?? '',
      userId: json['userId'] ?? '',
      artist: json['artist'] ?? '',
      title: json['title'] ?? '',
      review: json['review'] ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      date: json['date'] != null ? DateTime.parse(json['date']) : null,
      albumImageUrl: json['albumImageUrl'],
      userImageUrl: json['userImageUrl'],
      likes: json['likes'] ?? 0,
      replies: json['replies'] ?? 0,
      reposts: json['reposts'] ?? 0,
      genres: json['genres'] != null 
          ? List<String>.from(json['genres'] as List)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'displayName': displayName,
      'userId': userId,
      'artist': artist,
      'title': title,
      'review': review,
      'score': score,
      'date': date?.toIso8601String(),
      'albumImageUrl': albumImageUrl,
      'userImageUrl': userImageUrl,
      'likes': likes,
      'replies': replies,
      'reposts': reposts,
      'genres': genres,
    };
  }
}
