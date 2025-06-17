class Review {
  final String? userName;
  final String? email;
  final String userId;
  final String artist;
  final String title;
  final String review;
  final double score;
  final bool liked;
  final dynamic date; // Can be Timestamp or DateTime
  final String albumImageUrl;

  Review({
    required this.userName,
    required this.email,
    required this.userId,
    required this.artist,
    required this.title,
    required this.review,
    required this.score,
    required this.liked,
    required this.date,
    required this.albumImageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'userName': userName,
      'email': email,
      'userId': userId,
      'artist': artist,
      'title': title,
      'review': review,
      'score': score,
      'liked': liked,
      'date': date,
      'albumImageUrl': albumImageUrl,
    };
  }

  factory Review.fromMap(Map<String, dynamic> map) {
    return Review(
      userName: map['userName'],
      email: map['email'],
      userId: map['userId'],
      artist: map['artist'],
      title: map['title'],
      review: map['review'],
      score: (map['score'] as num).toDouble(),
      liked: map['liked'],
      date: map['date'],
      albumImageUrl: map['albumImageUrl'],
    );
  }
}
