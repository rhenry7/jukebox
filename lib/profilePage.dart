import 'package:flutter/material.dart';
import 'package:flutter_test_project/ProfileButton.dart';
import 'package:flutter_test_project/Types/userComments.dart';
import 'package:flutter_test_project/apis.dart';
import 'package:flutter_test_project/loadingWidget.dart';
import 'package:ionicons/ionicons.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => ProfileView();
}

class ProfileView extends State<ProfilePage> {
  late Future<List<UserComment>> users;
  @override
  void initState() {
    super.initState();
    users = fetchMockUserComments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: PreferredSize(
      preferredSize: const Size.fromHeight(275),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Card(
          child: FutureBuilder<List<UserComment>>(
              future: users,
              builder: ((context, snapshot) {
                if (snapshot.hasData) {
                  // TODO: Reevaluate this thing; can be better
                  final userName =
                      snapshot.data?[0].name ?? "userName not found";
                  return ListView.builder(itemBuilder: ((context, index) {
                    return Column(
                      children: [
                        // PROFILE_OVERVIEW
                        // SETTINGS
                        ProfileButton(
                            name: userName, icon: Ionicons.person_circle),
                      ],
                    );
                  }));
                } else if (snapshot.error == null) {
                  return const Center(child: Card(child: LoadingWidget()));
                } else {
                  return Text('${snapshot.data}');
                }
              })),
        ),
      ),
    ));
  }
}
