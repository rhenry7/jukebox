import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper to initialize Firebase for tests
/// Uses test Firebase options to avoid requiring actual Firebase configuration
Future<void> setupFirebaseForTests() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Check if Firebase is already initialized
    Firebase.app();
    return; // Already initialized
  } catch (e) {
    // Not initialized, proceed with initialization
  }
  
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'test-api-key',
        appId: 'test-app-id',
        messagingSenderId: 'test-sender-id',
        projectId: 'test-project-id',
        storageBucket: 'test-storage-bucket',
      ),
    );
  } catch (e) {
    // If initialization fails, try with explicit name
    try {
      await Firebase.initializeApp(
        name: '[DEFAULT]',
        options: const FirebaseOptions(
          apiKey: 'test-api-key',
          appId: 'test-app-id',
          messagingSenderId: 'test-sender-id',
          projectId: 'test-project-id',
          storageBucket: 'test-storage-bucket',
        ),
      );
    } catch (e2) {
      // If still fails, log but don't throw - some tests might still work
      // if they don't actually use Firebase operations
      print('⚠️ Firebase initialization in test failed: $e2');
      print('   Some tests may fail if they require Firebase');
    }
  }
}
