import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/friends_provider.dart';
import '../../services/friends_service.dart';
import 'auth_gate_modal.dart';

/// Adds or removes [friendId] as a friend of the signed-in user and says so
/// in a snackbar. Anonymous users get the sign-up modal instead.
Future<void> toggleFriend(
  BuildContext context,
  WidgetRef ref, {
  required String friendId,
  required String friendName,
}) async {
  final currentUserId = ref.read(currentUserIdProvider);
  if (currentUserId == null || ref.read(isAnonymousUserProvider)) {
    showAuthGateModal(context);
    return;
  }
  final messenger = ScaffoldMessenger.of(context);
  final service = FriendsService();
  try {
    if (ref.read(isFriendProvider(friendId))) {
      await service.removeFriend(
          currentUserId: currentUserId, friendId: friendId);
      messenger.showSnackBar(SnackBar(
        content: Text('Removed $friendName from friends'),
        duration: const Duration(seconds: 2),
      ));
    } else {
      await service.addFriend(
        currentUserId: currentUserId,
        friendId: friendId,
        friendDisplayName: friendName,
      );
      messenger.showSnackBar(SnackBar(
        content: Text('Added $friendName as a friend!'),
        duration: const Duration(seconds: 2),
      ));
    }
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
  }
}
