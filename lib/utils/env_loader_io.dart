import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test_project/Api/api_key.dart';

/// Load .env file from project root (mobile/desktop only).
Future<void> loadEnvVariables() async {
  await dotenv.load(fileName: '.env');
  loadApiKeysFromDotenv();
}
