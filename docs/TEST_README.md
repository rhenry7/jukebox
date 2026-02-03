# Test Suite

This directory contains unit tests, widget tests, and integration tests for the Flutter Test Project.

## Running Tests

### Run all tests:
```bash
flutter test
```

### Run specific test file:
```bash
flutter test test/models/review_test.dart
```

### Run tests with coverage:
```bash
flutter test --coverage
```

### Generate coverage report:
```bash
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## Test Structure

- `models/` - Tests for data models (Review, etc.)
- `services/` - Tests for service classes (ReviewLikesService, MusicProfileService, etc.)
- `utils/` - Tests for utility functions
- `integration/` - Integration tests for critical user paths
- `helpers/` - Test helper utilities (Firebase initialization, etc.)
- `widget_test.dart` - Basic widget tests

## Current Test Status

### ✅ Working Tests
- **Review Model Tests** - All tests pass (serialization, validation)
- **ReviewLikesService Static Methods** - Path formatting tests pass
- **Helper Functions** - Utility function tests pass

### ⚠️ Skipped Tests (Require Firebase)
- **ReviewLikesService Firestore Operations** - Require Firebase Emulator or refactoring
- **MusicProfileService Methods** - Service constructor requires Firebase initialization

### Why Some Tests Are Skipped

Some services use `FirebaseFirestore.instance` directly in their constructors, which requires Firebase to be initialized. To enable these tests:

1. **Option 1: Use Firebase Emulator Suite** (Recommended for integration tests)
   ```bash
   firebase emulators:start
   ```

2. **Option 2: Refactor Services** (Better for unit tests)
   - Inject Firestore as a dependency instead of using `FirebaseFirestore.instance`
   - This allows using `FakeFirebaseFirestore` in tests

3. **Option 3: Initialize Firebase in Tests**
   - Use `test/helpers/firebase_test_helper.dart`
   - Requires proper Firebase configuration

## Pre-Deployment Checklist

Before deploying to production, ensure all tests pass:

1. **Run all tests:**
   ```bash
   flutter test
   ```

2. **Check test coverage:**
   ```bash
   flutter test --coverage
   ```

3. **Validate critical paths:**
   - User signup/signin
   - Review submission
   - Like functionality
   - Community reviews loading
   - Music preferences

4. **Check for linter errors:**
   ```bash
   flutter analyze --no-fatal-infos --no-fatal-warnings
   ```

## Adding New Tests

When adding new features, create corresponding tests:

1. **For models:** Create test in `test/models/`
2. **For services:** Create test in `test/services/`
3. **For widgets:** Add to `test/widget_test.dart` or create new file
4. **For critical paths:** Add to `test/integration/`

## Mocking Firebase

For tests that require Firebase:

1. **Use `fake_cloud_firestore`** for Firestore mocking (requires service refactoring)
2. **Use `firebase_auth_mocks`** for Auth mocking
3. **Use Firebase Emulator Suite** for integration tests

## Continuous Integration

Consider setting up CI/CD to run tests automatically:
- GitHub Actions (`.github/workflows/tests.yml` is ready)
- GitLab CI
- CircleCI

## Troubleshooting

### Tests fail with Firebase errors
- Use Firebase emulators or mocks
- Check Firebase initialization in tests
- Consider refactoring services to accept dependencies

### Tests timeout
- Increase timeout: `test(..., timeout: Timeout(Duration(seconds: 30)))`
- Check for async operations not completing

### Coverage not generating
- Ensure `--coverage` flag is used
- Check that `lcov` is installed for HTML reports
