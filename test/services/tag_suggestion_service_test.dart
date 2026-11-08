import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/providers/reviews_provider.dart';
import 'package:flutter_test_project/providers/tag_suggestions_provider.dart';
import 'package:flutter_test_project/services/tag_suggestion_service.dart';

ReviewWithDocId _r(String title, String artist, List<String> genres) =>
    ReviewWithDocId(
      docId: title,
      review: Review(
        displayName: 'u',
        userId: 'u',
        artist: artist,
        review: 'x',
        score: 4,
        likes: 0,
        replies: 0,
        reposts: 0,
        title: title,
        genres: genres,
      ),
    );

void main() {
  group('isUsefulTag', () {
    test('keeps genres, niche ones and decades', () {
      for (final t in ['darkwave', 'synthpop', 'r&b', '80s', '1980s', 'soul']) {
        expect(TagSuggestionService.isUsefulTag(t), isTrue, reason: t);
      }
    });
    test('drops personal, bookkeeping and junk tags', () {
      for (final t in [
        'meme',
        'seen live',
        'favorites',
        'my favourite songs',
        'owned on vinyl',
        '2019',
        'x',
      ]) {
        expect(TagSuggestionService.isUsefulTag(t), isFalse, reason: t);
      }
    });
  });

  test('tagsFromResult: most voted first, junk removed', () {
    final tags = TagSuggestionService.tagsFromResult({
      'tags': [
        {'name': 'Meme', 'count': 9},
        {'name': 'Darkwave', 'count': 3},
        {'name': 'synthpop', 'count': 5},
      ],
    });
    expect(tags, ['synthpop', 'darkwave']);
  });

  test('mergeSuggestions: in source order, once each, skipping excluded', () {
    expect(
      mergeSuggestions(
        [
          ['R&B', 'soul'],
          ['rnb', 'funk', 'soul', 'disco'],
        ],
        exclude: {'funk'},
        limit: 3,
      ),
      ['R&B', 'soul', 'disco'],
    );
  });

  test("communityTagsFor: other reviewers' tags for the same song", () {
    final reviews = [
      _r('Perfect Girl', 'Mareux', ['darkwave', 'synth']),
      _r('perfect girl ', 'Mareux, Someone', ['darkwave']),
      _r('Perfect Girl', 'Other Artist', ['pop']),
      _r('Another Song', 'Mareux', ['rock']),
    ];
    expect(
      communityTagsFor((title: 'Perfect Girl', artist: 'Mareux'), reviews),
      ['darkwave', 'synth'],
    );
  });
}
