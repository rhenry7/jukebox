import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test_project/models/enhanced_user_preferences.dart';
import 'package:ionicons/ionicons.dart';

class UserProfileSummary extends StatefulWidget {
  const UserProfileSummary({
    super.key,
    this.color = const Color(0xFF2DBD3A),
    this.child,
  });

  final Color color;
  final Widget? child;

  @override
  State<UserProfileSummary> createState() => _UserProfileSummaryState();
}

// Future<Review> fetchReviews() async {
//   final String userId = FirebaseAuth.instance.currentUser != null
//       ? FirebaseAuth.instance.currentUser!.uid
//       : "";
//   if (userId.isEmpty) {
//     print("User not logged in, cannot fetch reviews.");
//     return [];
//   }
//   final doc = await FirebaseFirestore.instance
//       .collection('users')
//       .doc(userId)
//       .collection('reviews')
//       .orderBy('date', descending: true)
//       .snapshots();
//
//   late List<Review> reviews = [];
// }

Future<EnhancedUserPreferences> _fetchUserPreferences() async {
  final String userId = FirebaseAuth.instance.currentUser != null
      ? FirebaseAuth.instance.currentUser!.uid
      : "";

  if (userId.isEmpty) {
    print("User not logged in, cannot fetch preferences.");
    return EnhancedUserPreferences(favoriteGenres: [], favoriteArtists: []);
  }

  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('musicPreferences')
      .doc('profile')
      .get();

  if (doc.exists) {
    return EnhancedUserPreferences.fromJson(doc.data()!);
  } else {
    return EnhancedUserPreferences(favoriteGenres: [], favoriteArtists: []);
  }
}

class _UserProfileSummaryState extends State<UserProfileSummary> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.only(top: 100.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // BACK BUTTON
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BackButton(),
                ],
              ),
              // CARD CONTENT
              Padding(
                padding: EdgeInsets.only(top: 10.0),
                child: Card(
                  child: SizedBox(
                    width: 400,
                    height: 200,
                    child: Card(
                        color: Colors.white38,
                        child: Row(
                          children: [
                            Padding(
                              padding: EdgeInsets.all(10.0),
                              child: Center(
                                  child: SizedBox(
                                width: 100,
                                height: 100,
                                child: Card(
                                  color: Colors.black26,
                                  child: Icon(
                                    Ionicons.musical_notes_outline,
                                    color: Colors.white,
                                    size: 50.0,
                                    semanticLabel:
                                        'Text to announce in accessibility modes',
                                  ),
                                ),
                              )),
                            ),
                            Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Center(
                                  child: SizedBox(
                                    width: 200,
                                    child: Text(
                                      'By this way you will see this text break into maximum of three lines in real time. After that it will continue as ellipsis',
                                      textAlign: TextAlign.left,
                                      softWrap: true,
                                      maxLines: 8,
                                      overflow: TextOverflow
                                          .ellipsis, // this bound is important !!
                                    ),
                                  ),
                                )),
                          ],
                        )),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
