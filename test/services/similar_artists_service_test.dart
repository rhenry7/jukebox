import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/services/similar_artists_service.dart';

void main() {
  group('normName', () {
    test('ignores case, accents, punctuation and & vs and', () {
      expect(SimilarArtistsService.normName('Björk'), 'bjork');
      expect(SimilarArtistsService.normName('Beyoncé'), 'beyonce');
      expect(
        SimilarArtistsService.normName('Simon & Garfunkel'),
        SimilarArtistsService.normName('Simon and Garfunkel'),
      );
      expect(SimilarArtistsService.normName('Anderson .Paak'), 'anderson paak');
    });
  });

  group('pickArtistMbid', () {
    test('needs a confident, exact-name match', () {
      final results = [
        {'id': 'band', 'score': 100, 'name': 'Masego Band'},
        {'id': 'yes', 'score': 98, 'name': 'Masego'},
      ];
      expect(SimilarArtistsService.pickArtistMbid(results, 'masego'), 'yes');
      expect(
        SimilarArtistsService.pickArtistMbid([
          {'id': 'x', 'score': 60, 'name': 'Masego'},
        ], 'Masego'),
        isNull,
      );
      expect(SimilarArtistsService.pickArtistMbid(const [], 'Masego'), isNull);
    });
  });

  test('parseSimilarArtists: best first, scaled to 1, junk ignored', () {
    final body = [
      [
        {'artist_mbid': 'b', 'name': 'B', 'score': 200},
        {'nope': true},
        {'artist_mbid': 'a', 'name': 'A', 'score': 800},
      ],
    ];
    final out = SimilarArtistsService.parseSimilarArtists(body);
    expect([for (final s in out) s.name], ['A', 'B']);
    expect(out.first.score, 1);
    expect(out.last.score, 0.25);
    expect(SimilarArtistsService.parseSimilarArtists({'error': 1}), isEmpty);
  });

  test('parseCachedSimilar reads the Cloud Functions cache doc', () {
    final out = SimilarArtistsService.parseCachedSimilar({
      'similar': [
        {'mbid': 'p', 'name': 'Anderson .Paak', 'score': 1},
        {'mbid': 'bad'},
      ],
    });
    expect(out, hasLength(1));
    expect(out.single.name, 'Anderson .Paak');
    expect(SimilarArtistsService.parseCachedSimilar(null), isEmpty);
  });
}
