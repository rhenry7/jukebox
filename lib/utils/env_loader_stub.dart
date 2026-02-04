import 'package:flutter/services.dart';
import 'package:flutter_test_project/Api/api_key.dart';

/// Load environment variables for web.
/// When running locally (not deployed): .env is bundled as an asset (pubspec.yaml) so APIs are accessible.
/// When deployed: keys come from --dart-define at build time; .env in CI is a placeholder.
Future<void> loadEnvVariables() async {
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
    // Deployed builds get keys from --dart-define; .env may be empty placeholder. Safe to ignore.
  }
}
