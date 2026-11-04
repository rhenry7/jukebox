import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/providers/reviews_provider.dart';
import 'package:flutter_test_project/services/tag_match_service.dart';

ReviewWithDocId _r(
  String id,
  List<String> genres, {
  String user = 'other',
  String title = '',
  String artist = 'Artist',
  bool repost = false,
  int day = 1,
}) =>
    ReviewWithDocId(
      docId: id,
      fullReviewId: 'users/$user/reviews/$id',
      review: Review(
        displayName: user,
        userId: user,
        artist: artist,
        review: 'text',
        score: 4,
        likes: 0,
        replies: 0,
        reposts: 0,
        title: title.isEmpty ? 'Song $id' : title,
        genres: genres,
        date: DateTime(2026, 1, day),
        isRepost: repost,
      ),
    );

List<String> _ids(List<dynamic> matches) =>
    [for (final m in matches) m.review.docId as String];

void main() {
  List<dynamic> rank(List<ReviewWithDocId> candidates) => rankByTagOverlap(
        tags: ['R&B', 'soul', 'neo-soul'],
        title: 'Best to You',
        artist: 'Blood Orange',
        authorId: 'me',
        candidates: candidates,
      );

  test('more shared tags rank higher, ignoring case', () {
    final ranked = rank([
      _r('one', ['rnb', 'Soul']),
      _r('two', ['r&b', 'SOUL', 'jazz']),
      _r('none', ['metal']),
    ]);
    expect(_ids(ranked), ['two', 'one']);
    expect(ranked.first.reason, 'Also tagged r&b, SOUL');
  });

  test('ties go to the closer match, then the newer review', () {
    final ranked = rank([
      _r('broad', ['soul', 'jazz', 'funk', 'disco'], day: 9),
      _r('tight', ['soul'], day: 1),
      _r('tight-new', ['soul'], day: 5),
    ]);
    expect(_ids(ranked), ['tight-new', 'tight', 'broad']);
  });

  test('skips own reviews, reposts, the same track and repeat tracks', () {
    final ranked = rank([
      _r('mine', ['soul'], user: 'me'),
      _r('repost', ['soul'], repost: true),
      _r('same', ['soul'], title: 'best to you', artist: 'BLOOD ORANGE'),
      _r('a', ['soul'], title: 'Twin', day: 3),
      _r('b', ['soul'], title: 'Twin', day: 2),
    ]);
    expect(_ids(ranked), ['a']);
  });

  test('no tags on the new review means no matches', () {
    expect(
      rankByTagOverlap(
        tags: const [],
        title: 't',
        artist: 'a',
        authorId: 'me',
        candidates: [_r('x', ['soul'])],
      ),
      isEmpty,
    );
  });
}
