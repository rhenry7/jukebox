import 'package:spotify/spotify.dart';

import '../Api/api_key.dart';

/// How long one Spotify connection is reused. Its app token lasts an hour
/// and can't be renewed (client-credentials tokens have no refresh token),
/// so a fresh connection takes over a little before that.
const Duration _reuseFor = Duration(minutes: 50);

SpotifyApi? _api;
DateTime _createdAt = DateTime.fromMillisecondsSinceEpoch(0);

/// The app's one Spotify connection. Creating a `SpotifyApi` requests a new
/// access token, so sharing one saves that round trip on every search (each
/// review card looks up its Spotify link). Replaced when its token is about
/// to expire, or straight away if getting the token failed.
SpotifyApi sharedSpotifyApi() {
  final current = _api;
  if (current != null && DateTime.now().difference(_createdAt) < _reuseFor) {
    return current;
  }
  final api = SpotifyApi(SpotifyApiCredentials(clientId, clientSecret));
  _api = api;
  _createdAt = DateTime.now();
  // A failed token request would fail every later call; start over instead.
  Future.value(api.client).then<void>((_) {}, onError: (Object _) {
    if (identical(_api, api)) _api = null;
  });
  return api;
}
