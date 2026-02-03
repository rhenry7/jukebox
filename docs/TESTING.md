# Testing Guide

This document describes the testing strategy and how to run tests before deployment.

## Overview

The project includes unit tests, widget tests, and integration tests to validate functionality before deployment to production.

## Test Structure

```
test/
├── models/              # Model tests (Review, etc.)
├── services/            # Service tests (ReviewLikesService, etc.)
├── utils/               # Utility function tests
├── integration/         # Integration tests for critical paths
├── widget_test.dart     # Basic widget tests
└── README.md           # Test documentation
```

## Running Tests

### Quick Test Run
```bash
flutter test
```

### Run with Coverage
```bash
flutter test --coverage
```

### Run Specific Test File
```bash
flutter test test/models/review_test.dart
```

### Run All Tests with Script
```bash
./scripts/run_tests.sh
```

## Pre-Deployment Checklist

Before deploying to production, ensure:

1. ✅ **All tests pass:**
   ```bash
   flutter test
   ```

2. ✅ **Code analysis passes:**
   ```bash
   flutter analyze
   ```

3. ✅ **No linter errors:**
   ```bash
   flutter analyze
   ```

4. ✅ **Test coverage is acceptable:**
   ```bash
   flutter test --coverage
   ```

## Test Coverage Goals

- **Models:** 90%+ coverage
- **Services:** 80%+ coverage
- **Critical paths:** 100% coverage
- **Overall:** 70%+ coverage

## Critical Test Scenarios

These scenarios must pass before deployment:

### Authentication
- [ ] User can sign up
- [ ] User can sign in
- [ ] User session persists
- [ ] User can sign out

### Reviews
- [ ] User can submit a review
- [ ] Review data is saved correctly
- [ ] Review validation works
- [ ] Reviews display correctly

### Likes
- [ ] User can like a review
- [ ] User can unlike a review
- [ ] Like count updates correctly
- [ ] Like status persists

### Community
- [ ] Community reviews load
- [ ] Collection group query works
- [ ] Permissions are correct
- [ ] Lazy loading works

### Preferences
- [ ] User can set preferences
- [ ] Preferences save correctly
- [ ] Preferences affect recommendations

## Continuous Integration

For CI/CD pipelines, use:

```yaml
# Example GitHub Actions
- name: Run tests
  run: flutter test

- name: Analyze code
  run: flutter analyze

- name: Check coverage
  run: flutter test --coverage
```

## Mocking Firebase

For tests requiring Firebase:

1. Use `fake_cloud_firestore` for Firestore
2. Use `firebase_auth_mocks` for Auth
3. Use Firebase Emulator Suite for integration tests

## Adding New Tests

When adding features:

1. Create corresponding test file
2. Test happy path
3. Test error cases
4. Test edge cases
5. Update this document

## Troubleshooting

### Tests fail with Firebase errors
- Use Firebase emulators or mocks
- Check Firebase initialization in tests

### Tests timeout
- Increase timeout: `test(..., timeout: Timeout(Duration(seconds: 30)))`
- Check for async operations not completing

### Coverage not generating
- Ensure `--coverage` flag is used
- Check that `lcov` is installed for HTML reports
