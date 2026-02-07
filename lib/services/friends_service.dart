import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service for managing friend relationships in Firestore.
///
/// Firestore structure:
///   users/{userId}/friends/{friendId} → { userId, displayName, addedAt }
class FriendsService {
  final FirebaseFirestore _firestore;

  FriendsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Reference to a user's friends sub-collection.
  CollectionReference<Map<String, dynamic>> _friendsRef(String userId) =>
      _firestore.collection('users').doc(userId).collection('friends');

  /// Add [friendId] as a friend of [currentUserId].
  /// Stores the friend's display name for quick reads.
  Future<void> addFriend({
    required String currentUserId,
    required String friendId,
    required String friendDisplayName,
  }) async {
    if (currentUserId == friendId) return; // Can't friend yourself

    try {
      await _friendsRef(currentUserId).doc(friendId).set({
        'userId': friendId,
        'displayName': friendDisplayName,
        'addedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Added friend: $friendId ($friendDisplayName)');
    } catch (e) {
      debugPrint('Error adding friend: $e');
      rethrow;
    }
  }

  /// Remove [friendId] from the current user's friends list.
  Future<void> removeFriend({
    required String currentUserId,
    required String friendId,
  }) async {
    try {
      await _friendsRef(currentUserId).doc(friendId).delete();
      debugPrint('Removed friend: $friendId');
    } catch (e) {
      debugPrint('Error removing friend: $e');
      rethrow;
    }
  }

  /// Check whether [friendId] is in the current user's friends list.
  Future<bool> isFriend({
    required String currentUserId,
    required String friendId,
  }) async {
    try {
      final doc = await _friendsRef(currentUserId).doc(friendId).get();
      return doc.exists;
    } catch (e) {
      debugPrint('Error checking friend status: $e');
      return false;
    }
  }

  /// Stream the list of friend user-IDs for the given user.
  Stream<List<String>> friendIdsStream(String userId) {
    return _friendsRef(userId).snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => doc.id).toList());
  }

  /// Stream the full friend documents (includes displayName, addedAt).
  Stream<List<Map<String, dynamic>>> friendsStream(String userId) {
    return _friendsRef(userId)
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// One-shot fetch of friend IDs.
  Future<List<String>> getFriendIds(String userId) async {
    try {
      final snapshot = await _friendsRef(userId).get();
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      debugPrint('Error fetching friend IDs: $e');
      return [];
    }
  }

  /// Get the friend count for a user.
  Future<int> getFriendCount(String userId) async {
    try {
      final snapshot = await _friendsRef(userId).count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('Error getting friend count: $e');
      return 0;
    }
  }
}
