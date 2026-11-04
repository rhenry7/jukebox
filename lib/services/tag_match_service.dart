import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/review.dart';
import '../providers/reviews_provider.dart' show ReviewWithDocId;
import '../ui/widgets/genre_pills.dart' show splitGenreTags;
import 'for_you_service.dart' show ReviewMatch;

/// Reviews by other people whose tags overlap the tags on a review the user
/// just wrote. Runs entirely on the client against recent reviews, so it
/// works without the Cloud Functions backend.
class TagMatchService {
  /// How many of the newest reviews to compare against.
  static const int poolSize = 300;

  /// How many matches to show.
  static const int maxMatches = 10;

  /// Matches for the review at [reviewPath] (users/{uid}/reviews/{id}),
  /// tagged [tags], of [title] by [artist]. Empty on any failure.
  static Future<List<ReviewMatch>> matchesFor({
    required String reviewPath,
    required List<String> tags,
    required String title,
    required String artist,
    FirebaseFirestore? db,
  }) async {
    if (splitGenreTags(tags).isEmpty) return const [];
    try {
      final snapshot = await (db ?? FirebaseFirestore.instance)
          .collectionGroup('reviews')
          .orderBy('date', descending: true)
          .limit(poolSize)
          .get();
      final pool = <ReviewWithDocId>[];
      for (final doc in snapshot.docs) {
        try {
          pool.add(ReviewWithDocId(
            review: Review.fromFirestore(doc.data()),
            docId: doc.id,
            fullReviewId: doc.reference.path,
          ));
        } catch (e) {
          debugPrint('[TAG_MATCH] Skipping unreadable review ${doc.id}: $e');
        }
      }
      return rankByTagOverlap(
        tags: tags,
        title: title,
        artist: artist,
        authorId: _authorOf(reviewPath),
        candidates: pool,
      );
    } catch (e) {
      debugPrint('[TAG_MATCH] Could not load reviews: $e');
      return const [];
    }
  }

  static String? _authorOf(String reviewPath) {
    final parts = reviewPath.split('/');
    return parts.length >= 2 && parts[0] == 'users' ? parts[1] : null;
  }
}

/// Ranks [candidates] by how many tags they share with [tags] (ignoring
/// case), then by the share of tags in common, then newest first. Leaves
/// out the user's own reviews, reposts, other reviews of the same track and
/// anything with no tag in common; one review per track.
@visibleForTesting
List<ReviewMatch> rankByTagOverlap({
  required List<String> tags,
  required String title,
  required String artist,
  required String? authorId,
  required List<ReviewWithDocId> candidates,
  int limit = TagMatchService.maxMatches,
}) {
  String key(String s) => s.trim().toLowerCase();
  final mine = {for (final t in splitGenreTags(tags)) key(t)};
  if (mine.isEmpty) return const [];
  final ownTrack = '${key(title)}|${key(artist)}';

  final scored =
      <({ReviewWithDocId review, List<String> shared, double jaccard})>[];
  final seenTracks = <String>{ownTrack};
  for (final c in candidates) {
    final r = c.review;
    if (r.isRepost || (authorId != null && r.userId == authorId)) continue;
    final theirs = splitGenreTags(r.genres);
    final shared = [
      for (final t in theirs)
        if (mine.contains(key(t))) t,
    ];
    if (shared.isEmpty) continue;
    final union = {...mine, ...theirs.map(key)}.length;
    scored.add((review: c, shared: shared, jaccard: shared.length / union));
  }

  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  scored.sort((a, b) {
    final byShared = b.shared.length.compareTo(a.shared.length);
    if (byShared != 0) return byShared;
    final byJaccard = b.jaccard.compareTo(a.jaccard);
    if (byJaccard != 0) return byJaccard;
    return (b.review.review.date ?? epoch)
        .compareTo(a.review.review.date ?? epoch);
  });

  final result = <ReviewMatch>[];
  for (final s in scored) {
    final r = s.review.review;
    if (!seenTracks.add('${key(r.title)}|${key(r.artist)}')) continue;
    result.add(ReviewMatch(
      review: s.review,
      reason: 'Also tagged ${s.shared.take(3).join(', ')}',
    ));
    if (result.length >= limit) break;
  }
  return result;
}
