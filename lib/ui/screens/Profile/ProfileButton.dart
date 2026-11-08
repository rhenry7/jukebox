import 'package:flutter/material.dart';
import 'package:flutter_test_project/ui/screens/Profile/helpers/profileHelpers.dart';
import 'package:ionicons/ionicons.dart';
import 'package:flutter_test_project/ui/widgets/app_toast.dart';


class ProfileButton extends StatelessWidget {
  final String name;
  final IconData icon;
  const ProfileButton({super.key, required this.name, required this.icon});

  Future<void> showSignOutConfirmationDialog(BuildContext context) {
    // The drawer this button sits in; it isn't a route, so popping routes
    // doesn't close it.
    final scaffold = Scaffold.maybeOf(context);
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
              onPressed: () async {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                await signOut();
                // Close this dialog, the drawer and anything above Home; the
                // screens rebuild for the signed-out state by themselves.
                navigator.popUntil((route) => route.isFirst);
                scaffold?.closeDrawer();
                messenger.showAppToast('You have signed out');
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
    final Color useColor =
        (name == 'LogOut' || name == 'Delete Account') ? Colors.red : Colors.white;

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
              icon: const Icon(Ionicons.chevronForwardOutline)),
        ]));
  }
}
