import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/ui/widgets/review_card.dart';

void main() {
  group('reviewPreview', () {
    test('leaves short reviews untouched', () {
      expect(reviewPreview('Great record.'), 'Great record.');
    });

    test('cuts long reviews at a word boundary with an ellipsis', () {
      final text = List.filled(30, 'word').join(' '); // 149 chars
      final preview = reviewPreview(text, maxChars: 100);
      expect(preview.endsWith('word…'), isTrue);
    });

    test('drops trailing punctuation before the ellipsis', () {
      final text = '${'a' * 95}, then the rest of the review goes on';
      expect(reviewPreview(text, maxChars: 100), '${'a' * 95}…');
    });

    test('collapses line breaks', () {
      expect(reviewPreview('Line one.\n\nLine two.'), 'Line one. Line two.');
    });
  });
}
