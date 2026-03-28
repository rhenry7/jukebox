// Environment configuration using compile-time defines only.
//
// API keys are injected at build/run time with --dart-define.
// A local .env file can still exist as developer input, but it must be passed
// into Flutter at build time and is never bundled as an app asset.
//
// Expected keys (set via --dart-define, or read from a local .env helper by
// scripts that expand into --dart-define values):
//   Firebase:  FIREBASE_OPTIONS_KEY=...  FIREBASE_APP_ID=...
//   Spotify:   SPOTIFY_CLIENT_ID=...     SPOTIFY_CLIENT_SECRET=...
//   News:      NEWS_API_KEY=...
//   OpenAI:    OPENAI_API_KEY=...
//   Unsplash:  UNSPLASH_ACCESS_KEY=...   UNSPLASH_SECRET=...
// (api_key.dart also accepts CLIENT_ID/CLIENT_SECRET as aliases for Spotify.)
//
// Usage: call [loadEnvVariables] in main() before using API keys. It is a
// startup no-op kept for API compatibility.
export 'env_loader.dart';
