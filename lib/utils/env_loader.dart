import 'package:flutter/foundation.dart';

// Import both implementations
import 'env_loader_io.dart' as io_loader;
import 'env_loader_stub.dart' as web_loader;

/// Load environment variables based on platform.
/// Web uses rootBundle (env_loader_stub), others use flutter_dotenv (env_loader_io).
Future<void> loadEnvVariables() async {
  if (kIsWeb) {
    await web_loader.loadEnvVariables();
  } else {
    await io_loader.loadEnvVariables();
  }
}
