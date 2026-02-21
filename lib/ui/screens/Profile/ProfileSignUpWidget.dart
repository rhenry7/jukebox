import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test_project/routing/MainNavigation.dart';
import 'package:flutter_test_project/ui/screens/Profile/helpers/profileHelpers.dart';
import 'package:gap/gap.dart';
import 'package:ionicons/ionicons.dart';

class ProfileSignUp extends StatefulWidget {
  const ProfileSignUp({super.key});

  @override
  State<ProfileSignUp> createState() => ProfileSignUpPage();
}

class ProfileSignUpPage extends State<ProfileSignUp> {
  // late Future<List<UserComment>> users;
  late String userName; //displayName
  late String email;
  late String password;
  bool _isGoogleLoading = false;
  final _formKey = GlobalKey<FormState>();
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  /// Handle Google sign-up / sign-in flow
  Future<void> _handleGoogleSignUp() async {
    setState(() => _isGoogleLoading = true);
    try {
      final user = await signInWithGoogle();
      if (user == null) {
        // User cancelled
        if (mounted) {
          setState(() => _isGoogleLoading = false);
        }
        return;
      }

      // Wait for Firebase to settle
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      // Check if user has preferences set up
      final hasPrefs = await hasUserPreferences(user.uid);

      if (!mounted) return;

      if (hasPrefs) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (context) => const MainNav(title: 'JUKEBOXD')),
          (Route<dynamic> route) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Welcome back!'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (context) => const MainNav(
                  title: 'JUKEBOXD', navigateToPreferences: true)),
          (Route<dynamic> route) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Welcome! Please set up your music preferences to get started.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Google sign-up error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Google sign-in failed: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _userNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomKeyboardInset = mediaQuery.viewInsets.bottom;
    final bottomSafeInset = mediaQuery.viewPadding.bottom;
    final bottomPadding =
        (bottomKeyboardInset > 0 ? bottomKeyboardInset : bottomSafeInset) +
            20.0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(8.0, 8.0, 8.0, bottomPadding),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: _autovalidateMode,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Sign Up',
                                style: TextStyle(fontSize: 20)),
                            const Gap(28),
                            TextFormField(
                              controller: _userNameController,
                              decoration: const InputDecoration(
                                icon: Icon(Icons.person),
                                hintText: 'What is your username?',
                                hintStyle: TextStyle(color: Colors.grey),
                                labelText: 'Name *',
                                labelStyle: TextStyle(color: Colors.white),
                              ),
                              onSaved: (String? value) {
                                if (value != null) {
                                  userName = value;
                                }
                              },
                              validator: (String? value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Username is required.';
                                }
                                if (value.contains('@')) {
                                  return 'Do not use the @ char.';
                                }
                                if (value.trim().length < 3) {
                                  return 'Username must be at least 3 characters.';
                                }
                                return null;
                              },
                            ),
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                icon: Icon(Ionicons.mail_outline),
                                hintText: 'Enter your email',
                                hintStyle: TextStyle(color: Colors.grey),
                                labelText: 'Email *',
                              ),
                              keyboardType: TextInputType.emailAddress,
                              onSaved: (String? value) {
                                if (value != null) {
                                  email = value;
                                }
                              },
                              validator: (String? value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Email is required.';
                                }
                                final emailRegex =
                                    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                                if (!emailRegex.hasMatch(value.trim())) {
                                  return 'Please enter a valid email address.';
                                }
                                return null;
                              },
                            ),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                icon: Icon(Ionicons.eye_outline),
                                hintText: 'Password must be 8 characters long',
                                hintStyle: TextStyle(color: Colors.grey),
                                labelText: 'Password *',
                              ),
                              onSaved: (String? value) {
                                if (value != null) {
                                  password = value;
                                }
                              },
                              validator: (String? value) {
                                if (value == null || value.isEmpty) {
                                  return 'Password is required.';
                                }
                                if (value.length < 8) {
                                  return 'Password must be at least 8 characters.';
                                }
                                return null;
                              },
                            ),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                icon: Icon(Ionicons.eye_outline),
                                hintText: 'Passwords must match',
                                hintStyle: TextStyle(color: Colors.grey),
                                labelText: 'Confirm Password *',
                              ),
                              validator: (String? value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please confirm your password.';
                                }
                                if (value != _passwordController.text) {
                                  return 'Passwords do not match.';
                                }
                                return null;
                              },
                            ),
                            const Gap(40),
                            ElevatedButton(
                              onPressed: () async {
                                debugPrint(
                                    '🔵 [SIGNUP] Create Account button pressed');

                                // Trigger form validation — shows inline errors on each field
                                final isValid =
                                    _formKey.currentState?.validate() ?? false;

                                if (!isValid) {
                                  // Switch to real-time validation so errors update as user types
                                  setState(() {
                                    _autovalidateMode =
                                        AutovalidateMode.onUserInteraction;
                                  });
                                  return;
                                }

                                try {
                                  final userNameValue =
                                      _userNameController.text.trim();
                                  final emailValue =
                                      _emailController.text.trim();
                                  final passwordValue =
                                      _passwordController.text.trim();

                                  debugPrint(
                                      '✅ [SIGNUP] Validation passed, calling signUp...');
                                  await signUp(
                                      userNameValue, emailValue, passwordValue);
                                  debugPrint(
                                      '✅ [SIGNUP] signUp call completed');

                                  await Future.delayed(
                                      const Duration(milliseconds: 500));

                                  final currentUser =
                                      FirebaseAuth.instance.currentUser;
                                  if (currentUser != null) {
                                    final hasPrefs = await hasUserPreferences(
                                        currentUser.uid);

                                    if (hasPrefs) {
                                      if (mounted) {
                                        Navigator.of(context)
                                            .pushAndRemoveUntil(
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  const MainNav(
                                                      title: 'JUKEBOXD')),
                                          (Route<dynamic> route) => false,
                                        );
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text('Welcome!'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    } else {
                                      if (mounted) {
                                        Navigator.of(context)
                                            .pushAndRemoveUntil(
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  const MainNav(
                                                      title: 'JUKEBOXD',
                                                      navigateToPreferences:
                                                          true)),
                                          (Route<dynamic> route) => false,
                                        );
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Welcome! Please set up your music preferences to get started.'),
                                            duration: Duration(seconds: 3),
                                          ),
                                        );
                                      }
                                    }
                                  } else {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Sign-up failed. Please try again.'),
                                        ),
                                      );
                                    }
                                  }

                                  if (mounted) {
                                    _userNameController.clear();
                                    _emailController.clear();
                                    _passwordController.clear();
                                    _confirmPasswordController.clear();
                                  }
                                } catch (e) {
                                  debugPrint('❌ [SIGNUP] Error: $e');
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Sign-up failed: $e'),
                                      ),
                                    );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30.0),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                backgroundColor: Colors.green[800],
                              ),
                              child: const Text(
                                'Create Account',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            const Gap(24),
                            _isGoogleLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : ElevatedButton.icon(
                                    onPressed: _handleGoogleSignUp,
                                    icon: const Icon(Ionicons.logo_google,
                                        size: 20, color: Colors.white),
                                    label: const Text(
                                      'Sign Up With Google',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(30.0),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24, vertical: 12),
                                      backgroundColor: Colors.blueAccent,
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
