# Updating Your Deployed App

## Important: Code Changes Don't Auto-Update

When you make code changes locally, they **do NOT** automatically appear on your deployed site. You must rebuild and redeploy.

## Workflow for Updates

### Step 1: Make Your Code Changes
Edit your Flutter code as usual in your IDE.

### Step 2: Test Locally (Optional but Recommended)
```bash
flutter run -d chrome
```
Test your changes locally before deploying.

### Step 3: Rebuild for Production
```bash
flutter build web --release
```
This creates a new optimized build in `build/web`.

### Step 4: Deploy to Firebase
```bash
firebase deploy --only hosting
```

### Step 5: Wait for Deployment
Deployment usually takes 1-3 minutes. You'll see:
```
✔  Deploy complete!
Hosting URL: https://juxeboxd.web.app
```

### Step 6: Clear Browser Cache (Sometimes Needed)
After deployment, you might need to:
- Hard refresh: `Cmd+Shift+R` (Mac) or `Ctrl+Shift+R` (Windows)
- Or clear browser cache to see the new version

---

## Quick Update Script

I've created `deploy.sh` that does steps 3-4 automatically:

```bash
./deploy.sh
```

This will:
1. Build your app (`flutter build web --release`)
2. Deploy to Firebase (`firebase deploy --only hosting`)

---

## Development vs Production

### Local Development (Hot Reload)
- `flutter run -d chrome` - Fast development with hot reload
- Changes appear instantly
- **NOT deployed** - only visible on your local machine

### Production Deployment
- `flutter build web --release` + `firebase deploy`
- Changes go live on the internet
- Takes a few minutes
- Visible to everyone at your URL

---

## Best Practices

1. **Test Locally First**: Always test changes with `flutter run` before deploying
2. **Deploy After Features**: Deploy when you've completed a feature or fix
3. **Version Control**: Commit your changes to git before deploying
4. **Check After Deploy**: Visit your site after deployment to verify changes

---

## Automatic Deployments (Advanced)

If you want automatic deployments, you can set up:
- **GitHub Actions**: Auto-deploy on git push
- **Firebase CI/CD**: Connect your repo for automatic builds

But for now, manual deployment is fine and gives you control.

---

## Summary

**To update your deployed app:**
1. Make code changes
2. Run: `flutter build web --release`
3. Run: `firebase deploy --only hosting`
4. Done! Your changes are live in ~2-3 minutes

---

## Troubleshooting

**Changes not showing?**
- Wait 2-3 minutes for deployment to complete
- Hard refresh browser: `Cmd+Shift+R`
- Check Firebase Console → Hosting to see deployment status

**Build fails?**
- Try: `flutter clean && flutter pub get && flutter build web --release`

**Deploy fails?**
- Make sure you're logged in: `firebase login`
- Check you're using the right project: `firebase use juxeboxd`
