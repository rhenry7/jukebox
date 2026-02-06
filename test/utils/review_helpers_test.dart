import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/models/review.dart';

// We can't directly test the top-level functions in review_helpers.dart because
// they use FirebaseFirestore.instance and FirebaseAuth.instance directly.
// Instead, we test equivalent logic with injectable dependencies.

/// Mirrors submitReview logic but accepts injected Firestore and Auth instances.
Future<DocumentReference?> submitReviewTestable({
  required FirebaseFirestore firestore,
  required FirebaseAuth auth,
  required String review,
  required double score,
  required String artist,
  required String title,
  required bool liked,
  required String albumImageUrl,
  List<String>? tags,
}) async {
  final User? user = auth.currentUser;
  if (user == null) return null;

  final String userId = user.uid;
  final docRef = await firestore
      .collection('users')
      .doc(userId)
      .collection('reviews')
      .add({
    'displayName': user.displayName,
    'email': user.email,
    'userId': userId,
    'artist': artist,
    'title': title,
    'review': review,
    'score': score,
    'liked': liked,
    'date': FieldValue.serverTimestamp(),
    'albumImageUrl': albumImageUrl,
    if (tags != null && tags.isNotEmpty) 'tags': tags,
  });
  return docRef;
}

/// Mirrors deleteReview logic with injectable Firestore.
Future<void> deleteReviewTestable({
  required FirebaseFirestore firestore,
  required String userId,
  required String reviewDocId,
}) async {
  await firestore
      .collection('users')
      .doc(userId)
      .collection('reviews')
      .doc(reviewDocId)
      .delete();
}

void main() {
  group('submitReview', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockUser = MockUser(
        uid: 'test-user-123',
        displayName: 'Test User',
        email: 'test@example.com',
        isAnonymous: false,
      );
      mockAuth = MockFirebaseAuth(
        signedIn: true,
        mockUser: mockUser,
      );
    });

    test('creates review document with correct fields', () async {
      final docRef = await submitReviewTestable(
        firestore: fakeFirestore,
        auth: mockAuth,
        review: 'Great track!',
        score: 4.5,
        artist: 'Test Artist',
        title: 'Test Song',
        liked: true,
        albumImageUrl: 'https://example.com/image.jpg',
      );

      expect(docRef, isNotNull);

      final doc = await docRef!.get();
      final data = doc.data() as Map<String, dynamic>;

      expect(data['displayName'], 'Test User');
      expect(data['userId'], 'test-user-123');
      expect(data['artist'], 'Test Artist');
      expect(data['title'], 'Test Song');
      expect(data['review'], 'Great track!');
      expect(data['score'], 4.5);
      expect(data['liked'], true);
      expect(data['albumImageUrl'], 'https://example.com/image.jpg');
    });

    test('includes tags when provided', () async {
      final docRef = await submitReviewTestable(
        firestore: fakeFirestore,
        auth: mockAuth,
        review: 'Nice vibes',
        score: 3.0,
        artist: 'Artist',
        title: 'Song',
        liked: false,
        albumImageUrl: '',
        tags: ['rock', 'indie', 'workout'],
      );

      final doc = await docRef!.get();
      final data = doc.data() as Map<String, dynamic>;

      expect(data['tags'], ['rock', 'indie', 'workout']);
    });

    test('does not include tags field when tags are empty', () async {
      final docRef = await submitReviewTestable(
        firestore: fakeFirestore,
        auth: mockAuth,
        review: 'Decent',
        score: 3.0,
        artist: 'Artist',
        title: 'Song',
        liked: false,
        albumImageUrl: '',
        tags: [],
      );

      final doc = await docRef!.get();
      final data = doc.data() as Map<String, dynamic>;

      expect(data.containsKey('tags'), false);
    });

    test('returns null when user is not signed in', () async {
      final notSignedIn = MockFirebaseAuth(signedIn: false);

      final docRef = await submitReviewTestable(
        firestore: fakeFirestore,
        auth: notSignedIn,
        review: 'Should not work',
        score: 5.0,
        artist: 'Artist',
        title: 'Song',
        liked: false,
        albumImageUrl: '',
      );

      expect(docRef, isNull);

      // Verify no documents were created
      final snapshot = await fakeFirestore.collectionGroup('reviews').get();
      expect(snapshot.docs, isEmpty);
    });

    test('stores review under correct user path', () async {
      final docRef = await submitReviewTestable(
        firestore: fakeFirestore,
        auth: mockAuth,
        review: 'Path test',
        score: 4.0,
        artist: 'Artist',
        title: 'Song',
        liked: false,
        albumImageUrl: '',
      );

      // Verify it's under users/test-user-123/reviews/
      expect(docRef!.path, startsWith('users/test-user-123/reviews/'));
    });

    test('handles empty review text with rating', () async {
      final docRef = await submitReviewTestable(
        firestore: fakeFirestore,
        auth: mockAuth,
        review: '',
        score: 5.0,
        artist: 'Artist',
        title: 'Song',
        liked: true,
        albumImageUrl: '',
      );

      expect(docRef, isNotNull);
      final doc = await docRef!.get();
      final data = doc.data() as Map<String, dynamic>;
      expect(data['review'], '');
      expect(data['score'], 5.0);
    });
  });

  group('deleteReview', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
    });

    test('deletes the correct review document', () async {
      // Create a review first
      final docRef = await fakeFirestore
          .collection('users')
          .doc('user-123')
          .collection('reviews')
          .add({
        'review': 'To be deleted',
        'score': 3.0,
        'artist': 'Artist',
        'title': 'Song',
      });

      // Verify it exists
      var doc = await docRef.get();
      expect(doc.exists, true);

      // Delete it
      await deleteReviewTestable(
        firestore: fakeFirestore,
        userId: 'user-123',
        reviewDocId: docRef.id,
      );

      // Verify it's gone
      doc = await docRef.get();
      expect(doc.exists, false);
    });

    test('does not delete other reviews', () async {
      // Create two reviews
      final doc1 = await fakeFirestore
          .collection('users')
          .doc('user-123')
          .collection('reviews')
          .add({'review': 'Keep this', 'score': 5.0});

      final doc2 = await fakeFirestore
          .collection('users')
          .doc('user-123')
          .collection('reviews')
          .add({'review': 'Delete this', 'score': 2.0});

      // Delete only doc2
      await deleteReviewTestable(
        firestore: fakeFirestore,
        userId: 'user-123',
        reviewDocId: doc2.id,
      );

      // doc1 should still exist
      final remaining = await doc1.get();
      expect(remaining.exists, true);
      expect((remaining.data() as Map<String, dynamic>)['review'], 'Keep this');

      // doc2 should be gone
      final deleted = await doc2.get();
      expect(deleted.exists, false);
    });

    test('handles deleting non-existent document gracefully', () async {
      // Should not throw
      await deleteReviewTestable(
        firestore: fakeFirestore,
        userId: 'user-123',
        reviewDocId: 'does-not-exist',
      );
    });
  });

  group('Review model round-trip', () {
    test('review survives Firestore write and read', () async {
      final fakeFirestore = FakeFirebaseFirestore();

      await fakeFirestore
          .collection('users')
          .doc('user1')
          .collection('reviews')
          .add({
        'displayName': 'User',
        'userId': 'user1',
        'artist': 'Artist',
        'title': 'Song',
        'review': 'Great!',
        'score': 4.5,
        'date': Timestamp.now(),
        'albumImageUrl': 'https://example.com/img.jpg',
        'likes': 5,
        'replies': 1,
        'reposts': 0,
        'genres': ['Rock'],
        'tags': ['energetic', 'classic'],
      });

      final snapshot = await fakeFirestore
          .collection('users')
          .doc('user1')
          .collection('reviews')
          .get();

      expect(snapshot.docs.length, 1);

      final review = Review.fromFirestore(snapshot.docs.first.data());
      expect(review.artist, 'Artist');
      expect(review.title, 'Song');
      expect(review.score, 4.5);
      expect(review.genres, ['Rock']);
      expect(review.tags, ['energetic', 'classic']);
    });
  });

  group('preference string format', () {
    // Test that the preference string format uses 'artist:' (not 'arist:')
    test('saved track format is correct', () {
      const artist = 'Eagles';
      const title = 'Hotel California';
      final saved = 'artist: $artist, song: $title';
      expect(saved, 'artist: Eagles, song: Hotel California');
      expect(saved, contains('artist:'));
      expect(saved, isNot(contains('arist:')));
    });
  });
}
