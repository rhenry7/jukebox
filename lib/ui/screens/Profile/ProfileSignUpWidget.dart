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

  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    //users = fetchMockUserComments();
  }

  @override
  void dispose() {
    // Clean up controllers when the widget is disposed
    _userNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Center(
              child: Column(
                children: [
                  // PROFILE_OVERVIEW
                  // SETTINGS
                  const Gap(30),

                  const Gap(30),
                  const Text('Sign Up', style: TextStyle(fontSize: 20)),
                  const Gap(50),
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
                      return (value != null && value.contains('@'))
                          ? 'Do not use the @ char.'
                          : null;
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
                    onSaved: (String? value) {
                      // This optional block of code can be used to run
                      // code when the user saves the form.
                      if (value != null) {
                        email = value;
                      }
                    },
                    validator: (String? value) {
                      return (value != null && value.contains('@'))
                          ? 'Do not use the @ char.'
                          : null;
                    },
                  ),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      icon: Icon(Ionicons.eye_outline),
                      hintText: 'Password must be 8 characters long',
                      hintStyle: TextStyle(color: Colors.grey),
                      labelText: 'Password *',
                    ),
                    onSaved: (String? value) {
                      // This optional block of code can be used to run
                      // code when the user saves the form.
                      if (value != null) {
                        password = value;
                      }
                    },
                    validator: (String? value) {
                      return (value != null && value.contains('@'))
                          ? 'Do not use the @ char.'
                          : null;
                    },
                  ),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      icon: Icon(Ionicons.eye_outline),
                      hintText: 'Passwords must match',
                      hintStyle: TextStyle(color: Colors.grey),
                      labelText: 'Confirm Password *',
                    ),
                    onSaved: (String? value) {
                      // This optional block of code can be used to run
                      // code when the user saves the form.
                    },
                    validator: (String? value) {
                      return (value != null && value.contains('@'))
                          ? 'Do not use the @ char.'
                          : null;
                    },
                  ),
                  const Gap(70),
                  ElevatedButton(
                    onPressed: () async {
                      // Action when the button is pressed
                      print('🔵 [SIGNUP] Create Account button pressed');
                      try {
                        // Read values directly from controllers
                        final userNameValue = _userNameController.text.trim();
                        final emailValue = _emailController.text.trim();
                        final passwordValue = _passwordController.text.trim();
                        
                        print('🔵 [SIGNUP] Values: userName=$userNameValue, email=$emailValue, password=${passwordValue.isNotEmpty ? "***" : "empty"}');
                        
                        // Validate inputs
                        if (userNameValue.isEmpty || emailValue.isEmpty || passwordValue.isEmpty) {
                          print('⚠️ [SIGNUP] Validation failed: empty fields');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please fill in all fields'),
                            ),
                          );
                          return;
                        }

                        print('✅ [SIGNUP] Validation passed, calling signUp...');
                        // Send to Firebase
                        await signUp(userNameValue, emailValue, passwordValue);
                        print('✅ [SIGNUP] signUp call completed');

                        // Wait a moment for Firebase to update
                        await Future.delayed(const Duration(milliseconds: 500));

                        // After successful sign-up, check if the user is authenticated
                        final currentUser = FirebaseAuth.instance.currentUser;
                        if (currentUser != null) {
                          // Check if user has preferences set up
                          final hasPrefs = await hasUserPreferences(currentUser.uid);
                          
                          if (hasPrefs) {
                            // User has preferences, go to home
                            if (mounted) {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                    builder: (context) => const MainNav(
                                        title: 'JUKEBOXD')),
                                (Route<dynamic> route) => false,
                              );
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Welcome!'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          } else {
                            // User has no preferences, route to preferences page
                            if (mounted) {
                              // Navigate to MainNav with flag to navigate to preferences
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                    builder: (context) => const MainNav(
                                        title: 'JUKEBOXD',
                                        navigateToPreferences: true)),
                                (Route<dynamic> route) => false,
                              );
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Welcome! Please set up your music preferences to get started.'),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            }
                          }
                        } else {
                          // Sign-up failed
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Sign-up failed. Please try again.'),
                              ),
                            );
                          }
                        }

                        // Clear input fields
                        if (mounted) {
                          _userNameController.clear();
                          _emailController.clear();
                          _passwordController.clear();
                        }
                      } catch (e) {
                        // Handle sign-up errors here
                        print('❌ [SIGNUP] Error: $e');
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
                        borderRadius:
                            BorderRadius.circular(30.0), // Round radius
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      backgroundColor: Colors.green[800], // Button color
                    ),
                    child: const Text(
                      'Create Account',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const Gap(50),
                  ElevatedButton(
                    onPressed: () {
                      // Action when the button is pressed
                      // send to firebase
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(30.0), // Round radius
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      backgroundColor: Colors.blueAccent, // Button color
                    ),
                    child: const Text(
                      'Sign Up With Google',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const Gap(5),
                  ElevatedButton(
                    onPressed: () {
                      // Action when the button is pressed
                      // send to firebase
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(30.0), // Round radius
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 34, vertical: 12),
                      backgroundColor: Colors.white, // Button color
                    ),
                    child: const Text(
                      'Sign Up With Apple',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
