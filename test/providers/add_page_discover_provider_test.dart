import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/providers/add_page_discover_provider.dart';
import 'package:flutter_test_project/providers/reviews_provider.dart';

ReviewWithDocId _r(
  String user,
  String title,
  String artist,
  double score, {
  String art = 'https://i.scdn.co/x.jpg',
  int day = 1,
  bool repost = false,
  String? spotify,
}) => ReviewWithDocId(
  docId: '$user-$title',
  review: Review(
    displayName: user,
    userId: user,
    artist: artist,
    review: 'x',
    score: score,
    likes: 0,
    replies: 0,
    reposts: 0,
    title: title,
    albumImageUrl: art,
    date: DateTime(2026, 1, day),
    isRepost: repost,
    spotifyUrl: spotify,
  ),
);

void main() {
  group('topRatedTracks', () {
    test('groups by song, keeps 4★+ averages, best first', () {
      final out = topRatedTracks([
        _r(
          'a',
          'Tadow',
          'Masego, FKJ',
          5,
          spotify: 'https://open.spotify.com/track/1',
        ),
        _r('b', 'tadow', 'Masego', 4),
        _r('c', 'Sir Duke', 'Stevie Wonder', 5),
        _r('d', 'Meh', 'Someone', 3),
        _r('e', 'No Art', 'X', 5, art: ''),
        _r('f', 'Repost', 'Y', 5, repost: true),
      ]);
      expect([for (final t in out) t.title], ['Sir Duke', 'Tadow']);
      final tadow = out.last;
      expect(tadow.averageScore, 4.5);
      expect(tadow.reviewCount, 2);
      expect(tadow.spotifyUrl, 'https://open.spotify.com/track/1');
    });

    test('a song several people rate highly beats a single rave', () {
      final out = topRatedTracks([
        _r('a', 'Lone', 'A', 5),
        _r('b', 'Loved', 'B', 5),
        _r('c', 'Loved', 'B', 4.5),
      ]);
      expect([for (final t in out) t.title], ['Loved', 'Lone']);
    });

    test('ties: more reviews first, then newest; reviewed songs left out', () {
      final out = topRatedTracks(
        [
          _r('a', 'One', 'A', 5, day: 9),
          _r('b', 'Two', 'B', 5, day: 1),
          _r('c', 'Two', 'B', 5, day: 2),
          _r('d', 'Mine', 'C', 5),
        ],
        exclude: {'mine|c'},
      );
      expect([for (final t in out) t.title], ['Two', 'One']);
    });
  });

  group('suggestedReviewers', () {
    final pool = [
      _r('busy', 'S1', 'Rock Band', 4),
      _r('busy', 'S2', 'Rock Band', 4),
      _r('busy', 'S3', 'Rock Band', 4),
      _r('twin', 'S4', 'Masego', 5),
      _r('friend', 'S5', 'Masego', 5),
      _r('me', 'S6', 'Masego', 5),
    ];

    test('shared artists first, then most active; never me or friends', () {
      final out = suggestedReviewers(
        pool,
        myUserId: 'me',
        following: {'friend'},
        myReviews: [_r('me', 'Tadow', 'Masego, FKJ', 5)],
      );
      expect([for (final s in out) s.userId], ['twin', 'busy']);
      expect(out.first.sharedArtist, 'Masego');
      expect(out.last.reviewCount, 3);
      expect(out.last.sharedArtist, isNull);
    });

    test('dismissed reviewers are hidden', () {
      final out = suggestedReviewers(pool, myUserId: 'me', dismissed: {'twin'});
      expect(out.any((s) => s.userId == 'twin'), isFalse);
    });
  });
}
