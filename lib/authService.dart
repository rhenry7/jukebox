import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Sign up function
  Future<User?> signUp(String email, String password) async {
    try {
      // Attempt to create a new user
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Return the newly created user
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      // Handle different error codes from Firebase
      if (e.code == 'email-already-in-use') {
        print('This email address is already in use.');
      } else if (e.code == 'weak-password') {
        print('The password is too weak.');
      } else if (e.code == 'invalid-email') {
        print('The email address is not valid.');
      } else {
        print('Sign-up failed: ${e.message}');
      }
      return null;
    } catch (e) {
      print('An unexpected error occurred: $e');
      return null;
    }
  }
}
