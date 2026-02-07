import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationEvent {
  final String id;
  final String type;
  final String actorId;
  final String actorDisplayName;
  final String? actorPhotoUrl;
  final String? reviewId;
  final String? reviewTitle;
  final String? reviewArtist;
  final DateTime? createdAt;
  final bool read;

  NotificationEvent({
    required this.id,
    required this.type,
    required this.actorId,
    required this.actorDisplayName,
    this.actorPhotoUrl,
    this.reviewId,
    this.reviewTitle,
    this.reviewArtist,
    this.createdAt,
    this.read = false,
  });

  factory NotificationEvent.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return NotificationEvent(
      id: doc.id,
      type: data['type'] ?? '',
      actorId: data['actorId'] ?? '',
      actorDisplayName: data['actorDisplayName'] ?? '',
      actorPhotoUrl: data['actorPhotoUrl'],
      reviewId: data['reviewId'],
      reviewTitle: data['reviewTitle'],
      reviewArtist: data['reviewArtist'],
      createdAt: _parseDate(data['createdAt']),
      read: data['read'] == true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'actorId': actorId,
      'actorDisplayName': actorDisplayName,
      'actorPhotoUrl': actorPhotoUrl,
      'reviewId': reviewId,
      'reviewTitle': reviewTitle,
      'reviewArtist': reviewArtist,
      'createdAt': createdAt,
      'read': read,
    };
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

class NotificationType {
  static const String reviewLike = 'review_like';
  static const String friendAdded = 'friend_added';
}
