import 'package:flutter/material.dart';
import 'package:flutter_test_project/main.dart';
import 'package:ionicons/ionicons.dart';

import 'helpers.dart';

class ProfileButton extends StatelessWidget {
  final String name;
  final IoniconsData icon;
  const ProfileButton({super.key, required this.name, required this.icon});

  Future<void> showSignOutConfirmationDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900], // Darker background for the dialog
          title: const Text(
            'Confirm Sign Out',
            style: TextStyle(color: Colors.white), // White text for contrast
          ),
          content: const Text(
            'Are you sure you want to sign out?',
            style: TextStyle(
                color: Colors.white70), // Slightly lighter text for readability
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => {
                Navigator.of(context).pop(),
              },
              child: const Text(
                'No',
                style: TextStyle(color: Colors.redAccent), // Red for contrast
              ),
            ),
            TextButton(
              onPressed: () {
                signOut();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (context) =>
                          MyApp()), // Replace with your app's main widget
                  (Route<dynamic> route) =>
                      false, // Removes all previous routes
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('You have signed out!'),
                  ),
                );
                //Navigator.of(context).pop();
              },
              child: const Text(
                'Yes',
                style: TextStyle(
                    color: Colors.greenAccent), // Green for confirmation
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Color useColor = name == 'LogOut' ? Colors.red : Colors.white;
    Widget page = routeToPage(name);

    return Padding(
        padding: const EdgeInsets.all(8.0),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Icon(
                  icon,
                  color: useColor,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(name),
                )
              ],
            ),
          ),
          IconButton(
              onPressed: () {
                name != 'LogOut'
                    ? Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (BuildContext context) =>
                                profileRoute(name)))
                    : showSignOutConfirmationDialog(context);
              },
              icon: const Icon(Ionicons.chevron_forward_outline)),
        ]));
  }
}
