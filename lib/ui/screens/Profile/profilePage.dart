import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test_project/GIFs/gifs.dart';
import 'package:flutter_test_project/ui/screens/Profile/ProfileButton.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/models/user_comments.dart';
import 'package:flutter_test_project/Api/apis.dart';
import 'package:ionicons/ionicons.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => ProfileView();
}

class ProfileView extends State<ProfilePage> {
  late Future<List<Review>> users;
  @override
  void initState() {
    super.initState();
    users = fetchMockUserComments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: PreferredSize(
      preferredSize: const Size.fromHeight(375),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Card(
          child: FutureBuilder<List<Review>>(
              future: users,
              builder: ((context, snapshot) {
                if (snapshot.hasData) {
                  // TODO: Reevaluate this thing; can be better
                  final String userName =
                      FirebaseAuth.instance.currentUser?.displayName ??
                          "no user name";
                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        // PROFILE_OVERVIEW
                        // SETTINGS
                        ProfileButton(
                            name: userName, icon: Ionicons.person_circle),
                        const ProfileButton(
                            name: "Reviews",
                            icon: Ionicons.musical_notes_outline),
                        const ProfileButton(
                            name: "Preferences",
                            icon: Ionicons.analytics_outline),
                        const ProfileButton(
                            name: "Notifications",
                            icon: Ionicons.notifications_outline),
                        const ProfileButton(
                            name: "LogOut", icon: Ionicons.exit_outline),
                      ],
                    ),
                  );
                } else if (snapshot.hasError) {
                  return Image.asset('lib/assets/images/discoball_loading.png');
                } else {
                  return Text('');
                }
              })),
        ),
      ),
    ));
  }
}
