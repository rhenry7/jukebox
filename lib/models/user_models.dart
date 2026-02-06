import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test_project/models/review.dart';

class UserReviewInfo {
  final String displayName;
  final DateTime? joinDate;
  final String id;
  final List<Review>? reviews;

  UserReviewInfo({
    required this.id,
    required this.displayName,
    this.joinDate,
    this.reviews,
  });

  factory UserReviewInfo.fromMap(Map<String, dynamic> map) {
    return UserReviewInfo(
      id: map['id'] ?? '',
      displayName: map['displayName'] ?? '',
      joinDate: _parseDate(map['joinDate']),
      reviews: (map['reviews'] as List<dynamic>?)
              ?.map((e) => Review.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  factory UserReviewInfo.fromJson(Map<String, dynamic> json) {
    return UserReviewInfo(
      id: json['id'] ?? '',
      displayName: json['displayName'] ?? '',
      joinDate: _parseDate(json['joinDate']),
      reviews: (json['reviews'] as List<dynamic>?)
              ?.map((e) => Review.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }

  /// Safely parse a date from Firestore Timestamp, DateTime, or String.
  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'joinDate': joinDate?.toIso8601String(),
      'reviews': reviews?.map((r) => r.toJson()).toList(),
    };
  }
}
