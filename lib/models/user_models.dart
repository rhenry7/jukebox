import 'package:flutter_test_project/models/review.dart';

class UserReviewInfo {
  final String displayName;
  final DateTime? joinDate;
  final String id;
  final List<Review>? reviews;

  UserReviewInfo({
    required this.id,
    required this.displayName,
    required this.joinDate,
    required this.reviews,
  });

  factory UserReviewInfo.fromMap(Map<String, dynamic> map) {
    return UserReviewInfo(
      id: map['id'] ?? '',
      displayName: map['displayName'] ?? '',
      joinDate: map['joinDate'] ?? '',
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
      joinDate: json['joinDate'] ?? '',
      reviews: json['reviews'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'joinDate': joinDate,
      'reviews': reviews,
    };
  }

  }
