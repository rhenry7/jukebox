/// Browser hooks for [openOnSpotify]. This stub is used off the web, where
/// Spotify links already open the app.
library;

/// Whether this is the app installed to an iPhone/iPad home screen.
bool isIosHomeScreenApp() => false;

/// Tries to open [appUri] in the Spotify app; returns whether it opened.
Future<bool> tryOpenApp(Uri appUri) async => false;
