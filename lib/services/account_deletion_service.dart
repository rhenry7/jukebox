import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Permanently deletes all data associated with the current user
/// and removes their Firebase Auth account.
class AccountDeletionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Subcollections nested directly under users/{userId}
  static const List<String> _userSubcollections = [
    'reviews',
    'musicPreferences',
    'notifications',
    'friends',
    'following',
    'followers',
    'signals',
    'recommendationOutcomes',
    'reviewAnalysis',
    'musicProfile',
    'playlist_interactions',
  ];

  /// Deletes all user data from Firestore and removes the Auth account.
  /// Throws an exception if anything fails.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No signed-in user found.');

    final userId = user.uid;

    // 1. Delete all subcollections under users/{userId}
    for (final subcollection in _userSubcollections) {
      await _deleteCollection(
        _db.collection('users').doc(userId).collection(subcollection),
      );
    }

    // 2. Delete playlists owned by this user
    await _deleteWhere('playlists', 'userId', userId);

    // 3. Delete userLikedPlaylists/{userId} document
    await _db.collection('userLikedPlaylists').doc(userId).delete();

    // 4. Remove this user's like entry from every playlist they liked
    //    (query the liked playlist IDs from userLikedPlaylists before deleting)
    await _deletePlaylistLikeEntries(userId);

    // 5. Delete the top-level users/{userId} document
    await _db.collection('users').doc(userId).delete();

    // 6. Delete the Firebase Auth account (must be last)
    await user.delete();
  }

  /// Deletes all documents in a collection reference in batches of 400.
  Future<void> _deleteCollection(CollectionReference ref) async {
    const batchSize = 400;
    QuerySnapshot snapshot;

    do {
      snapshot = await ref.limit(batchSize).get();
      if (snapshot.docs.isEmpty) break;

      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } while (snapshot.docs.length == batchSize);
  }

  /// Deletes all documents in a top-level collection where [field] == [value].
  Future<void> _deleteWhere(
      String collection, String field, String value) async {
    const batchSize = 400;
    QuerySnapshot snapshot;

    do {
      snapshot = await _db
          .collection(collection)
          .where(field, isEqualTo: value)
          .limit(batchSize)
          .get();

      if (snapshot.docs.isEmpty) break;

      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } while (snapshot.docs.length == batchSize);
  }

  /// Removes the user's like entry from every playlist they had liked.
  Future<void> _deletePlaylistLikeEntries(String userId) async {
    try {
      final likedDoc =
          await _db.collection('userLikedPlaylists').doc(userId).get();
      if (!likedDoc.exists) return;

      final data = likedDoc.data();
      if (data == null) return;

      // userLikedPlaylists stores playlistId keys as booleans or timestamps
      final playlistIds = data.keys.toList();
      if (playlistIds.isEmpty) return;

      final batch = _db.batch();
      for (final playlistId in playlistIds) {
        final likeRef = _db
            .collection('playlistLikes')
            .doc(playlistId)
            .collection('likes')
            .doc(userId);
        batch.delete(likeRef);
      }
      await batch.commit();
    } catch (e) {
      // Non-fatal — best effort cleanup of like entries
      debugPrint('Could not clean up playlist like entries: $e');
    }
  }
}
