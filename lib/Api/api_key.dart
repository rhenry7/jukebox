// Safe stub — no secrets here. Safe to commit.
// Values: 1) --dart-define at build (CI), 2) .env at runtime via loadFromDotenv() (local dev).
// CI: pass secrets via --dart-define or leave empty for analyze/tests.
// Local: create .env and call ApiKeyOverrides.loadFromDotenv() after dotenv.load() (main.dart does this).

import 'package:flutter_dotenv/flutter_dotenv.dart';

// Compile-time only (String.fromEnvironment cannot be used at runtime).
const String apikey = String.fromEnvironment(
  'MUSICBRAINZ_API_KEY',
  defaultValue: '1347ba66e95e67a0764dcf76a3197fa0',
);
const String _clientId = String.fromEnvironment('CLIENT_ID', defaultValue: '');
const String _clientSecret =
    String.fromEnvironment('CLIENT_SECRET', defaultValue: '');
const String _newsAPIKey =
    String.fromEnvironment('NEWS_API_KEY', defaultValue: '');
const String _openAIKey = String.fromEnvironment('OPENAI_KEY', defaultValue: '');
const String _firebaseOptionsKey =
    String.fromEnvironment('FIREBASE_OPTIONS_KEY', defaultValue: '');
const String _firebaseAppId =
    String.fromEnvironment('FIREBASE_APP_ID', defaultValue: '');
const String _unsplashAccessKey =
    String.fromEnvironment('UNSPLASH_ACCESS_KEY', defaultValue: '');
const String _unsplashSecret =
    String.fromEnvironment('UNSPLASH_SECRET', defaultValue: '');

/// Runtime fallbacks (from .env). Populated by [ApiKeyOverrides.loadFromDotenv] after dotenv.load().
class _RuntimeKeys {
  String clientId = '';
  String clientSecret = '';
  String newsAPIKey = '';
  String openAIKey = '';
  String firebaseOptionsKey = '';
  String firebaseAppId = '';
  String unsplashAccessKey = '';
  String unsplashSecret = '';
}

final _runtime = _RuntimeKeys();

/// Call after dotenv.load() in main() so getters fall back to .env when dart-define values are empty.
void loadApiKeysFromDotenv() {
  _runtime.clientId = dotenv.env['SPOTIFY_CLIENT_ID'] ?? '';
  _runtime.clientSecret = dotenv.env['SPOTIFY_CLIENT_SECRET'] ?? '';
  _runtime.newsAPIKey = dotenv.env['NEWS_API_KEY'] ?? '';
  _runtime.openAIKey = dotenv.env['OPENAI_API_KEY'] ?? '';
  _runtime.firebaseOptionsKey = dotenv.env['FIREBASE_OPTIONS_KEY'] ?? '';
  _runtime.firebaseAppId = dotenv.env['FIREBASE_APP_ID'] ?? '';
  _runtime.unsplashAccessKey = dotenv.env['UNSPLASH_ACCESS_KEY'] ?? '';
  _runtime.unsplashSecret = dotenv.env['UNSPLASH_SECRET'] ?? '';
}

String get clientId => _clientId.isNotEmpty ? _clientId : _runtime.clientId;
String get clientSecret =>
    _clientSecret.isNotEmpty ? _clientSecret : _runtime.clientSecret;
String get newsAPIKey =>
    _newsAPIKey.isNotEmpty ? _newsAPIKey : _runtime.newsAPIKey;
String get openAIKey =>
    _openAIKey.isNotEmpty ? _openAIKey : _runtime.openAIKey;
String get firebaseOptionsKey => _firebaseOptionsKey.isNotEmpty
    ? _firebaseOptionsKey
    : _runtime.firebaseOptionsKey;
String get firebaseAppId =>
    _firebaseAppId.isNotEmpty ? _firebaseAppId : _runtime.firebaseAppId;
String get unsplashAccessKey => _unsplashAccessKey.isNotEmpty
    ? _unsplashAccessKey
    : _runtime.unsplashAccessKey;
String get unsplashSecret =>
    _unsplashSecret.isNotEmpty ? _unsplashSecret : _runtime.unsplashSecret;
