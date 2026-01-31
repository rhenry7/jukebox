# Step-by-Step Firebase Deployment Guide

Follow these steps in order to deploy your Flutter web app to Firebase Hosting.

## Step 1: Fix Firebase CLI Permissions (if needed)

If you get permission errors, run:
```bash
sudo chown -R $USER:$(id -gn $USER) /Users/ramonehenry/.config
```

## Step 2: Login to Firebase

Open your terminal and run:
```bash
firebase login
```

This will open a browser window. Sign in with your Google account that has access to the Firebase project.

## Step 3: Verify You're in the Right Directory

```bash
cd /Users/ramonehenry/Coding/Projects/FlutterProjects/flutter_test_project
```

## Step 4: Initialize Firebase Hosting (if not already done)

```bash
firebase init hosting
```

When prompted:
- **Select existing project**: Choose "juxeboxd" (or create a new one)
- **What do you want to use as your public directory?**: Type `build/web`
- **Configure as a single-page app?**: Type `Yes`
- **Set up automatic builds and deploys with GitHub?**: Type `No` (for now)
- **File build/web/index.html already exists. Overwrite?**: Type `No`

## Step 5: Build Your Flutter Web App

```bash
flutter build web --release
```

This creates optimized production files in the `build/web` directory.

**Wait for this to complete!** It may take a few minutes.

## Step 6: Verify Build Output

Check that `build/web` directory exists and has files:
```bash
ls -la build/web
```

You should see files like `index.html`, `main.dart.js`, etc.

## Step 7: Deploy to Firebase Hosting

```bash
firebase deploy --only hosting
```

This will:
- Upload your files to Firebase Hosting
- Show you a deployment URL when complete

## Step 8: Access Your Deployed App

After deployment completes, you'll see:
```
✔  Deploy complete!

Project Console: https://console.firebase.google.com/project/juxeboxd/overview
Hosting URL: https://juxeboxd.web.app
```

Visit the Hosting URL to see your live app!

---

## Troubleshooting

### Error: "Firebase CLI not found"
Install it:
```bash
npm install -g firebase-tools
```

### Error: "Not logged in"
Run:
```bash
firebase login
```

### Error: "No Firebase project found"
Run:
```bash
firebase init hosting
```
And select or create your project.

### Error: "build/web directory not found"
Make sure you ran:
```bash
flutter build web --release
```

### Error: "Permission denied"
Fix permissions:
```bash
sudo chown -R $USER:$(id -gn $USER) /Users/ramonehenry/.config
```

### Build fails
Try:
```bash
flutter clean
flutter pub get
flutter build web --release
```

---

## Quick Deploy Script

After the first setup, you can use the deploy script:
```bash
chmod +x deploy.sh
./deploy.sh
```

---

## Updating Your Deployment

To update your site after making changes:
1. Make your code changes
2. Run: `flutter build web --release`
3. Run: `firebase deploy --only hosting`

That's it! Your changes will be live in a few minutes.
