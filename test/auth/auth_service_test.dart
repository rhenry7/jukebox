import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

/// Testable version of AuthService that accepts an injected FirebaseAuth.
class TestableAuthService {
  final FirebaseAuth _auth;

  TestableAuthService(this._auth);

  Future<User?> signUp(
      String displayName, String email, String password) async {
    try {
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;

      if (user != null) {
        await user.updateDisplayName(displayName);
        await user.reload();
        user = _auth.currentUser;
      }

      return user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        return null;
      } else if (e.code == 'weak-password') {
        return null;
      } else if (e.code == 'invalid-email') {
        return null;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return true;
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password.';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many requests. Please try again later.';
          break;
        default:
          errorMessage = 'An error occurred. Please try again.';
      }
      throw Exception(errorMessage);
    } catch (e) {
      rethrow;
    }
  }
}

void main() {
  group('AuthService - signUp', () {
    test('creates user and sets display name', () async {
      final mockUser = MockUser(
        uid: 'new-user-123',
        email: 'new@example.com',
        displayName: 'New User',
        isAnonymous: false,
      );
      final mockAuth = MockFirebaseAuth(mockUser: mockUser);
      final authService = TestableAuthService(mockAuth);

      final user =
          await authService.signUp('New User', 'new@example.com', 'password123');

      expect(user, isNotNull);
      // MockFirebaseAuth generates its own UID on createUser, so just verify it's non-empty
      expect(user!.uid, isNotEmpty);
      expect(user.displayName, 'New User');
    });

    test('returns user after successful sign up', () async {
      final mockUser = MockUser(
        uid: 'uid-abc',
        email: 'test@test.com',
        displayName: 'TestUser',
        isAnonymous: false,
      );
      final mockAuth = MockFirebaseAuth(mockUser: mockUser);
      final authService = TestableAuthService(mockAuth);

      final user =
          await authService.signUp('TestUser', 'test@test.com', 'securePass1');

      expect(user, isNotNull);
      expect(mockAuth.currentUser, isNotNull);
      expect(mockAuth.currentUser!.email, 'test@test.com');
    });

    test('user is signed in after sign up', () async {
      final mockUser = MockUser(
        uid: 'uid-xyz',
        email: 'auto@test.com',
        isAnonymous: false,
      );
      final mockAuth = MockFirebaseAuth(mockUser: mockUser);
      final authService = TestableAuthService(mockAuth);

      await authService.signUp('Auto', 'auto@test.com', 'password123');

      // After sign-up, user should be the current user
      expect(mockAuth.currentUser, isNotNull);
    });
  });

  group('AuthService - signIn', () {
    test('returns true on successful sign in', () async {
      final mockUser = MockUser(
        uid: 'existing-user',
        email: 'existing@example.com',
        isAnonymous: false,
      );
      // Start signed out, with a mock user that can be signed in
      final mockAuth = MockFirebaseAuth(
        signedIn: false,
        mockUser: mockUser,
      );
      final authService = TestableAuthService(mockAuth);

      final result =
          await authService.signIn('existing@example.com', 'password123');

      expect(result, true);
      expect(mockAuth.currentUser, isNotNull);
    });

    test('user is accessible after sign in', () async {
      final mockUser = MockUser(
        uid: 'user-456',
        email: 'user@test.com',
        displayName: 'Existing User',
        isAnonymous: false,
      );
      final mockAuth = MockFirebaseAuth(
        signedIn: false,
        mockUser: mockUser,
      );
      final authService = TestableAuthService(mockAuth);

      await authService.signIn('user@test.com', 'password123');

      final currentUser = mockAuth.currentUser;
      expect(currentUser, isNotNull);
      expect(currentUser!.uid, 'user-456');
    });
  });

  group('AuthService - sign out', () {
    test('currentUser is null after sign out', () async {
      final mockUser = MockUser(
        uid: 'user-signout',
        email: 'signout@test.com',
        isAnonymous: false,
      );
      final mockAuth = MockFirebaseAuth(
        signedIn: true,
        mockUser: mockUser,
      );

      expect(mockAuth.currentUser, isNotNull);

      await mockAuth.signOut();

      expect(mockAuth.currentUser, isNull);
    });
  });

  group('AuthService - auth state stream', () {
    test('emits user on sign in', () async {
      final mockUser = MockUser(
        uid: 'stream-user',
        email: 'stream@test.com',
        isAnonymous: false,
      );
      final mockAuth = MockFirebaseAuth(
        signedIn: false,
        mockUser: mockUser,
      );

      // Listen to auth state changes
      final states = <User?>[];
      mockAuth.authStateChanges().listen((user) {
        states.add(user);
      });

      // Sign in
      await mockAuth.signInWithEmailAndPassword(
        email: 'stream@test.com',
        password: 'password',
      );

      // Allow stream to emit
      await Future.delayed(const Duration(milliseconds: 100));

      // Should have received the user
      expect(states.any((u) => u != null), true);
    });
  });
}
