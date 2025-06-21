import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test_project/models/enhanced_user_preferences.dart';
import 'package:flutter_test_project/models/music_recommendation.dart';
import 'package:flutter_test_project/models/review.dart';

Future<List<Review>> fetchUserReviews() async {
  final snapshot = await FirebaseFirestore.instance
      .collectionGroup('reviews')
      .orderBy('date', descending: true)
      .get();

  return snapshot.docs.map((doc) => Review.fromFirestore(doc.data())).toList();
}

Future<void> submitReview(String review, double score, String artist,
    String title, bool liked, String albumImageUrl) async {
  // album display image url
  print(artist);
  User? user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    print(review.toString());
    String userId = user.uid;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reviews')
          .add({
        'displayName': user.displayName,
        'email': user.email,
        'userId': userId,
        'artist': artist,
        'title': title,
        'review': review,
        'score': score,
        'liked': liked,
        'date': FieldValue.serverTimestamp(), // Adds server timestamp
        'albumImageUrl': albumImageUrl,
      });
    } catch (e) {
      print("could not post review");
      print(e.toString());
    }
  } else {
    print('could not place review, user not signed in');
  }
}

void addUserReview() async {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final database = FirebaseFirestore.instance.collection('users');
  DatabaseReference ref = FirebaseDatabase.instance.ref();
  if (auth.currentUser != null) {
    final db = Firebase.app('jukeboxd');
  }
}

Future<void> deleteReview(String userId, String reviewDocId) async {
  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('reviews')
        .doc()
        .delete();
  } catch (e) {
    print("Could not delete review: $e");
  }
}

Future<void> updateSavedTracks(String artist, String title) async {
  final String userId = FirebaseAuth.instance.currentUser != null
      ? FirebaseAuth.instance.currentUser!.uid
      : "";
  if (userId.isEmpty) {
    print("User not logged in, cannot upload preferences.");
    return;
  }
  final String saved = "arist: ${artist}, song: ${title}";

  await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('musicPreferences')
      .doc('profile')
      .update({
    'savedTracks': FieldValue.arrayUnion([saved]),
  });
}

Future<void> updateDislikedTracks(String artist, String title) async {
  final String userId = FirebaseAuth.instance.currentUser != null
      ? FirebaseAuth.instance.currentUser!.uid
      : "";
  if (userId.isEmpty) {
    print("User not logged in, cannot upload preferences.");
    return;
  }
  final String disliked = "arist: ${artist}, song: ${title}";

  await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('musicPreferences')
      .doc('profile')
      .update({
    'dislikedTracks': FieldValue.arrayUnion([disliked]),
  });
}

Future<void> updateRemovePreferences(String artist, String title) async {
  final String userId = FirebaseAuth.instance.currentUser != null
      ? FirebaseAuth.instance.currentUser!.uid
      : "";
  if (userId.isEmpty) {
    print("User not logged in, cannot upload preferences.");
    return;
  }
  final String saved = "arist: ${artist}, song: ${title}";

  await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('musicPreferences')
      .doc('profile')
      .update({
    'savedTracks': FieldValue.arrayRemove([saved]),
  });
}

List<MusicRecommendation> removeDuplicatesFaster({
  required List<MusicRecommendation> albums,
  required List<MusicRecommendation> savedTracks,
}) {
  final savedSet = savedTracks
      .map((t) =>
          "${t.artist.toLowerCase().trim()}|${t.song.toLowerCase().trim()}")
      .toSet();

  return albums.where((album) {
    final key =
        "${album.artist.toLowerCase().trim()}|${album.song.toLowerCase().trim()}";
    return !savedSet.contains(key);
  }).toList();
}

///  upload to firebase list of preferences
///  preferences included savedTracks, [arist: Eagles, song: Hotel California]
///  OpenAi recommendation includes: arist: Eagles, song: Hotel California,
///  filter recommended list, to remove song already saved, reduce duplication

Future<List<MusicRecommendation>> removeDuplication(
    List<MusicRecommendation> albums) async {
  final String userId = FirebaseAuth.instance.currentUser != null
      ? FirebaseAuth.instance.currentUser!.uid
      : "";
  if (userId.isEmpty) {
    print("User not logged in, cannot upload preferences.");
    return [];
  }

  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('musicPreferences')
      .doc('profile')
      .get();

  if (doc.exists) {
    final List<String> savedTracks =
        EnhancedUserPreferences.fromJson(doc.data()!).savedTracks;
    albums.removeWhere((album) =>
        savedTracks.contains('artist: ${album.artist}, song: ${album.song}'));
    return albums;
  } else {
    throw new Error();
  }
}
