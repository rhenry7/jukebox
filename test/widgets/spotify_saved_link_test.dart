import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/ui/widgets/spotify_play_button.dart';

void main() {
  group('savedSpotifyLink', () {
    test('uses a saved Spotify song or album link', () {
      expect(savedSpotifyLink('https://open.spotify.com/track/abc123'),
          Uri.parse('https://open.spotify.com/track/abc123'));
      expect(savedSpotifyLink('https://open.spotify.com/album/xyz'),
          Uri.parse('https://open.spotify.com/album/xyz'));
    });

    test('ignores missing links and anything not on open.spotify.com', () {
      for (final raw in [
        null,
        '',
        'not a link',
        'http://open.spotify.com/track/abc', // not https
        'https://evil.example.com/track/abc',
        'https://open.spotify.com.evil.example/track/abc',
        'javascript:alert(1)',
      ]) {
        expect(savedSpotifyLink(raw), isNull, reason: '$raw');
      }
    });
  });

  test('a review keeps its Spotify link through Firestore and JSON', () {
    final data = {
      'displayName': 'u',
      'userId': 'u1',
      'artist': 'A',
      'title': 'T',
      'review': 'r',
      'score': 4,
      'likes': 0,
      'replies': 0,
      'reposts': 0,
      'spotifyUrl': 'https://open.spotify.com/track/abc123',
    };
    final review = Review.fromFirestore(data);
    expect(review.spotifyUrl, 'https://open.spotify.com/track/abc123');
    expect(Review.fromJson(review.toJson()).spotifyUrl, review.spotifyUrl);

    final older = Review.fromFirestore({...data}..remove('spotifyUrl'));
    expect(older.spotifyUrl, isNull);
    expect(older.toJson().containsKey('spotifyUrl'), isFalse);
  });
}
