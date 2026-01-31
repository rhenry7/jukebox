# Fix Authentication Error (401 Unauthenticated)

The debug log shows your Firebase tokens are expired and can't refresh. Here's how to fix it:

## Step 1: Clear Expired Tokens

```bash
# Logout to clear expired tokens
firebase logout

# Clear Firebase cache
rm -rf ~/.config/firebase
rm -rf ~/.cache/firebase
```

## Step 2: Login Fresh

```bash
# Login again (will open browser)
firebase login
```

**Important**: When the browser opens:
- Sign in with: ramoneh94@gmail.com (the account shown in the debug log)
- Grant all permissions when prompted
- Wait for "Success! Logged in as..." message

## Step 3: Verify Login

```bash
firebase login:list
```

You should see your email address.

## Step 4: Test Project Access

```bash
firebase projects:list
```

This should now work and show your "juxeboxd" project.

## Step 5: Set Project and Deploy

```bash
firebase use juxeboxd
flutter build web --release
firebase deploy --only hosting
```

---

## If Browser Doesn't Open

Use this command instead:
```bash
firebase login --no-localhost
```

This will give you a URL to visit manually in your browser.

---

## Alternative: Use Different Account

If ramoneh94@gmail.com doesn't have access to the project, you might need to:
1. Check Firebase Console: https://console.firebase.google.com
2. Make sure you're logged in with the account that owns "juxeboxd"
3. If different account, logout and login with the correct one
