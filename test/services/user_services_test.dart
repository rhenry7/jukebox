import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/models/user_models.dart';
import 'package:flutter_test_project/services/user_services.dart';

/// Testable version of [UserServices] that accepts injected Firestore
/// instead of using the static singleton.
class TestableUserServices {
  final FakeFirebaseFirestore firestore;

  TestableUserServices(this.firestore);

  Future<UserReviewInfo> fetchUserInfo(String userId) async {
    try {
      final List<Review> reviews = await firestore
          .collection('users')
          .doc(userId)
          .collection('reviews')
          .orderBy('date', descending: true)
          .get()
          .then((snapshot) => snapshot.docs
              .map((doc) => Review.fromFirestore(doc.data()))
              .toList());

      final userDoc =
          await firestore.collection('users').doc(userId).get();

      if (reviews.isNotEmpty) {
        return UserReviewInfo(
          displayName: userDoc.data()?['displayName'] ?? '',
          joinDate: userDoc.data()?['joinDate'] != null
              ? (userDoc.data()!['joinDate'] as Timestamp).toDate()
              : null,
          reviews: reviews,
          id: userId,
        );
      } else {
        return UserReviewInfo(
          displayName: userDoc.data()?['displayName'] ?? 'Undefined',
          joinDate: null,
          reviews: [],
          id: userId,
        );
      }
    } catch (e) {
      return UserReviewInfo(
        displayName: 'Undefined',
        joinDate: null,
        reviews: [],
        id: '',
      );
    }
  }

  Future<List<Review>> fetchUserReviews(String userId) async {
    try {
      final snapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('reviews')
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Review.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<UserReviewInfo>> fetchUsers() async {
    try {
      final snapshot = await firestore.collection('users').get();
      return snapshot.docs
          .map((doc) => UserReviewInfo.fromJson(doc.data()))
          .toList();
    } catch (e) {
      return [];
    }
  }

  double getAverageRating(List<Review> reviews) {
    if (reviews.isEmpty) return 0.0;
    double total = 0.0;
    for (final review in reviews) {
      total += review.score;
    }
    return total / reviews.length;
  }
}

// ──────────────────────────────────────────────────────────
// Helper to seed Firestore with user + reviews
// ──────────────────────────────────────────────────────────
Future<void> _seedUser(
  FakeFirebaseFirestore firestore, {
  required String userId,
  required String displayName,
  DateTime? joinDate,
  List<Map<String, dynamic>> reviews = const [],
}) async {
  final userRef = firestore.collection('users').doc(userId);
  await userRef.set({
    'displayName': displayName,
    if (joinDate != null) 'joinDate': Timestamp.fromDate(joinDate),
  });

  for (final reviewData in reviews) {
    await userRef.collection('reviews').add(reviewData);
  }
}

void main() {
  // ──────────────────────────────────────────────────────────
  // getAverageRating (pure logic — no Firebase)
  // ──────────────────────────────────────────────────────────
  group('UserServices - getAverageRating', () {
    final userServices = UserServices();

    test('returns 0.0 for empty list', () {
      expect(userServices.getAverageRating([]), 0.0);
    });

    test('returns correct average for single review', () {
      final reviews = [
        Review(
          displayName: 'User',
          userId: 'u1',
          artist: 'Artist',
          review: 'Great',
          score: 4.5,
          likes: 0,
          replies: 0,
          reposts: 0,
          title: 'Song',
        ),
      ];
      expect(userServices.getAverageRating(reviews), 4.5);
    });

    test('returns correct average for multiple reviews', () {
      final reviews = [
        Review(
          displayName: 'U',
          userId: 'u1',
          artist: 'A',
          review: 'r',
          score: 5.0,
          likes: 0,
          replies: 0,
          reposts: 0,
          title: 'T1',
        ),
        Review(
          displayName: 'U',
          userId: 'u1',
          artist: 'A',
          review: 'r',
          score: 3.0,
          likes: 0,
          replies: 0,
          reposts: 0,
          title: 'T2',
        ),
        Review(
          displayName: 'U',
          userId: 'u1',
          artist: 'A',
          review: 'r',
          score: 4.0,
          likes: 0,
          replies: 0,
          reposts: 0,
          title: 'T3',
        ),
      ];
      expect(userServices.getAverageRating(reviews), 4.0);
    });

    test('handles all-zero scores', () {
      final reviews = [
        Review(
          displayName: 'U',
          userId: 'u1',
          artist: 'A',
          review: 'r',
          score: 0.0,
          likes: 0,
          replies: 0,
          reposts: 0,
          title: 'T',
        ),
      ];
      expect(userServices.getAverageRating(reviews), 0.0);
    });
  });

  // ──────────────────────────────────────────────────────────
  // fetchUserInfo (with FakeFirebaseFirestore)
  // ──────────────────────────────────────────────────────────
  group('TestableUserServices - fetchUserInfo', () {
    late FakeFirebaseFirestore fakeFirestore;
    late TestableUserServices service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = TestableUserServices(fakeFirestore);
    });

    test('returns user info with reviews when user has reviews', () async {
      await _seedUser(fakeFirestore,
          userId: 'user1',
          displayName: 'TestUser',
          joinDate: DateTime(2024, 1, 15),
          reviews: [
            {
              'displayName': 'TestUser',
              'userId': 'user1',
              'artist': 'Radiohead',
              'review': 'Great album!',
              'score': 4.5,
              'title': 'OK Computer',
              'likes': 10,
              'replies': 2,
              'reposts': 1,
              'date': Timestamp.fromDate(DateTime(2024, 6, 1)),
            },
          ]);

      final result = await service.fetchUserInfo('user1');

      expect(result.displayName, 'TestUser');
      expect(result.id, 'user1');
      expect(result.reviews, isNotEmpty);
      expect(result.reviews!.first.artist, 'Radiohead');
      expect(result.reviews!.first.score, 4.5);
    });

    test('returns default when user has no reviews', () async {
      await _seedUser(fakeFirestore,
          userId: 'user2', displayName: 'EmptyUser');

      final result = await service.fetchUserInfo('user2');

      expect(result.displayName, 'EmptyUser');
      expect(result.reviews, isEmpty);
    });

    test('returns default for non-existent user', () async {
      final result = await service.fetchUserInfo('ghost-user');
      expect(result.reviews, isEmpty);
    });

    test('handles multiple reviews ordered by date', () async {
      await _seedUser(fakeFirestore,
          userId: 'user3',
          displayName: 'MultiReview',
          reviews: [
            {
              'displayName': 'MultiReview',
              'userId': 'user3',
              'artist': 'Artist A',
              'review': 'Older',
              'score': 3.0,
              'title': 'Song A',
              'likes': 0,
              'replies': 0,
              'reposts': 0,
              'date': Timestamp.fromDate(DateTime(2024, 1, 1)),
            },
            {
              'displayName': 'MultiReview',
              'userId': 'user3',
              'artist': 'Artist B',
              'review': 'Newer',
              'score': 5.0,
              'title': 'Song B',
              'likes': 5,
              'replies': 1,
              'reposts': 0,
              'date': Timestamp.fromDate(DateTime(2024, 6, 1)),
            },
          ]);

      final result = await service.fetchUserInfo('user3');

      expect(result.reviews!.length, 2);
      // Ordered descending by date — newest first
      expect(result.reviews!.first.artist, 'Artist B');
      expect(result.reviews!.last.artist, 'Artist A');
    });
  });

  // ──────────────────────────────────────────────────────────
  // fetchUserReviews
  // ──────────────────────────────────────────────────────────
  group('TestableUserServices - fetchUserReviews', () {
    late FakeFirebaseFirestore fakeFirestore;
    late TestableUserServices service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = TestableUserServices(fakeFirestore);
    });

    test('returns reviews for user with reviews', () async {
      await _seedUser(fakeFirestore,
          userId: 'user1',
          displayName: 'Reviewer',
          reviews: [
            {
              'displayName': 'Reviewer',
              'userId': 'user1',
              'artist': 'Daft Punk',
              'review': 'Classic',
              'score': 5.0,
              'title': 'Discovery',
              'likes': 20,
              'replies': 5,
              'reposts': 3,
              'date': Timestamp.fromDate(DateTime(2024, 3, 15)),
            },
          ]);

      final reviews = await service.fetchUserReviews('user1');

      expect(reviews.length, 1);
      expect(reviews.first.title, 'Discovery');
      expect(reviews.first.score, 5.0);
    });

    test('returns empty list for user with no reviews', () async {
      await _seedUser(fakeFirestore,
          userId: 'user2', displayName: 'NoReviews');
      final reviews = await service.fetchUserReviews('user2');
      expect(reviews, isEmpty);
    });

    test('returns empty list for non-existent user', () async {
      final reviews = await service.fetchUserReviews('does-not-exist');
      expect(reviews, isEmpty);
    });
  });

  // ──────────────────────────────────────────────────────────
  // fetchUsers
  // ──────────────────────────────────────────────────────────
  group('TestableUserServices - fetchUsers', () {
    late FakeFirebaseFirestore fakeFirestore;
    late TestableUserServices service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = TestableUserServices(fakeFirestore);
    });

    test('returns empty list when no users exist', () async {
      final users = await service.fetchUsers();
      expect(users, isEmpty);
    });

    test('returns all users from Firestore', () async {
      await fakeFirestore.collection('users').doc('u1').set({
        'id': 'u1',
        'displayName': 'Alice',
      });
      await fakeFirestore.collection('users').doc('u2').set({
        'id': 'u2',
        'displayName': 'Bob',
      });

      final users = await service.fetchUsers();

      expect(users.length, 2);
      final names = users.map((u) => u.displayName).toSet();
      expect(names, containsAll(['Alice', 'Bob']));
    });
  });

  // ──────────────────────────────────────────────────────────
  // Review model round-trip through Firestore
  // ──────────────────────────────────────────────────────────
  group('TestableUserServices - review round-trip', () {
    late FakeFirebaseFirestore fakeFirestore;
    late TestableUserServices service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = TestableUserServices(fakeFirestore);
    });

    test('review with genres and tags survives Firestore round-trip',
        () async {
      await _seedUser(fakeFirestore,
          userId: 'user1',
          displayName: 'Tagger',
          reviews: [
            {
              'displayName': 'Tagger',
              'userId': 'user1',
              'artist': 'Tame Impala',
              'review': 'Psychedelic greatness',
              'score': 4.8,
              'title': 'Currents',
              'likes': 5,
              'replies': 0,
              'reposts': 0,
              'date': Timestamp.fromDate(DateTime(2024, 5, 1)),
              'genres': ['psychedelic rock', 'indie', 'chill', 'summer vibes'],
            },
          ]);

      final reviews = await service.fetchUserReviews('user1');

      expect(reviews.length, 1);
      expect(reviews.first.genres, containsAll(['psychedelic rock', 'indie', 'chill', 'summer vibes']));
    });

    test('review with null genres and tags reads back as null', () async {
      await _seedUser(fakeFirestore,
          userId: 'user1',
          displayName: 'NoTags',
          reviews: [
            {
              'displayName': 'NoTags',
              'userId': 'user1',
              'artist': 'Artist',
              'review': 'No tags',
              'score': 3.0,
              'title': 'Track',
              'likes': 0,
              'replies': 0,
              'reposts': 0,
              'date': Timestamp.fromDate(DateTime(2024, 1, 1)),
              // genres and tags intentionally omitted
            },
          ]);

      final reviews = await service.fetchUserReviews('user1');

      expect(reviews.first.genres, isNull);
    });
  });
}
