import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/review.dart';
import 'reviews_provider.dart' show ReviewWithDocId, firestoreProvider;
import 'cache_first.dart';
import 'tag_reviews_provider.dart' show searchKeysFor;

/// How many similar reviews the review page shows.
const int similarReviewCount = 5;

/// Reviews read per query when looking for similar ones. Enough to rank
/// without reading the whole corpus.
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
  String artistMbids,
});

SimilarReviewsKey similarReviewsKeyFor(Review review, String? path) => (
  path: path,
  title: review.title,
  artist: review.artist,
  tags: (review.genres ?? const []).join('\n'),
  artistMbids: review.artistMbids.join('\n'),
);

/// Why a review is in "More like this", shown as a chip on its card.
enum SimilarReason {
  sameArtist('Same artist'),
  similarArtist('Similar artist'),
  similarSong('Similar song'),
  sharedTags('Shared tags'),
  readsAlike('Reads alike');

  const SimilarReason(this.label);
  final String label;
}

/// A review in "More like this", and why (null when it came from the
/// app-side fallback, which doesn't give reasons).
typedef SimilarReview = ({ReviewWithDocId item, SimilarReason? reason});

/// Up to [similarReviewCount] other reviews like this one, for the "More like
/// this" row on the review page.
///
/// Normally the list Cloud Functions keeps in `similarReviews/{reviewDocId}`
/// (functions/src/similar.ts): reviews scored on similar artists and songs
/// (ListenBrainz), rare shared tags and how alike the reviews read, each
/// with a reason. Reviews without that list yet (just posted, or before the
/// backfill) fall back to [findSimilarReviews]: shared tags and similar
/// artists, through the tag index and `artistMbids`.
///
/// Answers from the on-device cache first, then from the server. Kept for a
/// few minutes, and started when a card is touched (see `ReviewCardWidget`),
/// so it's usually ready when the page opens.
final similarReviewsProvider = StreamProvider.autoDispose
    .family<List<SimilarReview>, SimilarReviewsKey>((ref, key) async* {
  ref.keepAliveFor();
  final db = ref.watch(firestoreProvider);
  if (key.path != null) {
    var found = false;
    try {
      final doc = db
          .collection('similarReviews')
          .doc(key.path!.replaceAll('/', '__'));
      await for (final snap in docCacheThenServer(doc)) {
        final list = await readServerSimilar(db, key, snap.data(),
            source: snap.metadata.isFromCache
                ? Source.cache
                : Source.serverAndCache);
        if (list.isNotEmpty) {
          found = true;
          yield list;
        }
      }
    } catch (e) {
      debugPrint('[SIMILAR] Server list unavailable: $e');
    }
    if (found) return;
  }
  List<SimilarReview> plain(List<ReviewWithDocId> items) =>
      [for (final item in items) (item: item, reason: null)];
  try {
    final cached = await findSimilarReviews(db, key, source: Source.cache);
    if (cached.isNotEmpty) yield plain(cached);
  } catch (_) {
    // Nothing cached yet.
  }
  yield plain(await findSimilarReviews(db, key));
});

/// The reviews a `similarReviews` doc lists, up to [similarReviewCount],
/// skipping any that were deleted or can't be read. Empty if the doc has no
/// list.
@visibleForTesting
Future<List<SimilarReview>> readServerSimilar(
  FirebaseFirestore db,
  SimilarReviewsKey key,
  Map<String, dynamic>? doc, {
  Source source = Source.serverAndCache,
}) async {
  final items = doc?['items'];
  if (items is! List) return const [];
  final wanted = [
    for (final i in items)
      if (i is Map && i['reviewPath'] is String) i,
  ].take(similarReviewCount + 3).toList(); // spares for deleted reviews
  final snaps = await Future.wait([
    for (final i in wanted)
      db
          .doc(i['reviewPath'] as String)
          .get(GetOptions(source: source))
          .then<DocumentSnapshot<Map<String, dynamic>>?>((d) => d)
          .catchError((Object _) => null),
  ]);
  final out = <SimilarReview>[];
  for (var n = 0; n < wanted.length && out.length < similarReviewCount; n++) {
    final snap = snaps[n];
    final data = snap?.data();
    if (snap == null || data == null) continue;
    final Review review;
    try {
      review = Review.fromFirestore(data);
    } catch (e) {
      debugPrint('[SIMILAR] Skipping unreadable review ${snap.id}: $e');
      continue;
    }
    out.add((
      item: ReviewWithDocId(
          review: review, docId: snap.id, fullReviewId: snap.reference.path),
      reason: _reasonFor(wanted[n]['reason'], review, key),
    ));
  }
  return out;
}

/// The server's reason code as a chip. "artist" covers both the same artist
/// and a similar one; tell them apart here.
SimilarReason? _reasonFor(Object? code, Review review, SimilarReviewsKey key) {
  switch (code) {
    case 'artist':
      final mine = key.artistMbids.split('\n').where((id) => id.isNotEmpty);
      final same = review.artistMbids.any(mine.contains) ||
          _mainArtist(review.artist) == _mainArtist(key.artist);
      return same ? SimilarReason.sameArtist : SimilarReason.similarArtist;
    case 'song':
      return SimilarReason.similarSong;
    case 'tags':
      return SimilarReason.sharedTags;
    case 'text':
      return SimilarReason.readsAlike;
  }
  return null;
}

String _mainArtist(String artist) =>
    artist.split(',').first.trim().toLowerCase();

/// How much a review by a similar artist counts, at full similarity, in
/// shared-tag points (an exact shared tag is 2).
const double _artistWeight = 4;

/// Another song by the same artist counts like a very similar artist.
const double _sameArtistScore = 0.9;

/// Ranks candidates by shared tags (exact tags 2 points, shared tag words 1)
/// plus artist similarity (up to [_artistWeight]), then newest first. Leaves
/// out the review itself, reposts, other reviews of the same track and
/// repeats of a track.
@visibleForTesting
Future<List<ReviewWithDocId>> findSimilarReviews(
  FirebaseFirestore db,
  SimilarReviewsKey key, {
  Source source = Source.serverAndCache,
}) async {
  final keys = searchKeysFor(genres: key.tags.split('\n'));
  final tagKeys = keys['tagKeys']!.take(_maxQueryKeys).toList();
  final wordKeys = keys['tagWordKeys']!.take(_maxQueryKeys).toList();
  final ownArtists = key.artistMbids
      .split('\n')
      .where((id) => id.isNotEmpty)
      .toList();
  final artistScores = await _similarArtistScores(db, ownArtists, source);
  if (tagKeys.isEmpty && artistScores.isEmpty) return const [];

  String track(String title, String artist) =>
      '${title.trim().toLowerCase()}|${artist.trim().toLowerCase()}';
  final ownTrack = track(key.title, key.artist);
  // Query order (newest first) is kept for ties, so remember arrival order.
  final found = <String, ({ReviewWithDocId item, double score, int order})>{};

  Future<void> collect(String field, List<String> values) async {
    if (values.isEmpty) return;
    final snapshot = await db
        .collectionGroup('reviews')
        .where(field, arrayContainsAny: values)
        .orderBy('date', descending: true)
        .limit(_similarPoolSize)
        .get(GetOptions(source: source));
    for (final doc in snapshot.docs) {
      final path = doc.reference.path;
      if (path == key.path || found.containsKey(path)) continue;
      final ReviewWithDocId item;
      try {
        item = ReviewWithDocId(
          review: Review.fromFirestore(doc.data()),
          docId: doc.id,
          fullReviewId: path,
        );
      } catch (e) {
        debugPrint('[SIMILAR] Skipping unreadable review ${doc.id}: $e');
        continue;
      }
      final r = item.review;
      if (r.isRepost || track(r.title, r.artist) == ownTrack) continue;
      final theirs = searchKeysFor(genres: r.genres);
      final sharedTags = theirs['tagKeys']!.where(tagKeys.contains).length;
      final sharedWords = theirs['tagWordKeys']!
          .where(wordKeys.contains)
          .length;
      var artist = 0.0;
      for (final id in r.artistMbids) {
        artist = math.max(artist, artistScores[id] ?? 0);
      }
      found[path] = (
        item: item,
        score: sharedTags * 2 + sharedWords + artist * _artistWeight,
        order: found.length,
      );
    }
  }

  await collect('tagKeys', tagKeys);
  // The closest-sounding artists (Firestore allows 30 values per query).
  final topArtists =
      (artistScores.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .take(_maxQueryKeys)
          .map((e) => e.key)
          .toList();
  await collect('artistMbids', topArtists);
  // Too few matches: widen to reviews whose tags share a word ("indie rock"
  // for "indie pop").
  if (found.length < similarReviewCount) {
    await collect('tagWordKeys', wordKeys);
  }

  final ranked = found.values.toList()
    ..sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.order.compareTo(b.order);
    });
  final seenTracks = <String>{};
  return [
    for (final s in ranked)
      if (seenTracks.add(track(s.item.review.title, s.item.review.artist)))
        s.item,
  ].take(similarReviewCount).toList();
}

/// Artist ID → 0–1 similarity to any of [artistMbids], from the cached
/// ListenBrainz lists; the artists themselves count as
/// [_sameArtistScore]. Empty if none are cached.
Future<Map<String, double>> _similarArtistScores(
  FirebaseFirestore db,
  List<String> artistMbids,
  Source source,
) async {
  final scores = <String, double>{};
  for (final id in artistMbids) {
    scores[id] = _sameArtistScore;
  }
  final docs = await Future.wait([
    for (final id in artistMbids)
      db
          .collection('similarArtists')
          .doc(id)
          .get(GetOptions(source: source))
          .then<DocumentSnapshot<Map<String, dynamic>>?>((d) => d)
          .catchError((Object _) => null),
  ]);
  var anyCached = false;
  for (final doc in docs) {
    final similar = doc?.data()?['similar'];
    if (similar is! List) continue;
    anyCached = true;
    for (final s in similar) {
      if (s is! Map) continue;
      final id = s['mbid'], score = s['score'];
      if (id is! String || score is! num) continue;
      if (artistMbids.contains(id)) continue;
      scores[id] = math.max(scores[id] ?? 0, score.toDouble());
    }
  }
  // Without the similar lists, same-artist alone isn't worth a query.
  return anyCached ? scores : const {};
}
