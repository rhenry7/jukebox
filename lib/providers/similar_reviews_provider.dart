import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/review.dart';
import 'reviews_provider.dart' show ReviewWithDocId, firestoreProvider;
import 'cache_first.dart';
import 'tag_reviews_provider.dart' show searchKeysFor;

/// How many similar reviews the review page shows.
const int similarReviewCount = 5;

/// Reviews read per query when looking for similar ones. Enough to rank by
/// shared tags without reading the whole corpus.
const int _similarPoolSize = 40;

/// Firestore caps `arrayContainsAny` at 30 values.
const int _maxQueryKeys = 30;

/// The review whose page is showing. Plain strings so the provider family
/// can compare them by value.
typedef SimilarReviewsKey = ({
  String? path,
  String title,
  String artist,
  String tags,
});

SimilarReviewsKey similarReviewsKeyFor(Review review, String? path) => (
      path: path,
      title: review.title,
      artist: review.artist,
      tags: (review.genres ?? const []).join('\n'),
    );

/// Up to [similarReviewCount] other reviews tagged like this one, for the
/// "More like this" row on the review page. Uses the tag page's index
/// (`tagKeys`, then `tagWordKeys`), so it costs a query or two and no AI.
///
/// Answers from the on-device cache first when it has matches, then from
/// the server. Kept for a few minutes, and started when a card is touched
/// (see `ReviewCardWidget`), so it's usually ready when the page opens.
final similarReviewsProvider = StreamProvider.autoDispose
    .family<List<ReviewWithDocId>, SimilarReviewsKey>((ref, key) async* {
  ref.keepAliveFor();
  final db = ref.watch(firestoreProvider);
  try {
    final cached = await findSimilarReviews(db, key, source: Source.cache);
    if (cached.isNotEmpty) yield cached;
  } catch (_) {
    // Nothing cached yet.
  }
  yield await findSimilarReviews(db, key);
});

/// Ranks candidates by how many tags they share with the review (exact tags
/// count double, shared tag words once), then newest first. Leaves out the
/// review itself, reposts, other reviews of the same track and repeats of a
/// track.
@visibleForTesting
Future<List<ReviewWithDocId>> findSimilarReviews(
  FirebaseFirestore db,
  SimilarReviewsKey key, {
  Source source = Source.serverAndCache,
}) async {
  final keys = searchKeysFor(genres: key.tags.split('\n'));
  final tagKeys = keys['tagKeys']!.take(_maxQueryKeys).toList();
  final wordKeys = keys['tagWordKeys']!.take(_maxQueryKeys).toList();
  if (tagKeys.isEmpty) return const [];

  String track(String title, String artist) =>
      '${title.trim().toLowerCase()}|${artist.trim().toLowerCase()}';
  final ownTrack = track(key.title, key.artist);
  final seenTracks = <String>{ownTrack};
  final scored = <({ReviewWithDocId item, int score})>[];

  Future<void> collect(String field, List<String> values) async {
    if (values.isEmpty) return;
    final snapshot = await db
        .collectionGroup('reviews')
        .where(field, arrayContainsAny: values)
        .orderBy('date', descending: true)
        .limit(_similarPoolSize)
        .get(GetOptions(source: source));
    for (final doc in snapshot.docs) {
      if (doc.reference.path == key.path) continue;
      final ReviewWithDocId item;
      try {
        item = ReviewWithDocId(
          review: Review.fromFirestore(doc.data()),
          docId: doc.id,
          fullReviewId: doc.reference.path,
        );
      } catch (e) {
        debugPrint('[SIMILAR] Skipping unreadable review ${doc.id}: $e');
        continue;
      }
      final r = item.review;
      if (r.isRepost) continue;
      if (!seenTracks.add(track(r.title, r.artist))) continue;
      final theirs = searchKeysFor(genres: r.genres);
      final sharedTags = theirs['tagKeys']!.where(tagKeys.contains).length;
      final sharedWords =
          theirs['tagWordKeys']!.where(wordKeys.contains).length;
      scored.add((item: item, score: sharedTags * 2 + sharedWords));
    }
  }

  await collect('tagKeys', tagKeys);
  // Too few exact matches: widen to reviews whose tags share a word
  // ("indie rock" for "indie pop").
  if (scored.length < similarReviewCount) {
    await collect('tagWordKeys', wordKeys);
  }

  // Stable sort keeps the queries' newest-first order within a score.
  final ranked = [...scored];
  mergeSort(ranked, compare: (a, b) => b.score.compareTo(a.score));
  return [for (final s in ranked.take(similarReviewCount)) s.item];
}
