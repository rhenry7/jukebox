import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'spotify_open_platform.dart'
    if (dart.library.js_interop) 'spotify_open_platform_web.dart' as platform;

/// Opens an `open.spotify.com` link. Returns whether something opened.
///
/// In the app installed to an iPhone home screen, an https link opens in an
/// in-app browser sheet that hands off to Spotify and is left behind as a
/// blank page the user comes back to. There it opens the `spotify:` app link
/// instead, and falls back to the web link only if Spotify didn't open.
Future<bool> openOnSpotify(Uri webUrl) async {
  final appUri = spotifyAppUri(webUrl);
  if (appUri != null &&
      platform.isIosHomeScreenApp() &&
      await platform.tryOpenApp(appUri)) {
    return true;
  }
  return launchUrl(webUrl, mode: LaunchMode.externalApplication);
}

/// The `spotify:` app link for an `open.spotify.com` link, or null.
@visibleForTesting
Uri? spotifyAppUri(Uri webUrl) {
  if (webUrl.host != 'open.spotify.com') return null;
  final parts = webUrl.pathSegments.where((p) => p.isNotEmpty).toList();
  if (parts.length < 2) return null;
  const types = {'track', 'album', 'artist', 'playlist', 'show', 'episode'};
  if (types.contains(parts[0]))
    return Uri.parse('spotify:${parts[0]}:${parts[1]}');
  if (parts[0] == 'search') {
    return Uri.parse('spotify:search:${Uri.encodeComponent(parts[1])}');
  }
  return null;
}
