# Fix: "Failed to list Firebase projects"

This error means Firebase CLI can't authenticate or access your Firebase account.

## Solution Steps

### Step 1: Login to Firebase

```bash
firebase login
```

This will:
- Open your browser
- Ask you to sign in with your Google account
- Grant permissions to Firebase CLI

**Make sure you use the same Google account that owns the "juxeboxd" Firebase project!**

### Step 2: Verify Login

After logging in, verify it worked:
```bash
firebase login:list
```

You should see your account email listed.

### Step 3: List Your Projects

```bash
firebase projects:list
```

This should show your "juxeboxd" project.

### Step 4: Set the Default Project

```bash
firebase use juxeboxd
```

### Step 5: Now Try Deploying

```bash
flutter build web --release
firebase deploy --only hosting
```

---

## Alternative: Login with Specific Account

If you have multiple Google accounts, you might need to logout and login with the correct one:

```bash
firebase logout
firebase login
```

Then select the correct Google account in the browser.

---

## If Still Not Working

1. **Check Firebase Console**: Go to https://console.firebase.google.com and make sure you can see the "juxeboxd" project
2. **Check Permissions**: Make sure your Google account has access to the project
3. **Try Reinstalling Firebase CLI**:
   ```bash
   npm uninstall -g firebase-tools
   npm install -g firebase-tools
   firebase login
   ```

---

## Common Issues

- **Wrong Google Account**: Make sure you're logged in with the account that owns the Firebase project
- **No Internet Connection**: Firebase CLI needs internet to authenticate
- **Firewall/Proxy**: Corporate networks sometimes block Firebase CLI
