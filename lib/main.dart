import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/Api/api_key.dart';
import 'package:flutter_test_project/GIFs/gifs.dart';
import 'package:flutter_test_project/providers/auth_provider.dart';
import 'package:flutter_test_project/routing/MainNavigation.dart';
import 'package:flutter_test_project/utils/env_config.dart';
import 'package:flutter_test_project/utils/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Runtime loading: .env via flutter_dotenv (mobile/desktop) or bundled asset (web).
  await loadEnvVariables();

  // On web, empty Firebase key causes uncaught assert; show friendly error instead.
  if (kIsWeb && firebaseOptionsKey.isEmpty) {
    runApp(
      MaterialApp(
        title: 'Jukeboxd',
        theme: ThemeData.dark(),
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Firebase API key missing on web',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Add FIREBASE_OPTIONS_KEY to .env in the project root. '
                    'For deploy, use ./deploy.sh (reads .env and passes keys at build time).',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, st) {
    debugPrint('Firebase.initializeApp failed: $e');
    debugPrint('$st');
    if (kIsWeb) {
      runApp(
        MaterialApp(
          title: 'Jukeboxd',
          theme: ThemeData.dark(),
          home: Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Firebase configuration error',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Check .env (FIREBASE_OPTIONS_KEY) or use ./deploy.sh for deploy.',
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  // Firebase Auth automatically uses localStorage on web to persist auth state
  // No need to explicitly set persistence - it's handled automatically
  if (kIsWeb) {
    debugPrint('🌐 Web platform detected - auth state will persist in localStorage');
  }

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch auth state - automatically handles initialization
    final authState = ref.watch(authStateProvider);
    
    // Show loading screen while checking auth state
    if (authState.isLoading) {
      return MaterialApp(
        title: 'Jukeboxd',
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: Colors.black,
        ),
        home: const Scaffold(
          backgroundColor: Colors.black,
          body: DiscoBallLoading(),
        ),
      );
    }
    
    // Log auth state for debugging
    final user = authState.value;
    if (user != null) {
      debugPrint('✅ User restored from cache: ${user.email}');
    } else {
      debugPrint('ℹ️ No cached user found');
    }

    return MaterialApp(
      title: 'Jukeboxd',
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromRGBO(214, 40, 40, 80)),
        useMaterial3: true,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black, // Black background
        colorScheme: const ColorScheme.dark(
          primary: Colors.black, // Primary color
          surface: Colors.black, // Background color
        ),
        useMaterial3: true,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: const MainNav(title: 'JUKEBOXD'),
    );
  }
}
