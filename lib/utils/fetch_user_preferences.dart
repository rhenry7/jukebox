import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test_project/MusicPreferences/MusicTaste.dart';
import 'package:flutter_test_project/models/enhanced_user_preferences.dart';

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
