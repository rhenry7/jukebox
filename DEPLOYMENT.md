# Flutter Web Deployment Guide

## Option 1: Firebase Hosting (Recommended - You're already using Firebase!)

### Prerequisites
1. Install Firebase CLI (if not already installed):
   ```bash
   npm install -g firebase-tools
   ```

2. Login to Firebase:
   ```bash
   firebase login
   ```

### Steps

1. **Build your Flutter web app:**
   ```bash
   flutter build web --release
   ```
   This creates optimized production files in the `build/web` directory.

2. **Update firebase.json for hosting:**
   Your `firebase.json` should include a hosting configuration. If it doesn't, add:
   ```json
   {
     "hosting": {
       "public": "build/web",
       "ignore": [
         "firebase.json",
         "**/.*",
         "**/node_modules/**"
       ],
       "rewrites": [
         {
           "source": "**",
           "destination": "/index.html"
         }
       ]
     }
   }
   ```

3. **Initialize Firebase Hosting (if not already done):**
   ```bash
   firebase init hosting
   ```
   - Select your Firebase project (juxeboxd)
   - Set public directory to: `build/web`
   - Configure as single-page app: Yes
   - Set up automatic builds: No (for now)

4. **Deploy:**
   ```bash
   firebase deploy --only hosting
   ```

5. **Your app will be live at:**
   `https://juxeboxd.web.app` or `https://juxeboxd.firebaseapp.com`

---

## Option 2: Netlify

1. **Build your app:**
   ```bash
   flutter build web --release
   ```

2. **Install Netlify CLI:**
   ```bash
   npm install -g netlify-cli
   ```

3. **Deploy:**
   ```bash
   netlify deploy --prod --dir=build/web
   ```

---

## Option 3: Vercel

1. **Build your app:**
   ```bash
   flutter build web --release
   ```

2. **Install Vercel CLI:**
   ```bash
   npm install -g vercel
   ```

3. **Deploy:**
   ```bash
   vercel --prod build/web
   ```

---

## Option 4: GitHub Pages

1. **Build your app:**
   ```bash
   flutter build web --release --base-href "/your-repo-name/"
   ```

2. **Copy build/web contents to gh-pages branch and push**

---

## Quick Firebase Deployment Script

Create a `deploy.sh` script:

```bash
#!/bin/bash
echo "Building Flutter web app..."
flutter build web --release

echo "Deploying to Firebase Hosting..."
firebase deploy --only hosting

echo "Deployment complete!"
```

Make it executable:
```bash
chmod +x deploy.sh
```

Then run:
```bash
./deploy.sh
```

---

## Important Notes

1. **Environment Variables**: Make sure your API keys are properly configured for production
2. **CORS**: Ensure your backend APIs allow requests from your deployed domain
3. **Firebase Rules**: Update Firestore security rules if needed for production
4. **Performance**: The `--release` flag optimizes the build for production

---

## Troubleshooting

- If you get CORS errors, check your API endpoints allow your domain
- If Firebase deploy fails, make sure you're logged in: `firebase login`
- If build fails, try: `flutter clean && flutter pub get && flutter build web --release`
