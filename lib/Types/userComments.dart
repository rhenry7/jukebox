class UserComment {
  final String id;
  final String name;
  final String avatar;
  final String comment;
  final int likes;
  final int replies;
  final int reposts;
  final int shares;
  final DateTime time; // Added DateTime field

  UserComment(
      {required this.id,
      required this.name,
      required this.avatar,
      required this.comment,
      required this.likes,
      required this.replies,
      required this.reposts,
      required this.shares,
      required this.time});

  // Factory method to create a UserComment from JSON
  factory UserComment.fromJson(Map<String, dynamic> json) {
    return UserComment(
      id: json['id'],
      name: json['name'],
      avatar: json['avatar'],
      comment: json['comment'],
      likes: json['likes'],
      time: DateTime.parse(json['time']),
      replies: json['replies'],
      reposts: json['reposts'],
      shares: json['shares'],
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
