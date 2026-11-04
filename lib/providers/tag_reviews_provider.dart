import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/review.dart';
import '../ui/widgets/genre_pills.dart' show rankTags, splitGenreTags;
import 'reviews_provider.dart' show ReviewWithDocId;

/// How many of the newest reviews the tag page searches.
const int tagPoolSize = 500;

/// How many related tags the tag page offers.
const int relatedTagCount = 8;

/// Reviews for one tag, and the tags people use alongside it.
typedef TagReviews = ({
  List<ReviewWithDocId> exact,
  List<ReviewWithDocId> similar,
  List<String> related,
});

/// Reviews tagged [tag] (or something like it) among the newest
/// [tagPoolSize], for the tag page.
final tagReviewsProvider =
    FutureProvider.autoDispose.family<TagReviews, String>((ref, tag) async {
  final snapshot = await FirebaseFirestore.instance
      .collectionGroup('reviews')
      .orderBy('date', descending: true)
      .limit(tagPoolSize)
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
      debugPrint('[TAG_PAGE] Skipping unreadable review ${doc.id}: $e');
    }
  }
  return groupByTag(tag, pool);
});

/// Splits [candidates] into reviews tagged exactly [tag] and reviews with a
/// similar tag (see [tagsSimilar]), each newest first, skipping reposts.
/// [related] is the other tags on those reviews, most used first.
@visibleForTesting
TagReviews groupByTag(String tag, List<ReviewWithDocId> candidates) {
  final want = normalizeTag(tag);
  final exact = <ReviewWithDocId>[];
  final similar = <ReviewWithDocId>[];
  final matchedTags = <List<String>>[];

  for (final c in candidates) {
    if (c.review.isRepost) continue;
    final tags = splitGenreTags(c.review.genres);
    final keys = tags.map(normalizeTag);
    if (keys.contains(want)) {
      exact.add(c);
    } else if (keys.any((k) => tagsSimilar(want, k))) {
      similar.add(c);
    } else {
      continue;
    }
    matchedTags.add(tags);
  }

  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  int newest(ReviewWithDocId a, ReviewWithDocId b) =>
      (b.review.date ?? epoch).compareTo(a.review.date ?? epoch);
  exact.sort(newest);
  similar.sort(newest);

  return (
    exact: exact,
    similar: similar,
    related: rankTags(matchedTags)
        .where((t) => normalizeTag(t) != want)
        .take(relatedTagCount)
        .toList(),
  );
}

/// Words too generic to make two tags similar on their own.
const Set<String> _genericWords = {'music', 'and', 'the', 'of', 'song', 'songs'};

/// Lowercase, with spelling variants folded together: "R&B", "rnb" and
/// "R and B" → "r&b"; "hip-hop" and "hiphop" → "hip hop".
String normalizeTag(String tag) {
  var t = tag.toLowerCase().trim().replaceAll(RegExp(r'[-_]+'), ' ');
  t = t.replaceAll(RegExp(r'\s+'), ' ');
  t = t.replaceAll(RegExp(r'\b(rnb|r ?n ?b|r and b|r ?& ?b)\b'), 'r&b');
  t = t.replaceAll(RegExp(r'\bhiphop\b'), 'hip hop');
  return t;
}

/// True when two normalized tags are related: one contains the other as
/// whole words ("r&b" / "alternative r&b"), or they share a meaningful word
/// ("chill dance" / "relaxing dance").
bool tagsSimilar(String a, String b) {
  if (a == b) return true;
  final wordsA = a.split(' ');
  final wordsB = b.split(' ');
  bool containsWords(List<String> outer, List<String> inner) {
    for (var i = 0; i + inner.length <= outer.length; i++) {
      if (listEquals(outer.sublist(i, i + inner.length), inner)) return true;
    }
    return false;
  }

  if (containsWords(wordsA, wordsB) || containsWords(wordsB, wordsA)) {
    return true;
  }
  final meaningful = wordsA.where((w) => !_genericWords.contains(w)).toSet();
  return wordsB.any(meaningful.contains);
}
