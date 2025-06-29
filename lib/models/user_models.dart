class UserReviewInfo {
  final String displayName;
  final DateTime? joinDate;
  final String id;
  final int reviewsCount;

  UserReviewInfo({
    required this.id,
    required this.displayName,
    required this.joinDate,
    required this.reviewsCount,
  });

  factory UserReviewInfo.fromMap(Map<String, dynamic> map) {
    return UserReviewInfo(
      id: map['id'] ?? '',
      displayName: map['displayName'] ?? '',
      joinDate: map['joinDate'] ?? '',
      reviewsCount: map['reviewsCount'] ?? 0,
    );
  }

  factory UserReviewInfo.fromJson(Map<String, dynamic> json) {
    return UserReviewInfo(
      id: json['id'] ?? '',
      displayName: json['displayName'] ?? '',
      joinDate: json['joinDate'] ?? '',
      reviewsCount: json['reviewsCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'joinDate': joinDate,
      'reviewsCount': reviewsCount,
    };
  }
}
