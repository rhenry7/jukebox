import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test_project/Api/api_key.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Signs visitors into a shared demo/QA account on startup so they can see
/// and interact with real data without creating an account.
///
/// Enabled only when DEMO_USER_EMAIL and DEMO_USER_PASSWORD are supplied via
/// --dart-define (see .env / deploy.sh). If they are absent, this is a no-op.
///
/// If the visitor explicitly signs out, an opt-out flag is stored so they are
/// not silently signed back in on the next launch (lets QA test signed-out
/// flows).
class DemoAutoSignIn {
  static const String _optOutKey = 'demo_auto_sign_in_opted_out';

  static bool get isEnabled =>
      demoUserEmail.isNotEmpty && demoUserPassword.isNotEmpty;

  /// Call after Firebase.initializeApp() and before runApp().
  static Future<void> signInIfNeeded() async {
    if (!isEnabled) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_optOutKey) ?? false) {
        debugPrint('ℹ️ Demo auto sign-in skipped (user previously signed out)');
        return;
      }

      // Wait for persisted auth state to be restored before deciding.
      final auth = FirebaseAuth.instance;
      final existingUser = await auth.authStateChanges().first;
      if (existingUser != null) return;

      await auth.signInWithEmailAndPassword(
        email: demoUserEmail,
        password: demoUserPassword,
      );
      debugPrint('✅ Demo auto sign-in succeeded');
    } catch (e) {
      // Never block startup; fall back to the normal signed-out experience.
      debugPrint('⚠️ Demo auto sign-in failed: $e');
    }
  }

  /// Call when the user explicitly signs out.
  static Future<void> optOut() async {
    if (!isEnabled) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_optOutKey, true);
    } catch (e) {
      debugPrint('Error saving demo auto sign-in opt-out: $e');
    }
  }
}
