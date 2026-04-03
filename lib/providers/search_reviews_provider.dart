import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/providers/reviews_provider.dart';

/// Fetches up to 400 recent reviews from all users and filters client-side
/// against [query], matching artist, title, and genres (case-insensitive).
final searchReviewsProvider =
    FutureProvider.autoDispose.family<List<ReviewWithDocId>, String>((ref, query) async {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return [];

  debugPrint('[SEARCH] Querying reviews for: "$q"');

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
      .where((r) {
        final artist = r.review.artist.toLowerCase();
        final title = r.review.title.toLowerCase();
        final genres =
            r.review.genres?.map((g) => g.toLowerCase()).join(' ') ?? '';
        return artist.contains(q) || title.contains(q) || genres.contains(q);
      })
      .toList();

  debugPrint('[SEARCH] Found ${results.length} results for "$q"');
  return results;
});
