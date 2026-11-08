import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stream provider for Firebase auth state - automatically updates when user signs in/out
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Current authenticated user (derived from auth state)
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.value;
});

/// Current user ID - null if not authenticated
final currentUserIdProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.uid;
});

/// True when no user is signed in (anonymous auth is disabled).
final isAnonymousUserProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user == null;
});
