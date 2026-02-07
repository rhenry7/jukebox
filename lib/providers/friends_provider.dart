import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/review.dart';
import '../providers/auth_provider.dart';
import '../providers/reviews_provider.dart' show ReviewWithDocId;
import '../services/friends_service.dart';

/// Singleton service instance.
final friendsServiceProvider = Provider<FriendsService>((ref) {
  return FriendsService();
});

/// Streams the current user's friend IDs as a live list.
final friendIdsProvider = StreamProvider<List<String>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);
  return FriendsService().friendIdsStream(userId);
});

/// Check whether a specific user is a friend (derived from the friend list).
final isFriendProvider = Provider.family<bool, String>((ref, friendId) {
  final friendIds = ref.watch(friendIdsProvider).value ?? [];
  return friendIds.contains(friendId);
});

/// Streams reviews from the current user's friends.
///
/// Strategy: read the friend-ID list, then query each friend's reviews
/// sub-collection individually (Firestore doesn't support "where userId in
/// [list]" on a collectionGroup across sub-collections without a composite
/// index). We merge the streams client-side.
final friendsReviewsProvider =
    StreamProvider<List<ReviewWithDocId>>((ref) {
  final friendIdsAsync = ref.watch(friendIdsProvider);
  final friendIds = friendIdsAsync.value ?? [];

  if (friendIds.isEmpty) return Stream.value([]);

  // Stream each friend's reviews, merge and sort client-side.
  final streams = friendIds.map((friendId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(friendId)
        .collection('reviews')
        .orderBy('date', descending: true)
        .limit(20) // Cap per-friend to keep things fast
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              try {
                final review = Review.fromFirestore(doc.data());
                return ReviewWithDocId(
                  review: review,
                  docId: doc.id,
                  fullReviewId: doc.reference.path,
                );
              } catch (e) {
                debugPrint('Error parsing friend review ${doc.id}: $e');
                return null;
              }
            }).where((r) => r != null).cast<ReviewWithDocId>().toList());
  });

  // Combine all friend streams into one.
  return _combineStreams(streams.toList());
});

/// Combines multiple streams of review lists into a single sorted stream.
Stream<List<ReviewWithDocId>> _combineStreams(
    List<Stream<List<ReviewWithDocId>>> streams) {
  if (streams.isEmpty) return Stream.value([]);
  if (streams.length == 1) return streams.first;

  // Use a map to track latest value from each stream, keyed by index.
  final latestValues = <int, List<ReviewWithDocId>>{};

  // We merge by listening to all streams and emitting on every update.
  return Stream.multi((controller) {
    final subscriptions = <int, dynamic>{};

    for (var i = 0; i < streams.length; i++) {
      final index = i;
      subscriptions[index] = streams[index].listen(
        (reviews) {
          latestValues[index] = reviews;
          // Flatten, sort by date descending, and emit.
          final all = latestValues.values
              .expand((list) => list)
              .toList()
            ..sort((a, b) {
              final dateA = a.review.date ?? DateTime(2000);
              final dateB = b.review.date ?? DateTime(2000);
              return dateB.compareTo(dateA);
            });
          controller.add(all);
        },
        onError: (e) => debugPrint('Friend reviews stream error: $e'),
      );
    }

    controller.onCancel = () {
      for (final sub in subscriptions.values) {
        (sub as dynamic).cancel();
      }
    };
  });
}
