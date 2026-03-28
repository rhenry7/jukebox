import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:ionicons/ionicons.dart';

import '../../../GIFs/gifs.dart';
import 'ProfileSignUpWidget.dart';
import 'auth/authService.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'helpers/profileHelpers.dart'
    show signInWithGoogle, signInWithApple, hasUserPreferences;
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
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;

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
            builder: (context) => const MainNav(title: 'CRATEBOXD'),
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
      final AuthService authService = AuthService();
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
                builder: (context) => const MainNav(title: 'CRATEBOXD'),
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
            content: Text(
                'Sign in failed: ${e.toString().replaceFirst('Exception: ', '')}'),
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

  /// Handle Apple sign-in flow
  Future<void> _handleAppleSignIn() async {
    setState(() => _isAppleLoading = true);
    try {
      final user = await signInWithApple();
      if (user == null) {
        if (mounted) setState(() => _isAppleLoading = false);
        return;
      }

      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      final hasPrefs = await hasUserPreferences(user.uid);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Successfully signed in with Apple!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      if (hasPrefs) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (context) => const MainNav(title: 'CRATEBOXD')),
          (Route<dynamic> route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (context) => const MainNav(
                  title: 'CRATEBOXD', navigateToPreferences: true)),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Apple sign-in failed: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAppleLoading = false);
    }
  }

  /// Handle forgot password — sends a reset email via Firebase Auth
  Future<void> _handleForgotPassword() async {
    final emailFromField = _emailController.text.trim();
    final emailController = TextEditingController(text: emailFromField);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Reset Password',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your email address and we\'ll send you a link to reset your password.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Send Reset Link',
                style: TextStyle(color: Colors.red[400])),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final email = emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email address.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset email sent to $email'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = e.code == 'user-not-found'
          ? 'No account found with that email address.'
          : 'Failed to send reset email. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  /// Handle Google sign-in flow
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    try {
      final user = await signInWithGoogle();
      if (user == null) {
        // User cancelled
        if (mounted) setState(() => _isGoogleLoading = false);
        return;
      }

      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      final hasPrefs = await hasUserPreferences(user.uid);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Successfully signed in with Google!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      if (hasPrefs) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (context) => const MainNav(title: 'CRATEBOXD')),
          (Route<dynamic> route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (context) => const MainNav(
                  title: 'CRATEBOXD', navigateToPreferences: true)),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Google sign-in failed: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    // Keep action buttons clear of the persistent bottom nav glass overlay.
    final bottomNavClearance = mediaQuery.viewPadding.bottom + 112.0;

    // If user is already signed in, show loading while redirecting
    if (_auth.currentUser != null) {
      return const Scaffold(
        body: DiscoBallLoading(),
      );
    }

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, bottomNavClearance),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: TextField(
                      controller: _emailController,
                      focusNode: _emailFocusNode,
                      decoration: InputDecoration(
                        labelText: 'Email',
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: TextField(
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      decoration: InputDecoration(
                        labelText: 'Password',
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
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : _handleForgotPassword,
                      child: Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSignIn,
                          style: ButtonStyle(
                            backgroundColor:
                                WidgetStateProperty.all(Colors.white),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.red),
                                  ),
                                )
                              : const Text('Sign In'),
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
                          backgroundColor:
                              WidgetStateProperty.all(Colors.green),
                        ),
                        child: const Text('Sign Up'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Divider with "or" text
                  Row(
                    children: [
                      const Expanded(child: Divider(color: Colors.grey)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 14)),
                      ),
                      const Expanded(child: Divider(color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Google Sign-In button
                  SizedBox(
                    width: double.infinity,
                    child: _isGoogleLoading
                        ? const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: (_isLoading || _isGoogleLoading || _isAppleLoading)
                                ? null
                                : _handleGoogleSignIn,
                            icon: const Icon(Ionicons.logo_google,
                                size: 20, color: Colors.white),
                            label: const Text(
                              'Sign in with Google',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                          ),
                  ),
                  // Apple Sign-In button (iOS / macOS only)
                  if (!kIsWeb) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: _isAppleLoading
                          ? const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              ),
                            )
                          : SignInWithAppleButton(
                              onPressed: (_isLoading || _isGoogleLoading || _isAppleLoading)
                                  ? () {}
                                  : _handleAppleSignIn,
                              style: SignInWithAppleButtonStyle.black,
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(30)),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
