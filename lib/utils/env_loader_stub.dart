import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test_project/Api/api_key.dart';

/// Load environment variables for web.
/// - **Local (debug)**: Load .env from asset bundle and populate runtime keys so the app can access APIs.
/// - **Deployed (release)**: Do not load .env; keys come only from --dart-define at build time (GitHub Secrets).
///   Skipping .env in release avoids any chance of empty/placeholder .env affecting keys.
Future<void> loadEnvVariables() async {
  // Deployed builds: use only compile-time keys from --dart-define. Do not touch .env.
  if (kReleaseMode) {
    return;
  }
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
    // .env missing or unreadable; app will use compile-time keys if any, or show error.
  }
}
