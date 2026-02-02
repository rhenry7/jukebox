#!/bin/bash

echo "🚀 Starting deployment process..."
echo ""

# Build Flutter web app
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