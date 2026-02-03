#!/bin/bash

echo "🚀 Starting deployment process..."
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Run tests
echo "🧪 Running tests..."
if flutter test; then
    echo -e "${GREEN}✅ All tests passed${NC}"
else
    echo -e "${RED}❌ Tests failed! Please fix tests before deploying.${NC}"
    exit 1
fi

echo ""

# Step 2: Analyze code (warnings are OK, errors are not)
echo "🔍 Analyzing code..."
flutter analyze --no-fatal-infos --no-fatal-warnings
ANALYZE_EXIT_CODE=$?

if [ $ANALYZE_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ Code analysis passed (no errors)${NC}"
elif [ $ANALYZE_EXIT_CODE -eq 1 ]; then
    echo -e "${YELLOW}⚠️  Code analysis found warnings (non-blocking)${NC}"
    echo "   Note: Warnings are acceptable, but errors would block deployment"
else
    echo -e "${RED}❌ Code analysis failed! Please fix errors before deploying.${NC}"
    exit 1
fi

echo ""

# Step 3: Build Flutter web app
echo "📦 Building Flutter web app (release mode)..."
flutter build web --release

if [ $? -ne 0 ]; then
    echo "❌ Build failed! Please check the errors above."
    exit 1
fi

echo ""
echo "✅ Build successful!"
echo ""

# Deploy to Firebase Hosting
echo "🔥 Deploying to Firebase Hosting..."
firebase deploy --only hosting

if [ $? -ne 0 ]; then
    echo "❌ Deployment failed! Make sure you're logged in: firebase login"
    exit 1
fi

echo ""
echo "🎉 Deployment complete!"
echo "Your app should be live at: https://juxeboxd.web.app"