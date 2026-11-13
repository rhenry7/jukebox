import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test_project/ui/widgets/reveal_on_focus.dart';
import 'package:flutter_test_project/ui/theme/tokens.dart';

import 'package:ionicons/ionicons.dart';

import 'auth/authService.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'helpers/profileHelpers.dart'
    show signInWithGoogle, signInWithApple, completeSignIn, openSignUp;
import 'package:flutter_test_project/ui/widgets/app_toast.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  // Read on use, not when the screen is built (tests have no Firebase).
  FirebaseAuth get _auth => FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();

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

  /// Signs in with email and password, then [completeSignIn].
  Future<void> _handleSignIn() async {
    final email = _emailController.text.trim();
    // Passwords are used exactly as typed.
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      showAppToast(context, 'Please enter both email and password', tone: ToastTone.warning);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = await AuthService().signIn(email, password);
      if (mounted) await completeSignIn(context, user);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    showAppToast(context, e.toString().replaceFirst('Exception: ', ''), tone: ToastTone.error, duration: const Duration(seconds: 4));
  }

  /// Signs in with Apple, then [completeSignIn]. Cancelling does nothing.
  Future<void> _handleAppleSignIn() async {
    setState(() => _isAppleLoading = true);
    try {
      final user = await signInWithApple();
      if (user != null && mounted) await completeSignIn(context, user);
    } catch (e) {
      _showError(e);
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
            RevealOnFocus(
              child: TextField(
              controller: emailController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
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
      showAppToast(context, 'Please enter your email address.', tone: ToastTone.warning);
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      showAppToast(context, 'Password reset email sent to $email', tone: ToastTone.success, duration: const Duration(seconds: 4));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = e.code == 'user-not-found'
          ? 'No account found with that email address.'
          : 'Failed to send reset email. Please try again.';
      showAppToast(context, message, tone: ToastTone.error);
    }
  }

  /// Signs in with Google, then [completeSignIn]. Cancelling does nothing.
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    try {
      final user = await signInWithGoogle();
      if (user != null && mounted) await completeSignIn(context, user);
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      _showError(e);
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // Opened from a sign-up prompt: a way back without signing in. (In the
      // Profile tab there is nothing to go back to.)
      appBar: Navigator.canPop(context)
          ? AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
            )
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          // Clears the floating dock (hidden while typing), so the last
          // buttons are never under it.
          padding:
              const EdgeInsets.fromLTRB(24, 0, 24, AppSpacing.dockClearance),
          child: AutofillGroup(
           child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Hero image ────────────────────────────────────
              Center(
                child: Image.asset(
                  'lib/assets/images/walking_music_man.png',
                  height: 240,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox(height: 80),
                ),
              ),
              const SizedBox(height: 8),

              // ── EMAIL ─────────────────────────────────────────
              const Text(
                'EMAIL',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 8),
              RevealOnFocus(
                child: TextField(
                controller: _emailController,
                focusNode: _emailFocusNode,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _passwordFocusNode.requestFocus(),
                enabled: !_isLoading,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'curator@crateboxd.io',
                  hintStyle: TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Color(0xFF1C1C1C),
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.inputAll,
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadius.inputAll,
                    borderSide: BorderSide(color: Colors.white24, width: 1),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
              ),
              const SizedBox(height: 16),

              // ── PASSWORD ──────────────────────────────────────
              const Text(
                'PASSWORD',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 8),
              RevealOnFocus(
                child: TextField(
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                obscureText: _obscurePassword,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _isLoading ? null : _handleSignIn(),
                enabled: !_isLoading,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: '••••••••••',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF1C1C1C),
                  border: const OutlineInputBorder(
                    borderRadius: AppRadius.inputAll,
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: AppRadius.inputAll,
                    borderSide: BorderSide(color: Colors.white24, width: 1),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: Colors.white38,
                      size: 20,
                    ),
                  ),
                ),
              ),
              ),

              // ── Forgot password ───────────────────────────────
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading ? null : _handleForgotPassword,
                  child: Text(
                    'Forgot Password?',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 4),

              // ── Sign In | Sign Up ─────────────────────────────
              // Signing in is what this screen is for, so it's the filled
              // button; new users take the outlined one.
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => openSignUp(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        // Same height as the Sign In pill beside it.
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: const Text(
                        'Sign Up',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: _isLoading ? null : _handleSignIn,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF39FF6A),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF39FF6A)
                                  .withValues(alpha: 0.35),
                              blurRadius: 22,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Center(
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.black),
                                  ),
                                )
                              : const Text(
                                  'Sign In',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── OR divider ────────────────────────────────────
              Row(
                children: [
                  const Expanded(child: Divider(color: Colors.white12)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'OR',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: Colors.white12)),
                ],
              ),
              const SizedBox(height: 20),

              // ── Google sign-in ────────────────────────────────
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
                    : GestureDetector(
                        onTap:
                            (_isLoading || _isGoogleLoading || _isAppleLoading)
                                ? null
                                : _handleGoogleSignIn,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1C),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Ionicons.logoGoogle,
                                  size: 20, color: Colors.white),
                              SizedBox(width: 12),
                              Text(
                                'Sign in with Google',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),

              // ── Apple sign-in (iOS / macOS only) ─────────────
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
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        )
                      : SignInWithAppleButton(
                          onPressed: (_isLoading ||
                                  _isGoogleLoading ||
                                  _isAppleLoading)
                              ? () {}
                              : _handleAppleSignIn,
                          style: SignInWithAppleButtonStyle.black,
                          borderRadius:
                              const BorderRadius.all(Radius.circular(12)),
                        ),
                ),
              ],
            ],
           ),
          ),
        ),
      ),
    );
  }
}
