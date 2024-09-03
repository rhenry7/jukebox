class UserComment {
  final String id;
  final String name;
  final String avatar;
  final String comment;

  UserComment({
    required this.id,
    required this.name,
    required this.avatar,
    required this.comment,
  });

  // Factory method to create a UserComment from JSON
  factory UserComment.fromJson(Map<String, dynamic> json) {
    return UserComment(
      id: json['id'],
      name: json['name'],
      avatar: json['avatar'],
      comment: json['comment'],
    );
  }

  // Method to convert UserComment to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatar': avatar,
      'createdAt': comment,
    };
  }
}
