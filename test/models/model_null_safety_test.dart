import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/models/user_models.dart';
import 'package:flutter_test_project/models/user_comments.dart';
import 'package:flutter_test_project/models/song_recommended.dart';

void main() {
  group('UserReviewInfo null safety', () {
    test('fromMap handles Timestamp joinDate', () {
      final map = {
        'id': 'user1',
        'displayName': 'Test User',
        'joinDate': Timestamp.fromDate(DateTime(2024, 6, 15)),
        'reviews': <dynamic>[],
      };

      final user = UserReviewInfo.fromMap(map);
      expect(user.joinDate, isNotNull);
      expect(user.joinDate!.year, 2024);
      expect(user.joinDate!.month, 6);
    });

    test('fromMap handles null joinDate', () {
      final map = {
        'id': 'user2',
        'displayName': 'No Date User',
        'joinDate': null,
      };

      final user = UserReviewInfo.fromMap(map);
      expect(user.joinDate, isNull);
    });

    test('fromMap handles missing joinDate', () {
      final map = {
        'id': 'user3',
        'displayName': 'Missing Date User',
      };

      final user = UserReviewInfo.fromMap(map);
      expect(user.joinDate, isNull);
    });

    test('fromMap handles string joinDate', () {
      final map = {
        'id': 'user4',
        'displayName': 'String Date User',
        'joinDate': '2024-01-15T10:30:00.000Z',
      };

      final user = UserReviewInfo.fromMap(map);
      expect(user.joinDate, isNotNull);
      expect(user.joinDate!.year, 2024);
    });

    test('fromMap handles empty string joinDate', () {
      final map = {
        'id': 'user5',
        'displayName': 'Empty Date User',
        'joinDate': '',
      };

      final user = UserReviewInfo.fromMap(map);
      expect(user.joinDate, isNull);
    });

    test('fromJson handles null joinDate', () {
      final json = {
        'id': 'user6',
        'displayName': 'Json User',
        'joinDate': null,
      };

      final user = UserReviewInfo.fromJson(json);
      expect(user.joinDate, isNull);
    });

    test('fromJson handles string joinDate', () {
      final json = {
        'id': 'user7',
        'displayName': 'Json Date User',
        'joinDate': '2025-03-20T12:00:00.000Z',
      };

      final user = UserReviewInfo.fromJson(json);
      expect(user.joinDate, isNotNull);
      expect(user.joinDate!.year, 2025);
    });

    test('fromMap handles missing reviews', () {
      final map = {
        'id': 'user8',
        'displayName': 'No Reviews',
      };

      final user = UserReviewInfo.fromMap(map);
      expect(user.reviews, isEmpty);
    });

    test('toMap produces correct output', () {
      final user = UserReviewInfo(
        id: 'user9',
        displayName: 'Map User',
        joinDate: DateTime(2024, 1, 1),
        reviews: [],
      );

      final map = user.toMap();
      expect(map['id'], 'user9');
      expect(map['displayName'], 'Map User');
      expect(map['joinDate'], isNotNull);
    });
  });

  group('UserComment null safety', () {
    test('fromJson handles all fields correctly', () {
      final json = {
        'id': 'comment1',
        'name': 'User',
        'avatar': 'https://example.com/avatar.jpg',
        'comment': 'Great post!',
        'likes': 10,
        'replies': 2,
        'reposts': 1,
        'shares': 3,
        'time': '2024-06-15T12:00:00.000Z',
      };

      final comment = UserComment.fromJson(json);
      expect(comment.id, 'comment1');
      expect(comment.name, 'User');
      expect(comment.likes, 10);
      expect(comment.time.year, 2024);
    });

    test('fromJson handles null fields gracefully', () {
      final json = <String, dynamic>{
        'id': null,
        'name': null,
        'avatar': null,
        'comment': null,
        'likes': null,
        'replies': null,
        'reposts': null,
        'shares': null,
        'time': null,
      };

      final comment = UserComment.fromJson(json);
      expect(comment.id, '');
      expect(comment.name, '');
      expect(comment.avatar, '');
      expect(comment.comment, '');
      expect(comment.likes, 0);
      expect(comment.replies, 0);
      expect(comment.reposts, 0);
      expect(comment.shares, 0);
      expect(comment.time, isNotNull); // Falls back to DateTime.now()
    });

    test('fromJson handles missing fields gracefully', () {
      final json = <String, dynamic>{};

      final comment = UserComment.fromJson(json);
      expect(comment.id, '');
      expect(comment.name, '');
      expect(comment.likes, 0);
      expect(comment.time, isNotNull);
    });

    test('fromJson handles invalid time string', () {
      final json = {
        'id': 'c1',
        'name': 'User',
        'avatar': '',
        'comment': '',
        'likes': 0,
        'replies': 0,
        'reposts': 0,
        'shares': 0,
        'time': 'not-a-date',
      };

      final comment = UserComment.fromJson(json);
      // Should fall back to DateTime.now() instead of crashing
      expect(comment.time, isNotNull);
    });

    test('toJson produces valid output', () {
      final comment = UserComment(
        id: 'c2',
        name: 'User',
        avatar: 'avatar.jpg',
        comment: 'Hello',
        likes: 5,
        replies: 1,
        reposts: 0,
        shares: 2,
        time: DateTime(2024, 3, 15),
      );

      final json = comment.toJson();
      expect(json['id'], 'c2');
      expect(json['likes'], 5);
      expect(json['time'], contains('2024'));
    });
  });

  group('SongRecommended null safety', () {
    test('fromJson handles valid data', () {
      final json = {
        'artist': 'Eagles',
        'song': 'Hotel California',
      };

      final song = SongRecommended.fromJson(json);
      expect(song.artist, 'Eagles');
      expect(song.song, 'Hotel California');
    });

    test('fromJson handles null fields', () {
      final json = <String, dynamic>{
        'artist': null,
        'song': null,
      };

      final song = SongRecommended.fromJson(json);
      expect(song.artist, '');
      expect(song.song, '');
    });

    test('fromJson handles missing fields', () {
      final json = <String, dynamic>{};

      final song = SongRecommended.fromJson(json);
      expect(song.artist, '');
      expect(song.song, '');
    });

    test('toJson round-trips correctly', () {
      final song = SongRecommended(artist: 'Artist', song: 'Song');
      final json = song.toJson();
      final restored = SongRecommended.fromJson(json);
      expect(restored.artist, 'Artist');
      expect(restored.song, 'Song');
    });

    test('constructor does not accept stray parameter', () {
      // This just verifies the unused `e` parameter was removed
      // and the constructor works cleanly
      final song = SongRecommended(artist: 'A', song: 'B');
      expect(song.artist, 'A');
      expect(song.song, 'B');
    });
  });
}
