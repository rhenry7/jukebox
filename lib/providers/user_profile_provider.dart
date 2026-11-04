import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The public basics of another user's profile, from `users/{uid}`.
typedef UserProfileInfo = ({String? displayName, DateTime? joinDate});

final userProfileInfoProvider = FutureProvider.autoDispose
    .family<UserProfileInfo, String>((ref, userId) async {
  final data =
      (await FirebaseFirestore.instance.collection('users').doc(userId).get())
          .data();
  final name = data?['displayName'];
  final joined = data?['joinDate'];
  return (
    displayName: name is String && name.isNotEmpty ? name : null,
    joinDate: joined is Timestamp ? joined.toDate() : null,
  );
});
