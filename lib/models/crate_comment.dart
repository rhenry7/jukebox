import 'package:cloud_firestore/cloud_firestore.dart';

class CrateComment {
  final String id;
  final String playlistId;
  final String userId;
  final String displayName;
  final String text;
  final DateTime createdAt;
  final int likes;

  const CrateComment({
    required this.id,
    required this.playlistId,
    required this.userId,
    required this.displayName,
    required this.text,
    required this.createdAt,
    required this.likes,
  });

  factory CrateComment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CrateComment(
      id: doc.id,
      playlistId: data['playlistId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      displayName: data['displayName'] as String? ?? 'Anonymous',
      text: data['text'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likes: (data['likes'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'playlistId': playlistId,
        'userId': userId,
        'displayName': displayName,
        'text': text,
        'createdAt': Timestamp.fromDate(createdAt),
        'likes': likes,
      };
}
