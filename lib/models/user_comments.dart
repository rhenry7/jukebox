class UserComment {
  final String id;
  final String name;
  final String avatar;
  final String comment;
  final int likes;
  final int replies;
  final int reposts;
  final int shares;
  final DateTime time;

  UserComment({
    required this.id,
    required this.name,
    required this.avatar,
    required this.comment,
    required this.likes,
    required this.replies,
    required this.reposts,
    required this.shares,
    required this.time,
  });

  factory UserComment.fromJson(Map<String, dynamic> json) {
    return UserComment(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? '',
      comment: json['comment']?.toString() ?? '',
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      time: json['time'] != null
          ? DateTime.tryParse(json['time'].toString()) ?? DateTime.now()
          : DateTime.now(),
      replies: (json['replies'] as num?)?.toInt() ?? 0,
      reposts: (json['reposts'] as num?)?.toInt() ?? 0,
      shares: (json['shares'] as num?)?.toInt() ?? 0,
    );
  }

  // Method to convert UserComment to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatar': avatar,
      'comment': comment,
      'likes': likes,
      'replies': replies,
      'reposts': reposts,
      'shares': shares,
      'time': time.toIso8601String(), // Convert DateTime to ISO 8601 string
    };
  }
}
