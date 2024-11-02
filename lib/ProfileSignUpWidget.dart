import 'package:flutter/material.dart';
import 'package:flutter_test_project/helpers.dart';
import 'package:gap/gap.dart';
import 'package:ionicons/ionicons.dart';

class ProfileSignUp extends StatefulWidget {
  const ProfileSignUp({super.key});

  @override
  State<ProfileSignUp> createState() => ProfileSignUpPage();
}

class ProfileSignUpPage extends State<ProfileSignUp> {
  // late Future<List<UserComment>> users;
  late String userName;
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
    setState(() {
      userName = _userNameController.text.trim();
      email = _emailController.text.trim();
      password = _passwordController.text.trim();
    });
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
                  const Row(
                    children: [
                      BackButton(),
                    ],
                  ),
                  const Gap(30),
                  const Text("Sign Up", style: TextStyle(fontSize: 20)),
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
                    onPressed: () {
                      // Action when the button is pressed
                      // send to firebase
                      signUp(userName, email, password);
                      setState(() {
                        userName = '';
                        email = '';
                        password = '';
                      });
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
