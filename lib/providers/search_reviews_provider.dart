import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/providers/cache_first.dart';
import 'package:flutter_test_project/providers/reviews_provider.dart';
import 'package:flutter_test_project/providers/tag_reviews_provider.dart'
    show normalizeTag;

/// The 400 newest reviews from all users, read once and kept a while: every
/// search filters this pool (reviews, tags, artists) instead of reading it
/// again per keystroke.
final searchPoolProvider = FutureProvider.autoDispose<List<ReviewWithDocId>>((
  ref,
) async {
  ref.keepAliveFor();
  final snapshot = await FirebaseFirestore.instance
      .collectionGroup('reviews')
      .orderBy('date', descending: true)
      .limit(400)
      .get();

  final results = snapshot.docs
      .map((doc) {
        try {
          final review = Review.fromFirestore(doc.data());
          return ReviewWithDocId(
            review: review,
            docId: doc.id,
            fullReviewId: doc.reference.path,
          );
        } catch (e) {
          debugPrint('[SEARCH] Skipping malformed doc ${doc.id}: $e');
          return null;
        }
      })
      .whereType<ReviewWithDocId>()
      .toList();
  return results;
});

/// Reviews from all users matching [query] (artist, title or tags,
/// case-insensitive), from [searchPoolProvider].
final searchReviewsProvider = FutureProvider.autoDispose
    .family<List<ReviewWithDocId>, String>((ref, query) async {
      final q = query.trim().toLowerCase();
      if (q.isEmpty) return [];
      final pool = await ref.watch(searchPoolProvider.future);
      return [
        for (final r in pool)
          if (r.review.artist.toLowerCase().contains(q) ||
              r.review.title.toLowerCase().contains(q) ||
              (r.review.genres ?? const <String>[]).any(
                (g) => g.toLowerCase().contains(q),
              ))
            r,
      ];
    });

/// The signed-in user's own reviews (not reposts) matching [query], newest
/// first, for the Profile page's "Search your reviews". Filters the list the
/// Profile page already has live, so it costs no extra reads.
final myReviewsSearchProvider = Provider.autoDispose
    .family<AsyncValue<List<ReviewWithDocId>>, String>((ref, query) {
      return ref
          .watch(userReviewsProvider)
          .whenData(
            (reviews) => [
              for (final r in reviews)
                if (!r.review.isRepost && matchesReviewQuery(r.review, query))
                  r,
            ],
          );
    });

/// Whether every word of [query] appears somewhere in [review]: artist,
/// song, tags / genres or the review text (case-insensitive; "rnb" finds
/// "R&B" the way tag search does).
bool matchesReviewQuery(Review review, String query) {
  final words = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty);
  if (words.isEmpty) return false;
  final haystack = [
    review.artist,
    review.title,
    ...(review.genres ?? const <String>[]),
    review.review,
  ].map(normalizeTag).join('  ');
  return words.every((w) => haystack.contains(normalizeTag(w)));
}
