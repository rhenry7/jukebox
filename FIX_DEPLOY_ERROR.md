# Fix: "resolving hosting target of a site with no site name"

## Solution

The error occurs because Firebase hosting needs to be properly initialized. Follow these steps:

### Step 1: Initialize Firebase Hosting

Run this command in your terminal:

```bash
firebase init hosting
```

When prompted:
1. **Select an option**: Choose "Use an existing project"
2. **Select a default Firebase project**: Choose "juxeboxd"
3. **What do you want to use as your public directory?**: Type `build/web`
4. **Configure as a single-page app (rewrite all urls to /index.html)?**: Type `Yes`
5. **Set up automatic builds and deploys with GitHub?**: Type `No`
6. **File build/web/index.html already exists. Overwrite?**: Type `No`

### Step 2: Verify Configuration

After initialization, check that `.firebaserc` exists:
```bash
cat .firebaserc
```

It should show:
```json
{
  "projects": {
    "default": "juxeboxd"
  }
}
```

### Step 3: Build Your App

```bash
flutter build web --release
```

### Step 4: Deploy

```bash
firebase deploy --only hosting
```

---

## Alternative: Manual Fix

If `firebase init hosting` doesn't work, I've already created the `.firebaserc` file for you. Just make sure:

1. The `.firebaserc` file exists with your project ID
2. Your `firebase.json` has the hosting configuration
3. You've built the app: `flutter build web --release`
4. Then deploy: `firebase deploy --only hosting`

---

## If Still Not Working

Try this command to see your Firebase projects:
```bash
firebase projects:list
```

Then set the default project:
```bash
firebase use juxeboxd
```

Then try deploying again:
```bash
firebase deploy --only hosting
```
