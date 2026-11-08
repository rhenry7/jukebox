import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/providers/home_feed_controls.dart';

Review _r(String title, List<String> genres, {double score = 3, int day = 1}) =>
    Review(
      displayName: 'u',
      userId: 'u',
      artist: 'a',
      review: 'text',
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
}
