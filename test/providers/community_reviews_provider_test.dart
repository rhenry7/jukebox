import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/providers/community_reviews_provider.dart';
import 'package:flutter_test_project/providers/reviews_provider.dart';

Review _review(String text, {String? image = 'https://img/art.jpg'}) => Review(
      displayName: 'a',
      userId: 'u',
      artist: 'Artist',
      review: text,
      score: 4,
      likes: 0,
      replies: 0,
      reposts: 0,
      title: 'Title',
      albumImageUrl: image,
    );

ReviewWithDocId _item(String id) => ReviewWithDocId(
      review: _review('x' * 60),
      docId: id,
      fullReviewId: 'users/u/reviews/$id',
    );

void main() {
  group('isPopularEligible', () {
    test('needs more than 50 characters of text', () {
      expect(isPopularEligible(_review('x' * 50)), isFalse);
      expect(isPopularEligible(_review('x' * 51)), isTrue);
      expect(isPopularEligible(_review('   ${'x' * 49}    ')), isFalse);
    });

    test('needs album art', () {
      expect(isPopularEligible(_review('x' * 60, image: null)), isFalse);
      expect(isPopularEligible(_review('x' * 60, image: '  ')), isFalse);
    });
  });

  group('shuffleReviews', () {
    final items = [for (var i = 0; i < 30; i++) _item('r$i')];
    List<String> ids(List<ReviewWithDocId> l) => [for (final r in l) r.docId];

    test('keeps every review exactly once', () {
      expect(ids(shuffleReviews(items, 1))..sort(), ids(items)..sort());
    });

    test('different seeds give different orders', () {
      expect(ids(shuffleReviews(items, 1)),
          isNot(equals(ids(shuffleReviews(items, 2)))));
    });

    test('same seed keeps existing cards in place when one is added', () {
      final before = ids(shuffleReviews(items, 7));
      final after = ids(shuffleReviews([...items, _item('new')], 7))
        ..remove('new');
      expect(after, before);
    });
  });

  group('keepPlacedOrder', () {
    List<String> ids(List<ReviewWithDocId> l) => [for (final r in l) r.docId];

    test('cards already placed keep their places; new ones go after', () {
      final first = [for (var i = 0; i < 3; i++) _item('n$i')];
      final placed = ids(keepPlacedOrder(first, const [], 5));

      final more = [...first, for (var i = 0; i < 6; i++) _item('r$i')];
      final next = ids(keepPlacedOrder(
          more, [for (final id in placed) 'users/u/reviews/$id'], 5));

      expect(next.take(3), placed);
      expect(next.skip(3).toSet(), {for (var i = 0; i < 6; i++) 'r$i'});
    });

    test('a placed review that is gone is dropped', () {
      final items = [_item('a'), _item('b')];
      final next =
          keepPlacedOrder(items, ['users/u/reviews/x', 'users/u/reviews/b'], 1);
      expect(ids(next).first, 'b');
      expect(ids(next), hasLength(2));
    });
  });
}
