import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/review.dart';
import '../ui/widgets/genre_pills.dart' show splitGenreTags;
import 'cache_first.dart';
import 'community_reviews_provider.dart';
import 'reviews_provider.dart' show ReviewWithDocId, firestoreProvider;
import 'tag_reviews_provider.dart' show normalizeTag;

/// The Home row's sort choice, shared by Popular, Friends and For You.
enum HomeSort {
  /// Each tab's own order: shuffled (Popular), newest (Friends), best match
  /// (For You).
  standard('Default'),
  recent('Most recent'),
  ratingHigh('Rating: high to low'),
  ratingLow('Rating: low to high');

  const HomeSort(this.label);
  final String label;
}

final homeSortProvider = StateProvider<HomeSort>((ref) => HomeSort.standard);

/// Tags picked in the Home row's carousel, as [normalizeTag] keys. Empty
/// means no filter. A review matches if it has any of them.
final homeTagFilterProvider = StateProvider<Set<String>>((ref) => const {});

/// How many tags the carousel offers.
const int homeTagChoiceCount = 40;

/// The carousel's tags: the [homeTagChoiceCount] most used tags in the
/// Popular pool (the newest reviews), in a random order picked once per
/// session. Empty until Popular has loaded.
final homeTagChoicesProvider = Provider<List<String>>((ref) {
  final pool = ref.watch(communityReviewsProvider).valueOrNull;
  if (pool == null) return const [];
  return tagChoicesFrom(
    [for (final r in pool) r.review],
    seed: ref.watch(_sessionSeedProvider),
  );
});

final _sessionSeedProvider =
    Provider<int>((ref) => math.Random().nextInt(1 << 31));

/// The [count] most used tags across [reviews], shuffled by [seed]. Tags are
/// counted by their [normalizeTag] key, so spellings like "R&B" and "rnb"
/// add up as one; the first spelling seen is shown.
@visibleForTesting
List<String> tagChoicesFrom(
  List<Review> reviews, {
  required int seed,
  int count = homeTagChoiceCount,
}) {
  final counts = <String, int>{};
  final spelling = <String, String>{};
  for (final r in reviews) {
    final keysInReview = <String>{};
    for (final tag in splitGenreTags(r.genres)) {
      final key = normalizeTag(tag);
      if (key.isEmpty || !keysInReview.add(key)) continue;
      spelling.putIfAbsent(key, () => tag);
      counts[key] = (counts[key] ?? 0) + 1;
    }
  }
  final keys = counts.keys.toList();
  final firstSeen = {for (var i = 0; i < keys.length; i++) keys[i]: i};
  keys.sort((a, b) {
    final byCount = counts[b]!.compareTo(counts[a]!);
    return byCount != 0 ? byCount : firstSeen[a]!.compareTo(firstSeen[b]!);
  });
  return [for (final k in keys.take(count)) spelling[k]!]
    ..shuffle(math.Random(seed));
}

/// Whether [review] has any of the tags in [keys] (normalized). An empty
/// [keys] matches everything.
bool matchesTagFilter(Review review, Set<String> keys) {
  if (keys.isEmpty) return true;
  return splitGenreTags(review.genres)
      .any((tag) => keys.contains(normalizeTag(tag)));
}

/// [items] in [sort]'s order (a copy). [HomeSort.standard] keeps the given
/// order. Ties keep the given order too.
List<T> applyHomeSort<T>(
  List<T> items,
  HomeSort sort,
  Review Function(T) reviewOf,
) {
  if (sort == HomeSort.standard) return items;
  int byDate(T a, T b) {
    final da = reviewOf(a).date, db = reviewOf(b).date;
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return db.compareTo(da);
  }

  final indexed = [for (var i = 0; i < items.length; i++) (i, items[i])];
  indexed.sort((a, b) {
    final x = a.$2, y = b.$2;
    final c = switch (sort) {
      HomeSort.recent => byDate(x, y),
      HomeSort.ratingHigh => reviewOf(y).score.compareTo(reviewOf(x).score),
      HomeSort.ratingLow => reviewOf(x).score.compareTo(reviewOf(y).score),
      HomeSort.standard => 0,
    };
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}

/// How many reviews Popular reads for a tag filter.
const int popularFilterLimit = 100;

/// Popular filtered by tags: the newest [popularFilterLimit] reviews with any
/// of the tags, through the tag index (`tagKeys`), so it covers every review,
/// not just the shuffled pool. [keys] is the sorted keys joined by '\n' (a
/// value the provider family can compare).
final popularTagFilterProvider = FutureProvider.autoDispose
    .family<List<ReviewWithDocId>, String>((ref, keys) async {
  ref.keepAliveFor();
  final values = keys.split('\n').where((k) => k.isNotEmpty).take(30).toList();
  if (values.isEmpty) return const [];
  final snapshot = await ref
      .watch(firestoreProvider)
      .collectionGroup('reviews')
      .where('tagKeys', arrayContainsAny: values)
      .orderBy('date', descending: true)
      .limit(popularFilterLimit)
      .get();
  return [
    for (final doc in snapshot.docs)
      if (_readable(doc) case final item?)
        if (!item.review.isRepost && isPopularEligible(item.review)) item,
  ];
});

ReviewWithDocId? _readable(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
  try {
    return ReviewWithDocId(
      review: Review.fromFirestore(doc.data()),
      docId: doc.id,
      fullReviewId: doc.reference.path,
    );
  } catch (e) {
    debugPrint('[HOME_FILTER] Skipping unreadable review ${doc.id}: $e');
    return null;
  }
}

/// [keys] as the [popularTagFilterProvider] family key.
String tagFilterKey(Set<String> keys) => (keys.toList()..sort()).join('\n');
