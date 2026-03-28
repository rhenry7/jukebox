# Juxeboxd

Flutter mobile project for users to write reviews for their favorite or not-so-favorite music albums or songs. Share reviews with friends. Create playlists and discuss whats new in the music world. 

## Flutter Version

This repo pins Flutter in `.flutter-version`. If you use FVM, run `fvm use` in the project root. Local test and deploy scripts verify that your active SDK matches the pinned version before they run.

## Local Web Dev

To run the app in Chrome with your local `.env`, use:

```bash
./scripts/flutter_with_env.sh run -d chrome
```

To run on an iPhone or simulator with the same local keys, use:

```bash
./scripts/flutter_with_env.sh ios
```

That keeps secrets out of bundled assets while still passing them into Flutter as compile-time defines.
