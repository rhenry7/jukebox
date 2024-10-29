import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:ionicons/ionicons.dart';

class ProfileSignUp extends StatefulWidget {
  const ProfileSignUp({super.key});

  @override
  State<ProfileSignUp> createState() => ProfileSignUpPage();
}

class ProfileSignUpPage extends State<ProfileSignUp> {
  // late Future<List<UserComment>> users;
  @override
  void initState() {
    super.initState();
    //users = fetchMockUserComments();
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
                  const Row(
                    children: [
                      BackButton(),
                    ],
                  ),
                  const Gap(30),
                  const Text("Sign Up", style: TextStyle(fontSize: 20)),
                  const Gap(50),
                  TextFormField(
                    decoration: const InputDecoration(
                      icon: Icon(Icons.person),
                      hintText: 'What do people call you?',
                      labelText: 'Name *',
                      labelStyle: TextStyle(color: Colors.white),
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
                  TextFormField(
                    decoration: const InputDecoration(
                      icon: Icon(Ionicons.mail_outline),
                      hintText: 'Enter your email',
                      labelText: 'Email *',
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
                  TextFormField(
                    decoration: const InputDecoration(
                      icon: Icon(Ionicons.eye_outline),
                      hintText: 'Password must be 8 characters long',
                      labelText: 'Password *',
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
                  TextFormField(
                    decoration: const InputDecoration(
                      icon: Icon(Ionicons.eye_outline),
                      hintText: 'Passwords must match',
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
