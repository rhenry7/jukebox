import 'package:cloud_firestore/cloud_firestore.dart';

/// Merges genres and tags (legacy) from Firestore, deduped by lowercase.
List<String>? _mergedGenresFromFirestore(Map<String, dynamic> data) {
  final g = data['genres'] as List?;
  final t = data['tags'] as List?;
  if (g == null && t == null) return null;
  final combined = [
    ...?g?.map((e) => e.toString().trim()).where((e) => e.isNotEmpty),
    ...?t?.map((e) => e.toString().trim()).where((e) => e.isNotEmpty),
  ];
  if (combined.isEmpty) return null;
  final seen = <String>{};
  final result = <String>[];
  for (final s in combined) {
    final lower = s.toLowerCase();
    if (!seen.contains(lower)) {
      seen.add(lower);
      result.add(s);
    }
  }
  return result.isEmpty ? null : result;
}

/// Merges genres and tags (legacy) from JSON, deduped by lowercase.
List<String>? _mergedGenresFromJson(Map<String, dynamic> json) {
  final g = json['genres'] as List?;
  final t = json['tags'] as List?;
  if (g == null && t == null) return null;
  final combined = [
    ...?g?.map((e) => e.toString().trim()).where((e) => e.isNotEmpty),
    ...?t?.map((e) => e.toString().trim()).where((e) => e.isNotEmpty),
  ];
  if (combined.isEmpty) return null;
  final seen = <String>{};
  final result = <String>[];
  for (final s in combined) {
    final lower = s.toLowerCase();
    if (!seen.contains(lower)) {
      seen.add(lower);
      result.add(s);
    }
  }
  return result.isEmpty ? null : result;
}

class Review {
  final String displayName;
  final String userId;
  final String artist;
  final String review;
  final double score;
  final String? albumImageUrl;
  final String? userImageUrl;
  final DateTime? date;
  final int likes;
  final int replies;
  final int reposts;
  final String title;
  final List<String>? genres; // Genres for the track (user-added + MusicBrainz, merged)

  Review({
    required this.displayName,
    required this.userId,
    required this.artist,
    required this.review,
    required this.score,
    this.date,
    this.albumImageUrl,
    this.userImageUrl,
    required this.likes,
    required this.replies,
    required this.reposts,
    required this.title,
    this.genres,
  });

  // Factory method to create a Review from Firestore document data
  factory Review.fromFirestore(Map<String, dynamic> data) {
    return Review(
      displayName: data['displayName'] ?? '',
      title: data['title'] ?? '',
      userId: data['userId'] ?? '',
      artist: data['artist'] ?? '',
      review: data['review'] ?? '',
      score: (data['score'] as num?)?.toDouble() ?? 0.0,
      date: (data['date'] as Timestamp?)
          ?.toDate(), // Convert Firestore timestamp to DateTime
      albumImageUrl: data['albumImageUrl'],
      userImageUrl: data['userImageUrl'],
      likes: data['likes'] ?? 0,
      replies: data['replies'] ?? 0,
      reposts: data['reposts'] ?? 0,
      genres: _mergedGenresFromFirestore(data),
    );
  }

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      displayName: json['displayName'] ?? '',
      userId: json['userId'] ?? '',
      artist: json['artist'] ?? '',
      title: json['title'] ?? '',
      review: json['review'] ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      date: json['date'] != null ? DateTime.parse(json['date']) : null,
      albumImageUrl: json['albumImageUrl'],
      userImageUrl: json['userImageUrl'],
      likes: json['likes'] ?? 0,
      replies: json['replies'] ?? 0,
      reposts: json['reposts'] ?? 0,
      genres: _mergedGenresFromJson(json),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'displayName': displayName,
      'userId': userId,
      'artist': artist,
      'title': title,
      'review': review,
      'score': score,
      'date': date?.toIso8601String(),
      'albumImageUrl': albumImageUrl,
      'userImageUrl': userImageUrl,
      'likes': likes,
      'replies': replies,
      'reposts': reposts,
      'genres': genres,
    };
  }
}
