import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewComment {
  final String id;
  final String userId;
  final String displayName;
  final String text;
  final DateTime? createdAt;
  final int likes;

  const ReviewComment({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.text,
    this.createdAt,
    this.likes = 0,
  });

  factory ReviewComment.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ReviewComment(
      id: doc.id,
      userId: data['userId'] ?? '',
      displayName: data['displayName'] ?? '',
      text: data['text'] ?? '',
      createdAt: _parseDate(data['createdAt']),
      likes: (data['likes'] as num?)?.toInt() ?? 0,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
