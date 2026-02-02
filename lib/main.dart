import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/GIFs/gifs.dart';
import 'package:flutter_test_project/providers/auth_provider.dart';
import 'package:flutter_test_project/routing/MainNavigation.dart';
import 'package:flutter_test_project/utils/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables from .env file
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // If .env file doesn't exist, app will use fallback values
    debugPrint('Warning: Could not load .env file: $e');
  }
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
