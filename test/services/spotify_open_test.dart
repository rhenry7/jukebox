import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/services/spotify_open/spotify_open.dart';

void main() {
  Uri? app(String url) => spotifyAppUri(Uri.parse(url));

  test('track, album and artist links map to spotify: links', () {
    expect(app('https://open.spotify.com/track/abc123'),
        Uri.parse('spotify:track:abc123'));
    expect(app('https://open.spotify.com/album/xyz'),
        Uri.parse('spotify:album:xyz'));
    expect(app('https://open.spotify.com/artist/42'),
        Uri.parse('spotify:artist:42'));
  });

  test('searches keep their query', () {
    expect(app('https://open.spotify.com/search/Frank%20Ocean/artists'),
        Uri.parse('spotify:search:Frank%20Ocean'));
  });

  test('anything else has no app link', () {
    expect(app('https://example.com/track/abc'), isNull);
    expect(app('https://open.spotify.com/'), isNull);
    expect(app('https://open.spotify.com/user/someone'), isNull);
  });
}
