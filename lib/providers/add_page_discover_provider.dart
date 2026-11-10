import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart' show currentUserIdProvider;
import 'community_reviews_provider.dart';
import 'friends_provider.dart';
import 'reviews_provider.dart' show ReviewWithDocId, userReviewsProvider;

/// A song rated highly by the community, for the Add page's "Highly rated"
/// list. Picking one starts a review of it.
typedef DiscoverTrack = ({
  String title,
  String artist,
  String imageUrl,
  String? spotifyUrl,
  double averageScore,
  int reviewCount,
});

/// Someone to follow, for the Add page's "Suggested reviewers" row.
typedef SuggestedReviewer = ({
  String userId,
  String displayName,
  String? imageUrl,
  int reviewCount,

  /// An artist they've reviewed that the signed-in user has too, if any.
  String? sharedArtist,
});

/// Songs averaging at least this many stars count as "highly rated".
const double highlyRatedMinScore = 4;

/// Ranking blends each song's average with this many neutral reviews, so a
/// single 5★ doesn't outrank a song several people rated 4.5★.
const double _priorReviews = 1;
const double _priorScore = 3.5;

/// The average, pulled toward [_priorScore] when few people rated it.
double _confidentScore(double average, int count) =>
    (average * count + _priorScore * _priorReviews) / (count + _priorReviews);

String _norm(String s) => s.trim().toLowerCase();
String _mainArtist(String artist) => _norm(artist.split(',').first);
String _trackKey(String title, String artist) =>
    '${_norm(title)}|${_mainArtist(artist)}';

/// Highly rated songs in [pool], best first: average stars (weighted by how
/// many rated them, see [_confidentScore]), then newest. Songs in [exclude] (track keys: the user's
/// own reviews) are left out, as are reposts and songs without album art.
@visibleForTesting
List<DiscoverTrack> topRatedTracks(
  List<ReviewWithDocId> pool, {
  Set<String> exclude = const {},
}) {
  final groups = <String, List<ReviewWithDocId>>{};
  for (final r in pool) {
    final review = r.review;
    if (review.isRepost || (review.albumImageUrl ?? '').isEmpty) continue;
    final key = _trackKey(review.title, review.artist);
    if (exclude.contains(key)) continue;
    groups.putIfAbsent(key, () => []).add(r);
  }
  final tracks = <(DiscoverTrack, DateTime)>[];
  for (final reviews in groups.values) {
    final avg =
        reviews.map((r) => r.review.score).reduce((a, b) => a + b) /
        reviews.length;
    if (avg < highlyRatedMinScore) continue;
    // Show the best-rated review's details (and any saved Spotify link).
    final best = [...reviews]
      ..sort((a, b) => b.review.score.compareTo(a.review.score));
    final first = best.first.review;
    final link = best
        .map((r) => r.review.spotifyUrl)
        .firstWhere((u) => (u ?? '').isNotEmpty, orElse: () => null);
    final newest = reviews
        .map((r) => r.review.date ?? DateTime(1970))
        .reduce((a, b) => a.isAfter(b) ? a : b);
    tracks.add((
      (
        title: first.title,
        artist: first.artist,
        imageUrl: first.albumImageUrl!,
        spotifyUrl: link,
        averageScore: avg,
        reviewCount: reviews.length,
      ),
      newest,
    ));
  }
  double rank(DiscoverTrack t) =>
      _confidentScore(t.averageScore, t.reviewCount);
  tracks.sort((a, b) {
    final byScore = rank(b.$1).compareTo(rank(a.$1));
    return byScore != 0 ? byScore : b.$2.compareTo(a.$2);
  });
  return [for (final t in tracks) t.$1];
}

/// Reviewers in [pool] worth following, best first: people who review
/// artists the user also reviews come first, then the most active. Leaves
/// out the user, people they already follow, and anyone in [dismissed].
@visibleForTesting
List<SuggestedReviewer> suggestedReviewers(
  List<ReviewWithDocId> pool, {
  required String? myUserId,
  Set<String> following = const {},
  Set<String> dismissed = const {},
  List<ReviewWithDocId> myReviews = const [],
  int limit = 12,
}) {
  final myArtists = {for (final r in myReviews) _mainArtist(r.review.artist)};
  final byUser = <String, List<ReviewWithDocId>>{};
  for (final r in pool) {
    final uid = r.review.userId;
    if (r.review.isRepost || uid.isEmpty || uid == myUserId) continue;
    if (following.contains(uid) || dismissed.contains(uid)) continue;
    if (r.review.displayName.trim().isEmpty) continue;
    byUser.putIfAbsent(uid, () => []).add(r);
  }
  final scored = <(SuggestedReviewer, double)>[];
  byUser.forEach((uid, reviews) {
    final shared = reviews
        .map((r) => r.review.artist)
        .where((a) => myArtists.contains(_mainArtist(a)))
        .toSet();
    final image = reviews
        .map((r) => r.review.userImageUrl)
        .firstWhere((u) => (u ?? '').isNotEmpty, orElse: () => null);
    scored.add((
      (
        userId: uid,
        displayName: reviews.first.review.displayName,
        imageUrl: image,
        reviewCount: reviews.length,
        sharedArtist: shared.isEmpty
            ? null
            : shared.first.split(',').first.trim(),
      ),
      shared.length * 3 + math.log(reviews.length + 1),
    ));
  });
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  return [for (final s in scored.take(limit)) s.$1];
}

/// Reviewers hidden with ✕ this session.
final dismissedSuggestionsProvider = StateProvider<Set<String>>(
  (ref) => const {},
);

/// Reviewers followed from the Add page this session: they stay in the row
/// (showing "Following") instead of disappearing as soon as they're followed.
final followedFromSuggestionsProvider = StateProvider<Set<String>>(
  (ref) => const {},
);

/// "Highly rated" songs for the Add page, from the Popular reviews already
/// loaded, without songs the user has reviewed.
final addPageTopRatedProvider = Provider.autoDispose<List<DiscoverTrack>?>((
  ref,
) {
  final pool = ref.watch(communityReviewsProvider).valueOrNull;
  if (pool == null) return null;
  final mine = ref.watch(userReviewsProvider).valueOrNull ?? const [];
  return topRatedTracks(
    pool,
    exclude: {for (final r in mine) _trackKey(r.review.title, r.review.artist)},
  );
});

/// "Suggested reviewers" for the Add page.
final addPageSuggestedReviewersProvider =
    Provider.autoDispose<List<SuggestedReviewer>?>((ref) {
      final pool = ref.watch(communityReviewsProvider).valueOrNull;
      if (pool == null) return null;
      return suggestedReviewers(
        pool,
        myUserId: ref.watch(currentUserIdProvider),
        following: {...?ref.watch(friendIdsProvider).valueOrNull}
            .difference(ref.watch(followedFromSuggestionsProvider)),
        dismissed: ref.watch(dismissedSuggestionsProvider),
        myReviews: ref.watch(userReviewsProvider).valueOrNull ?? const [],
      );
    });
