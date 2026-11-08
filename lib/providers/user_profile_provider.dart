import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cache_first.dart';

/// The public basics of another user's profile, from `users/{uid}`.
typedef UserProfileInfo = ({String? displayName, DateTime? joinDate});

/// Shows the on-device copy first, then the server's; kept for a few
/// minutes, and started when the reviewer sheet opens so "View profile" is
/// ready.
final userProfileInfoProvider =
    StreamProvider.autoDispose.family<UserProfileInfo, String>((ref, userId) {
  ref.keepAliveFor();
  return docCacheThenServer(
          FirebaseFirestore.instance.collection('users').doc(userId))
      .map((snap) {
    final data = snap.data();
    final name = data?['displayName'];
    final joined = data?['joinDate'];
    return (
      displayName: name is String && name.isNotEmpty ? name : null,
      joinDate: joined is Timestamp ? joined.toDate() : null,
    );
  });
});
