import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/services/for_you_service.dart';

Map<String, dynamic> _review(String title, String userId) => {
      'displayName': 'someone',
      'userId': userId,
      'artist': 'Artist',
      'title': title,
      'review': 'Great tape hiss and lazy drums.',
      'score': 4.5,
      'likes': 0,
      'replies': 0,
      'reposts': 0,
    };

void main() {
  late FakeFirebaseFirestore db;

  setUp(() async {
    db = FakeFirebaseFirestore();
    await db.doc('users/b/reviews/r1').set(_review('Neon Rain', 'b'));
    await db.doc('users/c/reviews/r2').set(_review('Subway Shimmer', 'c'));
  });

  test('emits null when no server-built list exists (caller falls back)', () async {
    expect(await ForYouService.watch('a', db: db).first, isNull);
  });

  test('maps cached items to reviews in server order, with reasons', () async {
    await db.doc('users/a/forYou/current').set({
      'items': [
        {'reviewPath': 'users/c/reviews/r2', 'score': 0.9, 'reason': 'Also praises crisp drums'},
        {'reviewPath': 'users/b/reviews/r1', 'score': 0.7, 'reason': 'Reads a lot like your review of X'},
      ],
    });

    final list = (await ForYouService.watch('a', db: db).first)!;
    expect(list.map((s) => s.reviewWithDocId.review.title), ['Subway Shimmer', 'Neon Rain']);
    expect(list.first.reason, 'Also praises crisp drums');
    expect(list.first.reviewWithDocId.fullReviewId, 'users/c/reviews/r2');
    expect(list.first.finalScore, 0.9);
  });

  test('skips reviews deleted since the list was built', () async {
    await db.doc('users/a/forYou/current').set({
      'items': [
        {'reviewPath': 'users/b/reviews/gone', 'score': 0.9, 'reason': 'x'},
        {'reviewPath': 'users/b/reviews/r1', 'score': 0.7, 'reason': 'y'},
      ],
    });

    final list = (await ForYouService.watch('a', db: db).first)!;
    expect(list.map((s) => s.reviewWithDocId.docId), ['r1']);
  });
}
