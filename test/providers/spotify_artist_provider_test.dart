import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/providers/spotify_artist_provider.dart';
import 'package:spotify/spotify.dart';

({String artist, DateTime? date}) _r(String artist, [int day = 1]) =>
    (artist: artist, date: DateTime(2026, 1, day));

void main() {
  group('splitArtists', () {
    test('splits Spotify-joined artists and feat. credits', () {
      expect(splitArtists('Kendrick Lamar, SZA'), ['Kendrick Lamar', 'SZA']);
      expect(splitArtists('Drake feat. Rihanna'), ['Drake', 'Rihanna']);
    });

    test('keeps "&" names and comma names whole', () {
      expect(splitArtists('Simon & Garfunkel'), ['Simon & Garfunkel']);
      expect(splitArtists('Tyler, The Creator, Kali Uchis'),
          ['Tyler, The Creator', 'Kali Uchis']);
      expect(splitArtists('Earth, Wind & Fire'), ['Earth, Wind & Fire']);
    });
  });

  test('normalizeArtist ignores case, accents and punctuation', () {
    expect(normalizeArtist('Beyoncé'), normalizeArtist('beyonce'));
    expect(normalizeArtist('Tyler, The Creator'),
        normalizeArtist('tyler the creator'));
  });

  group('rankArtists', () {
    test('credits every artist on a review', () {
      final ranked = rankArtists([
        _r('Kendrick Lamar'),
        _r('Kendrick Lamar, SZA'),
        _r('SZA'),
        _r('Frank Ocean'),
      ]);
      // Both on 2 with the same date, so alphabetical decides.
      expect(ranked.take(2).toList(), [
        (name: 'Kendrick Lamar', count: 2),
        (name: 'SZA', count: 2),
      ]);
      expect(ranked.last.name, 'Frank Ocean');
    });

    test('merges spellings and shows the most recent one', () {
      final ranked = rankArtists([_r('Beyonce', 1), _r('Beyoncé', 5)]);
      expect(ranked, [(name: 'Beyoncé', count: 2)]);
    });

    test('ties go to the most recently reviewed artist', () {
      final ranked = rankArtists([_r('Older', 1), _r('Newer', 9)]);
      expect([for (final t in ranked) t.name], ['Newer', 'Older']);
    });
  });

  test('pickArtistMatch only accepts a matching name', () {
    final wrong = Artist.fromJson({'name': 'Drake Bell'});
    final right = Artist.fromJson({'name': 'Drake'});
    expect(pickArtistMatch('drake', [wrong, right]), same(right));
    expect(pickArtistMatch('Drake', [wrong]), isNull);
  });
}
