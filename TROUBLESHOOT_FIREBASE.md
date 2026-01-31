# Troubleshooting Firebase Authentication

## Current Issue: "Failed to list Firebase projects"

This is an authentication/network issue. Try these solutions in order:

## Solution 1: Re-authenticate

```bash
# Logout completely
firebase logout

# Login again (this will open browser)
firebase login

# Verify login
firebase login:list
```

## Solution 2: Check Network/Firewall

Firebase CLI needs internet access. If you're on a corporate network or VPN, try:
- Disconnecting VPN
- Using a different network
- Checking if firewall is blocking Firebase

## Solution 3: Clear Firebase Cache

```bash
# Clear Firebase CLI cache
rm -rf ~/.config/firebase
rm -rf ~/.cache/firebase

# Login again
firebase login
```

## Solution 4: Check Node.js Version

Firebase CLI requires Node.js. Check your version:
```bash
node --version
```

Should be Node.js 14+ or 16+. If outdated:
```bash
# Update Node.js (using Homebrew on Mac)
brew upgrade node
```

## Solution 5: Reinstall Firebase CLI

```bash
# Uninstall
npm uninstall -g firebase-tools

# Reinstall
npm install -g firebase-tools

# Login
firebase login
```

## Solution 6: Use Service Account (Advanced)

If nothing works, you can use a service account key:

1. Go to Firebase Console → Project Settings → Service Accounts
2. Generate a new private key
3. Set environment variable:
   ```bash
   export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"
   ```

## Solution 7: Manual Deployment via Firebase Console

If CLI continues to fail, you can deploy manually:

1. Build your app:
   ```bash
   flutter build web --release
   ```

2. Go to Firebase Console → Hosting
3. Click "Get Started" or "Add another site"
4. Upload the `build/web` folder contents via the console

## Check Debug Log

The error message says to check `firebase-debug.log`. Look at it:
```bash
cat firebase-debug.log
```

This will show the exact error.

---

## Quick Test

Try this simple command to test connectivity:
```bash
firebase --version
```

If this works but `firebase login` doesn't, it's an authentication issue.

---

## Most Common Fix

Usually this works:
```bash
firebase logout
firebase login --no-localhost
```

The `--no-localhost` flag will give you a URL to visit manually if browser doesn't open.
