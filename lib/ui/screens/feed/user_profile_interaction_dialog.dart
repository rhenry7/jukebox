

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test_project/ui/screens/Profile/auth/following/follow.dart';
import 'package:ionicons/ionicons.dart';

/// A dialog widget that displays user profile interactions.
/// 
/// This widget is typically used to show options or actions related to a user's profile,
/// such as following, messaging, or viewing more details. It is designed to be used
/// within a feed or user list context.
/// 
/// {@category UI}
class UserProfileInteractionDialog extends StatelessWidget {
  final String displayName;
  final int reviewCount;
  final String accountCreationDate;
  final VoidCallback? onClose;
  String currentUid = FirebaseAuth.instance.currentUser!.uid;

  UserProfileInteractionDialog({
    Key? key,
    required this.displayName,
    required this.reviewCount,
    required this.accountCreationDate,
    this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(color: Colors.white, width: 2),
                  color: Colors.black,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Profile Icon
                    const Icon(
                      Ionicons.person_circle,
                      size: 60,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    // Title
                    Text(
                      displayName,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    // User Name
                    _buildInfoRow(
                      icon: Ionicons.person,
                      label: 'Name',
                      value: displayName, // Replace with actual user name
                    ),
                    const SizedBox(height: 12),
                    // Number of Reviews
                    _buildInfoRow(
                      icon: Ionicons.star,
                      label: 'Reviews',
                      value: reviewCount
                          .toString(), // Replace with actual review count
                    ),
                    const SizedBox(height: 12),
                    // Account Creation Date
                    _buildInfoRow(
                      icon: Ionicons.calendar,
                      label: 'Member Since',
                      value:
                          'January 2023', // Replace with actual creation date
                    ),
                    const SizedBox(height: 24),
                    // Close Button
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        //Navigator.of(context).pop();
                        print('Following user: $displayName as $currentUid');
                        followUser(currentUid, displayName).then((_) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Followed successfully!'),
                            ),
                          );
                        }).catchError((error) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error following user: $error'),
                            ),
                          );
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Follow'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 3.0, right: 5.0),
            child: Icon(Ionicons.person_circle_outline),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 3.0, right: 5.0),
            child: Text(displayName),
          ),
        ],
      ),
    );
  }
}



Widget _buildInfoRow({
  required IconData icon,
  required String label,
  required String value,
}) {
  return Row(
    children: [
      Icon(
        icon,
        size: 20,
        color: Colors.grey[600],
      ),
      const SizedBox(width: 12),
      Text(
        '$label: ',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.grey[700],
        ),
      ),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.end,
        ),
      ),
    ],
  );
}
