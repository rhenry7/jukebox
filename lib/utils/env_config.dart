// Environment configuration using flutter_dotenv (runtime loading).
//
// API keys are loaded at runtime from:
// - **Mobile/Desktop**: .env file via flutter_dotenv (env_loader_io).
// - **Web**: .env bundled as asset (pubspec.yaml), loaded via rootBundle (env_loader_stub).
// - **CI/Deploy**: Pass keys via --dart-define at build time (no .env in repo).
//
// Expected .env keys (create .env in project root, do not commit):
//   Firebase:  FIREBASE_OPTIONS_KEY=...  FIREBASE_APP_ID=...
//   Spotify:   SPOTIFY_CLIENT_ID=...     SPOTIFY_CLIENT_SECRET=...
//   News:      NEWS_API_KEY=...
//   OpenAI:    OPENAI_API_KEY=...
//   Unsplash:  UNSPLASH_ACCESS_KEY=...   UNSPLASH_SECRET=...
// (api_key.dart also accepts CLIENT_ID/CLIENT_SECRET as aliases for Spotify.)
//
// Usage: call [loadEnvVariables] in main() before using API keys.
export 'env_loader.dart';
