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
      preferredSize: const Size.fromHeight(225),
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
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    const Icon(Ionicons.person_outline),
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(left: 18.0),
                                      child: Text(userName),
                                    )
                                  ],
                                ),
                              ),
                              ElevatedButton.icon(
                                  onPressed: () => print("buttonPressed"),
                                  icon: const Icon(
                                      Ionicons.arrow_forward_circle_outline,
                                      color: Colors.white),
                                  label: const Text("",
                                      style: TextStyle(color: Colors.white))),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    Icon(Ionicons.settings_outline),
                                    Padding(
                                      padding: EdgeInsets.only(left: 18.0),
                                      child: Text("Settings"),
                                    )
                                  ],
                                ),
                              ),
                              ElevatedButton.icon(
                                  onPressed: () => print("buttonPressed"),
                                  icon: const Icon(
                                      Ionicons.arrow_forward_circle_outline,
                                      color: Colors.white),
                                  label: const Text("",
                                      style: TextStyle(color: Colors.white))),
                            ],
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    Icon(
                                      Ionicons.exit_outline,
                                      color: Colors.red,
                                    ),
                                    Padding(
                                      padding: EdgeInsets.only(left: 18.0),
                                      child: Text("LogOut"),
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // SETTINGS
                      ],
                    );
                  }));
                } else if (snapshot.error == null) {
                  return const Text("Loading profile...");
                } else {
                  return Text('${snapshot.data}');
                }
              })),
        ),
      ),
    ));
  }
}
