import 'package:flutter/services.dart';
import 'package:flutter_test_project/Api/api_key.dart';

/// Load environment variables for web.
/// Note: .env is not bundled as an asset (gitignored, not in CI).
/// For web builds, keys come from --dart-define at build time.
/// This function is kept for potential future use but will gracefully fail if .env doesn't exist.
Future<void> loadEnvVariables() async {
  // .env is no longer bundled as an asset, so this will always fail gracefully
  // Keys come from --dart-define for web builds (see deploy.sh)
  // This try-catch ensures the app doesn't crash if someone tries to load .env
  try {
    final String envString = await rootBundle.loadString('.env');
    final Map<String, String> env = {};
    
    for (final line in envString.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      
      final index = trimmed.indexOf('=');
      if (index > 0) {
        final key = trimmed.substring(0, index).trim();
        final value = trimmed.substring(index + 1).trim();
        // Remove quotes if present
        String cleanValue = value;
        if (cleanValue.startsWith('"') && cleanValue.endsWith('"')) {
          cleanValue = cleanValue.substring(1, cleanValue.length - 1);
        } else if (cleanValue.startsWith("'") && cleanValue.endsWith("'")) {
          cleanValue = cleanValue.substring(1, cleanValue.length - 1);
        }
        env[key] = cleanValue;
      }
    }
    
    loadApiKeysFromMap(env);
  } catch (e) {
    // .env might not exist in production builds (keys come from --dart-define)
    // This is expected and safe to ignore
  }
}
