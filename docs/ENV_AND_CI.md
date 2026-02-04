# Environment Configuration & CI/CD

## Runtime loading (flutter_dotenv)

API keys are loaded at **runtime** from a `.env` file:

- **Mobile/Desktop**: `.env` is read from the project root via `flutter_dotenv` (no bundling).
- **Web (local)**: `.env` is listed in `pubspec.yaml` assets and loaded from the asset bundle at runtime.
- **CI/Deploy**: `.env` is not in the repo (gitignored). Keys are passed at **build time** via `--dart-define` from GitHub Secrets.

### Local setup

1. Create a `.env` file in the **project root** (same folder as `pubspec.yaml`).
2. Add at least Firebase, and any others your app uses:
   ```env
   FIREBASE_OPTIONS_KEY=your_firebase_web_api_key
   FIREBASE_APP_ID=1:412268788730:web:...
   SPOTIFY_CLIENT_ID=...
   SPOTIFY_CLIENT_SECRET=...
   NEWS_API_KEY=...
   OPENAI_API_KEY=...
   UNSPLASH_ACCESS_KEY=...
   UNSPLASH_SECRET=...
   ```
   (In code, `CLIENT_ID` / `CLIENT_SECRET` are aliases for Spotify.)
3. Do **not** commit `.env` (it is in `.gitignore`).

### Code entry point

- **`lib/utils/env_config.dart`** – Documents expected keys and re-exports `loadEnvVariables()`.
- **`lib/utils/env_loader.dart`** – Conditional export: web uses `env_loader_stub.dart` (rootBundle), others use `env_loader_io.dart` (flutter_dotenv).
- **`main.dart`** – Calls `await loadEnvVariables()` before Firebase init.

---

## CI/CD configuration

### Tests (`.github/workflows/tests.yml`)

- Runs on push/PR to `main` and `develop`.
- API keys come from **GitHub Secrets** via `--dart-define` (no `.env` in CI).
- Required secrets (for tests that need them): `FIREBASE_OPTIONS_KEY`, `FIREBASE_APP_ID`, and optionally `CLIENT_ID`, `CLIENT_SECRET`, etc.

### Deploy (`.github/workflows/deploy.yml`)

- Runs on push to `main` or via **workflow_dispatch** (manual).
- Builds Flutter web with `--dart-define` from GitHub Secrets, then deploys to Firebase Hosting.

**Required GitHub Secrets for deploy:**

| Secret                 | Description |
|------------------------|-------------|
| `FIREBASE_OPTIONS_KEY` | Firebase Web API key |
| `FIREBASE_APP_ID`      | Firebase Web app ID |
| `FIREBASE_TOKEN`       | From `firebase login:ci` (one-time) |
| `CLIENT_ID`            | Spotify client ID (or `SPOTIFY_CLIENT_ID`) |
| `CLIENT_SECRET`        | Spotify client secret (or `SPOTIFY_CLIENT_SECRET`) |
| `NEWS_API_KEY`         | News API key (optional) |
| `OPENAI_KEY`           | OpenAI API key (optional) |
| `UNSPLASH_ACCESS_KEY`  | Unsplash access key (optional) |
| `UNSPLASH_SECRET`      | Unsplash secret (optional) |

**Getting `FIREBASE_TOKEN`:**

```bash
firebase login:ci
```

Add the printed token as repository secret `FIREBASE_TOKEN` in GitHub: **Settings → Secrets and variables → Actions**.

---

## Local deploy (without CI)

Use the deploy script so keys from `.env` are passed at build time (deployed app does not load `.env` from the server):

```bash
./deploy.sh
```

This reads `.env`, runs `flutter build web --release` with `--dart-define` for each key, then runs `firebase deploy --only hosting`.
