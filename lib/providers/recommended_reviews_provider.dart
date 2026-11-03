import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/providers/auth_provider.dart';
import 'package:flutter_test_project/services/for_you_service.dart';
import 'package:flutter_test_project/services/review_recommendation_service.dart';

/// Personalized review recommendations for the current user.
///
/// Reads the list the server builds after each review (CF-RAG over the whole
/// corpus, cached at users/{uid}/forYou/current) and updates live when it is
/// rebuilt. Until that list exists — a brand-new user, or the backend not
/// deployed yet — it falls back to on-device ranking.
final recommendedReviewsProvider =
    StreamProvider<List<ScoredReview>>((ref) async* {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    yield [];
    return;
  }

  debugPrint('[REC_PROVIDER] Watching For You for user=$userId');
  try {
    await for (final items in ForYouService.watch(userId)) {
      yield items ??
          await ReviewRecommendationService.getRecommendedReviews(userId);
    }
  } catch (e) {
    // e.g. rules not deployed yet → permission-denied. Never leave the tab empty.
    debugPrint('[REC_PROVIDER] For You cache unavailable ($e); using local ranking');
    yield await ReviewRecommendationService.getRecommendedReviews(userId);
  }
});

/// Display limit for lazy-loading recommended reviews (starts at 10).
final recommendedReviewsDisplayLimitProvider = StateProvider<int>((ref) => 5);

/// Increments the display limit by 10 to show more recommendations.
final loadMoreRecommendedReviewsProvider = Provider<void Function()>((ref) {
  return () {
    final current = ref.read(recommendedReviewsDisplayLimitProvider);
    ref.read(recommendedReviewsDisplayLimitProvider.notifier).state =
        current + 10;
  };
});

/// Pull-to-refresh: asks the server to rebuild the list (the stream above
/// picks up the new version). If the backend isn't reachable, re-runs the
/// on-device ranking instead.
final refreshRecommendationsProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    debugPrint('[REC_PROVIDER] Refreshing recommendations');
    if (await ForYouService.refresh()) return;
    ReviewRecommendationService.clearCache(userId);
    ref.invalidate(recommendedReviewsProvider);
  };
});
