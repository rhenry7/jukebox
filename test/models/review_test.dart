import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test_project/models/review.dart';

void main() {
  group('Review Model Tests', () {
    test('Review.fromFirestore creates Review with all fields', () {
      final data = {
        'displayName': 'Test User',
        'userId': 'user123',
        'artist': 'Test Artist',
        'title': 'Test Song',
        'review': 'Great song!',
        'score': 4.5,
        'date': Timestamp.now(),
        'albumImageUrl': 'https://example.com/image.jpg',
        'userImageUrl': 'https://example.com/user.jpg',
        'likes': 10,
        'replies': 2,
        'reposts': 1,
        'genres': ['Rock', 'Pop'],
      };

      final review = Review.fromFirestore(data);

      expect(review.displayName, 'Test User');
      expect(review.userId, 'user123');
      expect(review.artist, 'Test Artist');
      expect(review.title, 'Test Song');
      expect(review.review, 'Great song!');
      expect(review.score, 4.5);
      expect(review.likes, 10);
      expect(review.replies, 2);
      expect(review.reposts, 1);
      expect(review.genres, ['Rock', 'Pop']);
      expect(review.albumImageUrl, 'https://example.com/image.jpg');
    });

    test('Review.fromFirestore handles missing optional fields', () {
      final data = {
        'displayName': 'Test User',
        'userId': 'user123',
        'artist': 'Test Artist',
        'title': 'Test Song',
        'review': 'Great song!',
        'score': 4.5,
        'likes': 0,
        'replies': 0,
        'reposts': 0,
      };

      final review = Review.fromFirestore(data);

      expect(review.displayName, 'Test User');
      expect(review.date, isNull);
      expect(review.albumImageUrl, isNull);
      expect(review.userImageUrl, isNull);
      expect(review.genres, isNull);
    });

    test('Review.fromJson creates Review from JSON', () {
      final json = {
        'displayName': 'Test User',
        'userId': 'user123',
        'artist': 'Test Artist',
        'title': 'Test Song',
        'review': 'Great song!',
        'score': 4.5,
        'date': '2024-01-01T00:00:00.000Z',
        'albumImageUrl': 'https://example.com/image.jpg',
        'likes': 10,
        'replies': 2,
        'reposts': 1,
        'genres': ['Rock', 'Pop'],
      };

      final review = Review.fromJson(json);

      expect(review.displayName, 'Test User');
      expect(review.score, 4.5);
      expect(review.date, isNotNull);
      expect(review.genres, ['Rock', 'Pop']);
    });

    test('Review.toJson converts Review to JSON', () {
      final review = Review(
        displayName: 'Test User',
        userId: 'user123',
        artist: 'Test Artist',
        title: 'Test Song',
        review: 'Great song!',
        score: 4.5,
        date: DateTime(2024, 1, 1),
        albumImageUrl: 'https://example.com/image.jpg',
        likes: 10,
        replies: 2,
        reposts: 1,
        genres: ['Rock', 'Pop'],
      );

      final json = review.toJson();

      expect(json['displayName'], 'Test User');
      expect(json['userId'], 'user123');
      expect(json['artist'], 'Test Artist');
      expect(json['title'], 'Test Song');
      expect(json['score'], 4.5);
      expect(json['likes'], 10);
      expect(json['genres'], ['Rock', 'Pop']);
      expect(json['date'], isNotNull);
    });

    test('Review handles null score gracefully', () {
      final data = {
        'displayName': 'Test User',
        'userId': 'user123',
        'artist': 'Test Artist',
        'title': 'Test Song',
        'review': 'Great song!',
        'likes': 0,
        'replies': 0,
        'reposts': 0,
      };

      final review = Review.fromFirestore(data);

      expect(review.score, 0.0);
    });
  });
}
