# Testing Guide

## Quick Start

### Run Tests Only (Skip Analysis)
```bash
./test/run_tests_quick.sh
```

### Run Full Validation (Tests + Analysis)
```bash
./scripts/run_tests.sh
```

## Understanding Test Results

### Analysis Warnings vs Errors

The code analysis found **578 issues**, but most are **warnings**, not errors:

- **Info/Warnings** (non-blocking):
  - `avoid_print` - Print statements (acceptable for debugging)
  - `file_names` - File naming conventions (cosmetic)
  - `unused_import` - Unused imports (can be cleaned up)
  - `deprecated_member_use` - Using deprecated methods (should fix eventually)

- **Errors** (blocking):
  - Compilation errors
  - Type errors
  - Missing dependencies

### Current Status

✅ **Tests can run** - The analysis warnings don't prevent tests from executing
⚠️ **Many style warnings** - Should be addressed over time, but not blocking

## Running Tests

### Option 1: Quick Test (Recommended for Development)
```bash
flutter test
```

### Option 2: Full Validation Script
```bash
./scripts/run_tests.sh
```
This will:
1. Get dependencies
2. Run analysis (warnings OK, errors fail)
3. Run tests
4. Optionally generate coverage

### Option 3: Quick Test Script (Skip Analysis)
```bash
./test/run_tests_quick.sh
```

## Pre-Deployment Checklist

Before deploying, ensure:

1. ✅ **All tests pass:**
   ```bash
   flutter test
   ```

2. ⚠️ **No compilation errors** (warnings are OK):
   ```bash
   flutter analyze --no-fatal-infos --no-fatal-warnings
   ```

3. ✅ **Build succeeds:**
   ```bash
   flutter build web --release
   ```

## Addressing Warnings (Optional)

While warnings don't block deployment, you can address them over time:

### Most Common Warnings

1. **`avoid_print`** - Replace `print()` with proper logging:
   ```dart
   // Instead of: print('Debug info');
   // Use: debugPrint('Debug info'); // or a logging package
   ```

2. **`file_names`** - Rename files to snake_case:
   - `ProfileSignIn.dart` → `profile_sign_in.dart`
   - `MusicTaste.dart` → `music_taste.dart`

3. **`unused_import`** - Remove unused imports (IDE can do this)

4. **`deprecated_member_use`** - Update deprecated methods:
   - `withOpacity()` → `withValues()`

## Test Coverage

Generate coverage report:
```bash
flutter test --coverage
```

View HTML report (if `lcov` is installed):
```bash
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## CI/CD Integration

The `.github/workflows/tests.yml` file is configured to:
- Run on push/PR to main/develop
- Run analysis (warnings OK)
- Run tests
- Generate coverage

## Next Steps

1. **Run tests now:**
   ```bash
   flutter test
   ```

2. **Fix critical issues** (if any test failures)

3. **Address warnings gradually** (not blocking)

4. **Add more tests** as you develop features
