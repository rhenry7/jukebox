import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'ProfileSignUpWidget.dart';
import 'auth/authService.dart';
import '../../../routing/MainNavigation.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Check if user is already signed in
    _checkAuthState();
    
    // Add listeners to focus nodes to update UI when focus changes
    _emailFocusNode.addListener(() {
      setState(() {}); // Rebuild when focus changes
    });
    _passwordFocusNode.addListener(() {
      setState(() {}); // Rebuild when focus changes
    });
  }

  @override
  void dispose() {
    // Clean up controllers and focus nodes
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  /// Check if user is already signed in and redirect to home
  void _checkAuthState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_auth.currentUser != null) {
        // User is already signed in, navigate to home
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const MainNav(title: "JUKEBOXD"),
          ),
          (Route<dynamic> route) => false, // Remove all previous routes
        );
      }
    });
  }

  /// Handle sign in with success/failure toasts and routing
  Future<void> _handleSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // Basic validation
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both email and password'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      AuthService authService = AuthService();
      final success = await authService.signIn(email, password);

      if (success && _auth.currentUser != null) {
        // Success - show toast and navigate to home
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully signed in!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          // Navigate to home page after a short delay to show toast
          await Future.delayed(const Duration(milliseconds: 500));
          
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const MainNav(title: "JUKEBOXD"),
              ),
              (Route<dynamic> route) => false, // Remove all previous routes
            );
          }
        }
      }
    } catch (e) {
      // Failure - show error toast
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign in failed: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If user is already signed in, show loading while redirecting
    if (_auth.currentUser != null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Sign In")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Walking music man image
            Center(
              child: Image.asset(
                'lib/assets/images/walking_music_man.png',
                height: 350,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox(height: 150);
                },
              ),
            ),
            const SizedBox(height: 32),
            // Email field with focus-aware styling
            Container(
              decoration: BoxDecoration(
                color: _emailFocusNode.hasFocus 
                    ? Colors.grey[900]?.withOpacity(0.3) 
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: TextField(
                controller: _emailController,
                focusNode: _emailFocusNode,
                decoration: InputDecoration(
                  labelText: "Email",
                  labelStyle: TextStyle(
                    color: _emailFocusNode.hasFocus 
                        ? Colors.red[600] 
                        : Colors.grey,
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: _emailFocusNode.hasFocus 
                          ? Colors.red[600]! 
                          : Colors.grey,
                      width: _emailFocusNode.hasFocus ? 2 : 1,
                    ),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.red[600]!,
                      width: 2,
                    ),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
                enabled: !_isLoading,
              ),
            ),
            const SizedBox(height: 16),
            // Password field with focus-aware styling
            Container(
              decoration: BoxDecoration(
                color: _passwordFocusNode.hasFocus 
                    ? Colors.grey[900]?.withOpacity(0.3) 
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: TextField(
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                decoration: InputDecoration(
                  labelText: "Password",
                  labelStyle: TextStyle(
                    color: _passwordFocusNode.hasFocus 
                        ? Colors.red[600] 
                        : Colors.grey,
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: _passwordFocusNode.hasFocus 
                          ? Colors.red[600]! 
                          : Colors.grey,
                      width: _passwordFocusNode.hasFocus ? 2 : 1,
                    ),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.red[600]!,
                      width: 2,
                    ),
                  ),
                ),
                obscureText: true,
                enabled: !_isLoading,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignIn,
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(Colors.red),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text("Sign In"),
                  ),
                ),
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (BuildContext context) =>
                                  const ProfileSignUp(),
                            ),
                          );
                        },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(Colors.green),
                  ),
                  child: const Text("Sign Up"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
