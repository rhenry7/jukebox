# Environment Configuration & CI/CD

## Build-time secrets only

API keys are loaded only from compile-time environment values supplied with
`--dart-define`.

- **Mobile/Desktop**: pass keys with `--dart-define` when you run or build the app.
- **Web**: pass keys with `--dart-define` when you run or build the app.
- **CI/Deploy**: pass keys with `--dart-define` from GitHub Secrets.

A local `.env` file can still exist for developer convenience, but it is never
bundled into the app and is never read at runtime by Flutter code.

### Local setup (APIs accessible when not deployed)

1. Create a `.env` file in the **project root** (same folder as `pubspec.yaml`) if you want a single local source of truth for secrets.
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
3. Run locally by passing the values into Flutter at startup/build time. Examples:
   ```bash
   ./scripts/flutter_with_env.sh run -d chrome
   ./scripts/flutter_with_env.sh ios
   ./scripts/flutter_with_env.sh build web --release
   flutter run -d chrome --dart-define-from-file=.env
   flutter run -d <ios-device-id> --dart-define-from-file=.env
   ```
4. Do **not** commit `.env` (it is in `.gitignore`).

### Code entry point

- **`lib/utils/env_config.dart`** – Documents expected compile-time keys and re-exports `loadEnvVariables()`.
- **`lib/utils/env_loader.dart`** – Startup no-op kept so app initialization stays stable while secrets come only from compile-time defines.
- **`main.dart`** – Calls `await loadEnvVariables()` before Firebase init, then reads keys from `String.fromEnvironment`.

---

## CI/CD configuration

### Flutter version pinning

- The repo pins Flutter with `.flutter-version`.
- Optional local FVM support is configured in `.fvmrc`.
- Local validation scripts call `scripts/check_flutter_version.sh` before running tests or deploys.
- CI reads the same pinned version file before setting up Flutter, so local and GitHub Actions stay aligned.

### Local SDK setup

If you use FVM:

```bash
fvm use
fvm flutter pub get
```

If you do not use FVM, install/switch your local Flutter SDK to the exact version in `.flutter-version`.

### Tests (`.github/workflows/tests.yml`)

- Runs on push/PR to `main` and `develop`.
- Installs the exact Flutter version from `.flutter-version`.
- API keys come from **GitHub Secrets** via `--dart-define` (no `.env` in CI).
- Required secrets (for tests that need them): `FIREBASE_OPTIONS_KEY`, `FIREBASE_APP_ID`, and optionally `CLIENT_ID`, `CLIENT_SECRET`, etc.

### Deploy (`.github/workflows/deploy.yml`)

- Runs on push to `main` or via **workflow_dispatch** (manual).
- Installs the exact Flutter version from `.flutter-version`.
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
| `OPENAI_API_KEY`        | OpenAI API key (optional) |
| `UNSPLASH_ACCESS_KEY`  | Unsplash access key (optional) |
| `UNSPLASH_SECRET`      | Unsplash secret (optional) |

**Getting `FIREBASE_TOKEN`:**

```bash
firebase login:ci
```

Add the printed token as repository secret `FIREBASE_TOKEN` in GitHub: **Settings → Secrets and variables → Actions**.

---

## Local deploy (without CI)

Use the deploy script so keys from `.env` are passed at build time:

```bash
./deploy.sh
```

This first verifies that your active Flutter SDK matches `.flutter-version`, then reads `.env`, runs `flutter build web --release` with `--dart-define` for each key, and finally runs `firebase deploy --only hosting`. The `.env` file stays local and is not bundled into the app.
