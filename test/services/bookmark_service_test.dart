import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/services/bookmark_service.dart';

void main() {
  const user = 'me';
  const first = 'users/a/reviews/1';
  const second = 'users/b/reviews/2';

  test('toggle saves, then un-saves, a review', () async {
    final db = FakeFirebaseFirestore();
    final service = BookmarkService(db: db);
    final stream = service.bookmarksStream(user);

    await service.toggle(userId: user, reviewPath: first, isBookmarked: false);
    expect((await stream.first).map((b) => b.reviewPath), [first]);

    final doc = await db
        .doc('users/$user/bookmarks/${BookmarkService.docIdFor(first)}')
        .get();
    expect(doc.data()?['reviewPath'], first);

    await service.toggle(userId: user, reviewPath: first, isBookmarked: true);
    expect(await stream.first, isEmpty);
  });

  test('saving twice keeps one bookmark per review', () async {
    final service = BookmarkService(db: FakeFirebaseFirestore());
    for (final path in [first, second, first]) {
      await service.toggle(userId: user, reviewPath: path, isBookmarked: false);
    }
    final saved = await service.bookmarksStream(user).first;
    expect(saved.map((b) => b.reviewPath).toSet(), {first, second});
    expect(saved, hasLength(2));
  });
}
