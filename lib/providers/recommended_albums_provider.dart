import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/providers/recommended_reviews_provider.dart';
import 'package:flutter_test_project/services/get_album_service.dart';
import 'package:flutter_test_project/services/review_recommendation_service.dart';

/// Album-level recommendation derived from community reviews.
class AlbumRecommendation {
  final String title;
  final String artist;
  final String albumImageUrl;
  final List<String> genres;
  final double averageScore;
  final int reviewCount;

  const AlbumRecommendation({
    required this.title,
    required this.artist,
    required this.albumImageUrl,
    required this.genres,
    required this.averageScore,
    required this.reviewCount,
  });
}

/// Derives album-level recommendations from the existing [recommendedReviewsProvider].
///
/// Groups reviews by (artist, title), computes aggregate stats, and returns
/// the top 15 sorted by review count then average score. No new API calls.
final recommendedAlbumsProvider =
    FutureProvider<List<AlbumRecommendation>>((ref) async {
  final reviews = await ref.watch(recommendedReviewsProvider.future);
  if (reviews.isEmpty) return [];

  // Group reviews by normalized (artist, title) key
  final groups = <String, List<ScoredReview>>{};
  for (final scored in reviews) {
    final r = scored.reviewWithDocId.review;
    final key =
        '${r.artist.trim().toLowerCase()}||${r.title.trim().toLowerCase()}';
    groups.putIfAbsent(key, () => []).add(scored);
  }

  // Build album recommendations from groups
  final albums = groups.entries.map((entry) {
    final groupReviews = entry.value;
    final first = groupReviews.first.reviewWithDocId.review;

    final totalScore =
        groupReviews.fold<double>(0, (sum, s) => sum + s.reviewWithDocId.review.score);
    final avgScore = totalScore / groupReviews.length;

    // Collect unique genres across all reviews in the group
    final genreSet = <String>{};
    for (final s in groupReviews) {
      final g = s.reviewWithDocId.review.genres;
      if (g != null) genreSet.addAll(g);
    }

    return AlbumRecommendation(
      title: first.title,
      artist: first.artist,
      albumImageUrl: first.albumImageUrl ?? '',
      genres: genreSet.toList(),
      averageScore: avgScore,
      reviewCount: groupReviews.length,
    );
  }).toList();

  // Sort by review count descending, then average score descending
  albums.sort((a, b) {
    final countCmp = b.reviewCount.compareTo(a.reviewCount);
    if (countCmp != 0) return countCmp;
    return b.averageScore.compareTo(a.averageScore);
  });

  return albums.take(15).toList();
});

/// Fetches release-level info (date + country) from MusicBrainz on demand.
///
/// Keyed by `(artist: ..., title: ...)` so each album is fetched once.
final albumReleaseInfoProvider = FutureProvider.family<MusicBrainzAlbum?,
    ({String artist, String title})>((ref, params) {
  return MusicBrainzService.searchReleaseByTitleAndArtist(
    params.title,
    params.artist,
  );
});
