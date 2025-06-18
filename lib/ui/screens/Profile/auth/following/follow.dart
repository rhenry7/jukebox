import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> followUser(String currentUid, String targetUid) async {
  final now = Timestamp.now();
  final firestore = FirebaseFirestore.instance;

  final batch = firestore.batch();

  final followingRef = firestore
      .collection('users')
      .doc(currentUid)
      .collection('following')
      .doc(targetUid);

  final followerRef = firestore
      .collection('users')
      .doc(targetUid)
      .collection('followers')
      .doc(currentUid);

  batch.set(followingRef, {'followedAt': now});
  batch.set(followerRef, {'followedAt': now});

  await batch.commit();
}

Future<void> unfollowUser(String currentUid, String targetUid) async {
  final firestore = FirebaseFirestore.instance;

  final followingRef = firestore
      .collection('users')
      .doc(currentUid)
      .collection('following')
      .doc(targetUid);
  final followerRef = firestore
      .collection('users')
      .doc(targetUid)
      .collection('followers')
      .doc(currentUid);

  final batch = firestore.batch();
  batch.delete(followingRef);
  batch.delete(followerRef);

  await batch.commit();
}
