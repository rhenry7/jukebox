import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/ui/widgets/genre_pills.dart';

void main() {
  test('rankTags orders by use, ignoring case, keeping first spelling', () {
    expect(
      rankTags([
        ['Rock', 'indie'],
        ['rock / Shoegaze'],
        ['Indie', 'ROCK'],
        null,
      ]),
      ['Rock', 'indie', 'Shoegaze'],
    );
  });

  test('rankTags breaks ties by first appearance', () {
    expect(rankTags([['b', 'a'], ['a', 'b']]), ['b', 'a']);
  });
}
