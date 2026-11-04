import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/review.dart';
import '../services/bookmark_service.dart';
import 'auth_provider.dart';
import 'reviews_provider.dart';

/// The signed-in user's bookmarks, newest first.
final bookmarksProvider =
    StreamProvider<List<({String reviewPath, DateTime? savedAt})>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const []);
  return BookmarkService().bookmarksStream(userId);
});

/// Paths of the reviews the user has saved — one listener for every card.
final bookmarkedPathsProvider = Provider<Set<String>>((ref) {
  final bookmarks = ref.watch(bookmarksProvider).valueOrNull ?? const [];
  return {for (final b in bookmarks) b.reviewPath};
});

/// The saved reviews themselves, in the order they were saved (newest
/// first). Reviews deleted since are left out.
final bookmarkedReviewsProvider =
    FutureProvider.autoDispose<List<ReviewWithDocId>>((ref) async {
  final bookmarks = await ref.watch(bookmarksProvider.future);
  final db = FirebaseFirestore.instance;
  final docs = await Future.wait(bookmarks.map((b) async {
    try {
      return await db.doc(b.reviewPath).get();
    } catch (e) {
      debugPrint('[BOOKMARKS] Could not load ${b.reviewPath}: $e');
      return null;
    }
  }));
  final reviews = <ReviewWithDocId>[];
  for (final doc in docs) {
    final data = doc?.data();
    if (doc == null || data == null) continue;
    try {
      reviews.add(ReviewWithDocId(
        review: Review.fromFirestore(data),
        docId: doc.id,
        fullReviewId: doc.reference.path,
      ));
    } catch (e) {
      debugPrint('[BOOKMARKS] Skipping unreadable review ${doc.id}: $e');
    }
  }
  return reviews;
});
