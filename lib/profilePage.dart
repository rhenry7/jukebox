import 'package:flutter/material.dart';
import 'package:flutter_test_project/Types/userComments.dart';
import 'package:flutter_test_project/apis.dart';
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
      preferredSize: const Size.fromHeight(350),
      child: Expanded(
        child: Card(
          child: Expanded(
              child: FutureBuilder<List<UserComment>>(
                  future: users,
                  builder: ((context, snapshot) {
                    if (snapshot.hasData) {
                      // TODO: Re
                      final userName = snapshot.data!.first.name;
                      return ListView.builder(itemBuilder: ((context, index) {
                        return Column(
                          children: [
                            // PROFILE_OVERVIEW
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    const Icon(Ionicons.person_outline),
                                    Text(userName)
                                  ],
                                ),
                                ElevatedButton.icon(
                                    onPressed: () => print("buttonPressed"),
                                    icon: const Icon(
                                        Ionicons.arrow_forward_circle_outline),
                                    label: const Text("leave")),
                              ],
                            ),
                            // SETTINGS
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Icon(Ionicons.person_outline),
                                    Text("settings")
                                  ],
                                ),
                                ElevatedButton.icon(
                                    onPressed: () => print("buttonPressed"),
                                    icon: const Icon(Ionicons.hammer_outline),
                                    label: const Text("leave")),
                              ],
                            ), // USER_REVIEWS
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Icon(Ionicons.musical_note_outline),
                                    Text("Reviews")
                                  ],
                                ),
                                ElevatedButton.icon(
                                    onPressed: () => print("buttonPressed"),
                                    icon: const Icon(
                                        Ionicons.arrow_forward_circle_outline),
                                    label: const Text("leave")),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Icon(Ionicons.close_circle_outline,
                                        color: Colors.red),
                                    Text("LogOut")
                                  ],
                                ),
                                ElevatedButton.icon(
                                    onPressed: () => print("buttonPressed"),
                                    icon: const Icon(
                                        Ionicons.arrow_forward_circle_outline),
                                    label: const Text("leave")),
                              ],
                            )
                          ],
                        );
                      }));
                    } else {
                      print(snapshot.error);
                      return const Text("snapshot error");
                    }
                  }))),
        ),
      ),
    ));
  }
}
