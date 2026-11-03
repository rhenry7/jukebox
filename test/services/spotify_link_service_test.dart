import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/services/spotify_link_service.dart';

SpotifyCandidate _c(String id, String name, List<String> artists,
        {bool album = false}) =>
    SpotifyCandidate(id: id, name: name, artists: artists, isAlbum: album);

void main() {
  group('SpotifyLinkService.pickBest', () {
    test('picks the exact track by the right artist', () {
      final best = SpotifyLinkService.pickBest('Rill Rill', 'Sleigh Bells', [
        _c('cover', 'Rill Rill', ['Some Cover Band']),
        _c('t1', 'Rill Rill', ['Sleigh Bells']),
        _c('a1', 'Treats', ['Sleigh Bells'], album: true),
      ]);
      expect(best?.id, 't1');
      expect(best?.url.toString(), 'https://open.spotify.com/track/t1');
    });

    test('links the album when the review is of an album', () {
      final best = SpotifyLinkService.pickBest('Treats', 'Sleigh Bells', [
        _c('t1', 'Rill Rill', ['Sleigh Bells']),
        _c('a1', 'Treats', ['Sleigh Bells'], album: true),
      ]);
      expect(best?.id, 'a1');
      expect(best?.url.toString(), 'https://open.spotify.com/album/a1');
    });

    test('prefers the track when a single shares the album name', () {
      final best = SpotifyLinkService.pickBest('Creep', 'Radiohead', [
        _c('a1', 'Creep', ['Radiohead'], album: true),
        _c('t1', 'Creep', ['Radiohead']),
      ]);
      expect(best?.id, 't1');
    });

    test('exact name beats a remaster or partial match', () {
      final best = SpotifyLinkService.pickBest('Creep', 'Radiohead', [
        _c('t2', 'Creep (Acoustic)', ['Radiohead']),
        _c('t3', 'Creep Again', ['Radiohead']),
      ]);
      // "(Acoustic)" is stripped, so it counts as the exact title.
      expect(best?.id, 't2');
    });

    test('matches one artist of a multi-artist review', () {
      final best = SpotifyLinkService.pickBest(
          'Time Moves Slow', 'BADBADNOTGOOD, Samuel T. Herring', [
        _c('t1', 'Time Moves Slow', ['BADBADNOTGOOD', 'Samuel T. Herring']),
      ]);
      expect(best?.id, 't1');
    });

    test('returns null when no artist matches', () {
      final best = SpotifyLinkService.pickBest('Creep', 'Radiohead', [
        _c('t1', 'Creep', ['TLC']),
      ]);
      expect(best, isNull);
    });
  });

  test('searchUrl encodes the title and artist', () {
    expect(
      SpotifyLinkService.searchUrl('Rill Rill', 'Sleigh Bells').toString(),
      'https://open.spotify.com/search/Rill%20Rill%20Sleigh%20Bells',
    );
  });
}
