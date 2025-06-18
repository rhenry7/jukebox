import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'ProfileSignUpWidget.dart';
import 'auth/authService.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  late String email = '';
  late String password = '';

  @override
  void dispose() {
    // Clean up controllers
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void signIn(String email, String password) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    print(email);
    print(password);
    AuthService authService = AuthService();
    return await authService.signIn(email, password);
  }

  @override
  Widget build(BuildContext context) {
    print(email);
    print(password);
    return Scaffold(
      appBar: AppBar(title: const Text("Sign In")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email"),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ElevatedButton(
                      onPressed: () {
                        signIn(email, password);
                      },
                      style: ButtonStyle(
                          backgroundColor:
                              WidgetStateProperty.all(Colors.red)),
                      child: const Text(
                        "Sign In",
                      )),
                ),
                ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (BuildContext context) =>
                                  const ProfileSignUp()));
                    },
                    style: ButtonStyle(
                        backgroundColor:
                            WidgetStateProperty.all(Colors.green)),
                    child: const Text("Sign Up")),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
