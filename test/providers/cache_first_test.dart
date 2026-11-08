import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/providers/cache_first.dart';

const _hold = Duration(milliseconds: 60);

final _pageData = Provider.autoDispose<int>((ref) {
  ref.keepAliveFor(_hold);
  return 1;
});

Future<void> _wait(Duration d) => Future<void>.delayed(d);

void main() {
  group('keepAliveFor', () {
    test('keeps data read ahead of time (no listener) for a while', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(_pageData); // prefetch: nothing listens yet
      await _wait(const Duration(milliseconds: 10));
      expect(container.exists(_pageData), isTrue);

      await _wait(_hold * 2);
      expect(container.exists(_pageData), isFalse);
    });

    test('keeps data while used, and for a while after the page closes',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final page = container.listen(_pageData, (_, __) {});
      await _wait(_hold * 2); // open longer than the hold
      expect(container.exists(_pageData), isTrue);

      page.close();
      await _wait(const Duration(milliseconds: 10));
      expect(container.exists(_pageData), isTrue, reason: 'just closed');

      await _wait(_hold * 2);
      expect(container.exists(_pageData), isFalse);
    });
  });

  test('cacheThenServer ends with the server result', () async {
    final db = FakeFirebaseFirestore();
    await db.doc('users/a/reviews/r1').set({'title': 'x'});

    final results =
        await cacheThenServer(db.collection('users/a/reviews')).toList();

    expect(results, isNotEmpty);
    expect(results.last.docs.single.id, 'r1');
  });
}
