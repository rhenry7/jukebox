#!/bin/bash

# Test runner script for pre-deployment validation
# Usage: ./scripts/run_tests.sh

set -e  # Exit on error

echo "🧪 Running Flutter tests..."
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 0: Verify pinned Flutter version
echo "📌 Verifying Flutter SDK version..."
bash ./scripts/check_flutter_version.sh

# Step 1: Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Step 2: Analyze code (warnings are OK, errors are not)
echo ""
echo "🔍 Analyzing code..."
set +e
flutter analyze --no-fatal-infos --no-fatal-warnings
ANALYZE_EXIT_CODE=$?
set -e

if [ $ANALYZE_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ Code analysis passed (no errors)${NC}"
elif [ $ANALYZE_EXIT_CODE -eq 1 ]; then
    echo -e "${YELLOW}⚠️  Code analysis found warnings (non-blocking)${NC}"
    echo "   Note: Warnings are acceptable, but errors would block deployment"
else
    echo -e "${RED}❌ Code analysis failed! Please fix errors before deploying.${NC}"
    exit 1
fi

# Step 3: Run tests
echo ""
echo "🧪 Running tests..."
if flutter test; then
    echo -e "${GREEN}✅ All tests passed${NC}"
else
    echo -e "${RED}❌ Tests failed${NC}"
    exit 1
fi

# Step 4: Generate coverage report (optional)
echo ""
read -p "Generate coverage report? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "📊 Generating coverage report..."
    flutter test --coverage
    
    if command -v genhtml &> /dev/null; then
        genhtml coverage/lcov.info -o coverage/html
        echo -e "${GREEN}✅ Coverage report generated at coverage/html/index.html${NC}"
    else
        echo -e "${YELLOW}⚠️  genhtml not found. Install lcov to generate HTML coverage report.${NC}"
        echo "   Coverage data available at coverage/lcov.info"
    fi
fi

echo ""
echo -e "${GREEN}✅ Pre-deployment validation complete!${NC}"
