import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/utils/helpers.dart';

void main() {
  group('Helper Functions Tests', () {
    test('formatRelativeTime formats recent time correctly', () {
      final now = DateTime.now();
      final oneMinuteAgo = now.subtract(const Duration(minutes: 1));
      final fiveMinutesAgo = now.subtract(const Duration(minutes: 5));
      final oneHourAgo = now.subtract(const Duration(hours: 1));
      final oneDayAgo = now.subtract(const Duration(days: 1));

      final oneMin = formatRelativeTime(oneMinuteAgo);
      final fiveMin = formatRelativeTime(fiveMinutesAgo);
      final oneHr = formatRelativeTime(oneHourAgo);
      final oneDay = formatRelativeTime(oneDayAgo);

      // Check that relative time strings are generated
      expect(oneMin, isNotEmpty);
      expect(fiveMin, isNotEmpty);
      expect(oneHr, isNotEmpty);
      expect(oneDay, isNotEmpty);
    });

    test('formatRelativeTime handles null gracefully', () {
      // Should not throw
      expect(() => formatRelativeTime(null), returnsNormally);
    });
  });
}
