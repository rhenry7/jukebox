import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/providers/home_feed_controls.dart';

Review _r(
  String title,
  List<String> genres, {
  double score = 3,
  int day = 1,
  String text = 'text',
  int? year,
  String artist = 'a',
}) => Review(
  displayName: 'u',
  userId: 'u',
  artist: artist,
  review: text,
  releaseYear: year,
  score: score,
  likes: 0,
  replies: 0,
  reposts: 0,
  title: title,
  genres: genres,
  date: DateTime(2026, 1, day),
);

List<String> _titles(List<Review> l) => [for (final r in l) r.title];

void main() {
  group('tagChoicesFrom', () {
    final reviews = [
      _r('a', ['rock', 'indie']),
      _r('b', ['Rock', 'punk']),
      _r('c', ['R&B', 'rock']),
      _r('d', ['rnb', 'soul']),
    ];

    test('the most used tags, each once (spelling variants count as one)', () {
      final tags = tagChoicesFrom(reviews, seed: 1, count: 2);
      expect(tags.toSet(), {'rock', 'R&B'});
    });

    test('shuffled, but the same order for the same seed', () {
      final a = tagChoicesFrom(reviews, seed: 7);
      expect(tagChoicesFrom(reviews, seed: 7), a);
      expect(a.toSet(), {'rock', 'indie', 'punk', 'R&B', 'soul'});
    });
  });

  group('matchesTagFilter', () {
    test('no filter matches everything', () {
      expect(matchesTagFilter(_r('a', []), const {}), isTrue);
    });

    test('any picked tag matches, in any spelling', () {
      final review = _r('a', ['R and B', 'Soul']);
      expect(matchesTagFilter(review, {'r&b'}), isTrue);
      expect(matchesTagFilter(review, {'jazz', 'soul'}), isTrue);
      expect(matchesTagFilter(review, {'jazz'}), isFalse);
    });
  });

  group('applyHomeSort', () {
    final items = [
      _r('old-mid', [], score: 3, day: 1),
      _r('new-low', [], score: 1, day: 9),
      _r('mid-high', [], score: 5, day: 5),
      _r('mid-high-2', [], score: 5, day: 4),
    ];
    List<String> sorted(HomeSort s) =>
        _titles(applyHomeSort(items, s, (r) => r));

    test('default keeps the given order', () {
      expect(sorted(HomeSort.standard), _titles(items));
    });
    test('most recent first', () {
      expect(sorted(HomeSort.recent), [
        'new-low',
        'mid-high',
        'mid-high-2',
        'old-mid',
      ]);
    });
    test('rating high to low; ties keep their order', () {
      expect(sorted(HomeSort.ratingHigh), [
        'mid-high',
        'mid-high-2',
        'old-mid',
        'new-low',
      ]);
    });
    test('rating low to high', () {
      expect(sorted(HomeSort.ratingLow).first, 'new-low');
      expect(sorted(HomeSort.ratingLow).last, 'mid-high-2');
    });
  });

  group('more sorts', () {
    List<String> sorted(List<Review> items, HomeSort s) =>
        _titles(applyHomeSort(items, s, (r) => r));

    test('release year: newest / oldest, unknown years last', () {
      final items = [
        _r('70s', [], year: 1975),
        _r('unknown', []),
        _r('2017', [], year: 2017),
        _r('60s', [], year: 1964),
      ];
      expect(sorted(items, HomeSort.releaseNewest), [
        '2017',
        '70s',
        '60s',
        'unknown',
      ]);
      expect(sorted(items, HomeSort.releaseOldest), [
        '60s',
        '70s',
        '2017',
        'unknown',
      ]);
    });

    test('longest reads first', () {
      final items = [
        _r('short', [], text: 'ok'),
        _r('long', [], text: 'x' * 400),
        _r('mid', [], text: 'x' * 120),
      ];
      expect(sorted(items, HomeSort.longest), ['long', 'mid', 'short']);
    });

    test('divisive: most-disagreed songs first, their reviews together', () {
      final items = [
        _r('agreed-1', [], score: 4, artist: 'B'),
        _r('split-low', [], score: 1, artist: 'A'),
        _r('alone', [], score: 5, artist: 'C'),
        _r('agreed-2', [], score: 4, artist: 'B'),
        _r('split-high', [], score: 5, artist: 'A'),
      ].map(_sameSong).toList();
      final order = [
        for (final r in applyHomeSort(items, HomeSort.divisive, (r) => r))
          r.genres!.first,
      ];
      expect(order, [
        'split-high', // song A: 1★ vs 5★ (spread 4), highest rating first
        'split-low',
        'agreed-1', // song B: both 4★, then C: one review, in list order
        'agreed-2',
        'alone',
      ]);
    });
  });
}

/// Reviews of the same artist count as the same song here (titles differ
/// only so the test can tell them apart).
Review _sameSong(Review r) => Review(
  displayName: r.displayName,
  userId: r.userId,
  artist: r.artist,
  review: r.review,
  score: r.score,
  likes: 0,
  replies: 0,
  reposts: 0,
  title: 'song ${r.artist}',
  genres: [r.title],
);
