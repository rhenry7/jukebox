# Deployment Summary

## Updating Your Deployed App

**Important:** Code changes do NOT automatically update your deployed app. You must rebuild and redeploy after making changes.

### Quick Update Process

1. **Make your code changes** locally
2. **Build for production:**
   ```bash
   flutter build web --release
   ```
3. **Deploy to Firebase:**
   ```bash
   firebase deploy --only hosting
   ```

**Or use the automated script:**
```bash
./deploy.sh
```

### Timeline
- Build: ~1-2 minutes
- Deploy: ~1-2 minutes  
- **Total: ~2-4 minutes** for changes to go live

### Important Notes

- **Local development** (`flutter run`) is NOT deployed - only visible on your machine
- **Production changes** require rebuild + deploy to go live
- After deploying, **hard refresh** your browser (`Cmd+Shift+R` on Mac, `Ctrl+Shift+R` on Windows) to see updates
- Firebase Hosting caches files, so changes may take a minute to appear globally

### Development Workflow

1. Make changes locally
2. Test with `flutter run -d chrome` 
3. When ready, deploy with `./deploy.sh`
4. Changes are live in ~2-4 minutes

---

## Initial Deployment

### Prerequisites
- Firebase CLI installed: `npm install -g firebase-tools`
- Logged in: `firebase login`
- Project initialized: `firebase init hosting`

### First-Time Deployment

```bash
# Build the app
flutter build web --release

# Deploy to Firebase
firebase deploy --only hosting
```

Your app will be live at: `https://juxeboxd.web.app`

---

## Troubleshooting

- **Changes not showing?** Wait 2-3 minutes, then hard refresh browser
- **Build fails?** Try: `flutter clean && flutter pub get && flutter build web --release`
- **Deploy fails?** Check: `firebase login` and `firebase use juxeboxd`
