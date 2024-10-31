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

  Future<void> signIn(String email, String password) async {
    try {
      print(email);
      // Attempt to sign in with Firebase
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      print("successfully signed in!");
      // Sign-in successful
    } on FirebaseAuthException catch (e) {
      // Handle errors
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = "No user found with this email.";
          break;
        case 'wrong-password':
          errorMessage = "Incorrect password.";
          break;
        case 'invalid-email':
          errorMessage = "Invalid email address.";
          break;
        case 'too-many-requests':
          errorMessage = "Too many requests. Please try again later.";
          break;
        case 'operation-not-allowed':
          errorMessage = "This operation is not allowed.";
          break;
        default:
          errorMessage = "An error occurred. Please try again.";
      }
      print(errorMessage); // Print to console for debugging
      // Display error message to the user (e.g., using a SnackBar)
      // ... (Code to display error message)
    }
  }
}
