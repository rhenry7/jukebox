import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/providers/similar_reviews_provider.dart';
import 'package:flutter_test_project/providers/tag_reviews_provider.dart';

Future<void> _add(
  FakeFirebaseFirestore db,
  String path, {
  required String title,
  required List<String> genres,
  int day = 1,
  bool isRepost = false,
}) =>
    db.doc(path).set({
      'title': title,
      'artist': 'Artist $title',
      'userId': path.split('/')[1],
      'displayName': 'u',
      'review': 'text',
      'score': 4.0,
      'likes': 0,
      'replies': 0,
      'reposts': 0,
      'genres': genres,
      'date': Timestamp.fromDate(DateTime(2026, 1, day)),
      if (isRepost) 'isRepost': true,
      ...searchKeysFor(genres: genres, isRepost: isRepost),
    });

SimilarReviewsKey _key(List<String> tags,
        {String? path, String title = 'Me'}) =>
    (path: path, title: title, artist: 'Artist $title', tags: tags.join('\n'));

List<String?> _titles(List results) =>
    [for (final r in results) r.review.title as String?];

void main() {
  late FakeFirebaseFirestore db;
  setUp(() => db = FakeFirebaseFirestore());

  test('ranks by shared tags and leaves out itself, reposts and the same track',
      () async {
    await _add(db, 'users/a/reviews/self',
        title: 'Me', genres: ['indie', 'rock']);
    await _add(db, 'users/b/reviews/1',
        title: 'Both', genres: ['indie', 'rock']);
    await _add(db, 'users/c/reviews/2', title: 'One', genres: ['rock'], day: 9);
    await _add(db, 'users/d/reviews/3', title: 'Me', genres: ['indie']);
    await _add(db, 'users/e/reviews/4',
        title: 'Repost', genres: ['indie'], isRepost: true);
    await _add(db, 'users/f/reviews/5', title: 'Jazz', genres: ['jazz']);

    final results = await findSimilarReviews(
        db, _key(['indie', 'rock'], path: 'users/a/reviews/self'));

    expect(_titles(results), ['Both', 'One']);
  });

  test('widens to shared tag words when exact tags are scarce', () async {
    await _add(db, 'users/b/reviews/1', title: 'Pop', genres: ['indie pop']);
    await _add(db, 'users/c/reviews/2', title: 'Exact', genres: ['indie rock']);

    final results = await findSimilarReviews(db, _key(['indie rock']));

    expect(_titles(results), ['Exact', 'Pop']);
  });

  test('shows one review per track and at most five', () async {
    for (var i = 0; i < 8; i++) {
      await _add(db, 'users/u$i/reviews/r',
          title: 'T$i', genres: ['soul'], day: i + 1);
    }
    await _add(db, 'users/x/reviews/dup', title: 'T7', genres: ['soul']);

    final results = await findSimilarReviews(db, _key(['soul']));

    expect(results, hasLength(similarReviewCount));
    expect(_titles(results).toSet(), hasLength(similarReviewCount));
    expect(_titles(results).first, 'T7');
  });

  test('a review with no tags has no similar reviews', () async {
    await _add(db, 'users/b/reviews/1', title: 'Any', genres: ['rock']);
    expect(await findSimilarReviews(db, _key([])), isEmpty);
  });
}
