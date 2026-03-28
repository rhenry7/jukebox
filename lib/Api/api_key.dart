// Safe stub — no secrets here. Safe to commit.
//
// Keys are resolved only from compile-time environment values supplied with
// --dart-define. This avoids ever bundling a local .env file into the app.

// Compile-time only (String.fromEnvironment cannot be used at runtime).
const String apikey = String.fromEnvironment(
  'MUSICBRAINZ_API_KEY',
  defaultValue: '1347ba66e95e67a0764dcf76a3197fa0',
);
const String _clientId = String.fromEnvironment('CLIENT_ID', defaultValue: '');
const String _spotifyClientId =
    String.fromEnvironment('SPOTIFY_CLIENT_ID', defaultValue: '');
const String _clientSecret =
    String.fromEnvironment('CLIENT_SECRET', defaultValue: '');
const String _spotifyClientSecret =
    String.fromEnvironment('SPOTIFY_CLIENT_SECRET', defaultValue: '');
const String _newsAPIKey =
    String.fromEnvironment('NEWS_API_KEY', defaultValue: '');
const String _openAIKey =
    String.fromEnvironment('OPENAI_API_KEY', defaultValue: '');
const String _openAIKeyAlias =
    String.fromEnvironment('OPENAI_KEY', defaultValue: '');
const String _firebaseWebOptionsKey =
    String.fromEnvironment('FIREBASE_WEB_OPTIONS_KEY', defaultValue: '');
const String _firebaseWebAppId =
    String.fromEnvironment('FIREBASE_WEB_APP_ID', defaultValue: '');
const String _firebaseOptionsKey =
    String.fromEnvironment('FIREBASE_OPTIONS_KEY', defaultValue: '');
const String _firebaseAppId =
    String.fromEnvironment('FIREBASE_APP_ID', defaultValue: '');
const String _unsplashAccessKey =
    String.fromEnvironment('UNSPLASH_ACCESS_KEY', defaultValue: '');
const String _unsplashSecret =
    String.fromEnvironment('UNSPLASH_SECRET', defaultValue: '');
const String _defaultFirebaseWebOptionsKey =
    'AIzaSyCYfDpT_XEF_6bGHhSCt0qTglPAWl9BFsU';
const String _defaultFirebaseWebAppId =
    '1:412268788730:web:ba888c5cdf66b317fe8243';

String get clientId => _clientId.isNotEmpty ? _clientId : _spotifyClientId;
String get clientSecret =>
    _clientSecret.isNotEmpty ? _clientSecret : _spotifyClientSecret;
String get newsAPIKey => _newsAPIKey;
String get openAIKey => _openAIKey.isNotEmpty ? _openAIKey : _openAIKeyAlias;
String get firebaseOptionsKey => _firebaseOptionsKey;
String get firebaseAppId => _firebaseAppId;
String get firebaseWebOptionsKey {
  if (_firebaseWebOptionsKey.isNotEmpty) return _firebaseWebOptionsKey;
  if (_firebaseOptionsKey.isNotEmpty) return _firebaseOptionsKey;
  return _defaultFirebaseWebOptionsKey;
}

String get firebaseWebAppId {
  if (_firebaseWebAppId.isNotEmpty) return _firebaseWebAppId;
  if (_firebaseAppId.contains(':web:')) return _firebaseAppId;
  return _defaultFirebaseWebAppId;
}

String get unsplashAccessKey => _unsplashAccessKey;
String get unsplashSecret => _unsplashSecret;
