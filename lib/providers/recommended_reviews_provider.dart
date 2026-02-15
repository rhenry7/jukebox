import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/providers/auth_provider.dart';
import 'package:flutter_test_project/providers/preferences_provider.dart';
import 'package:flutter_test_project/services/review_recommendation_service.dart';

/// Fetches personalized review recommendations for the current user.
///
/// Uses the NLP-based recommendation engine (taste profile + embeddings).
/// Depends on [userPreferencesStreamProvider] so when the user updates their
/// preferences in Profile, recommendations refresh automatically.
/// Auto-disposes when the widget tree no longer listens.
final recommendedReviewsProvider =
    FutureProvider.autoDispose<List<ScoredReview>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  // Refetch when preferences change (e.g. genre weights updated in Profile)
  ref.watch(userPreferencesStreamProvider);

  debugPrint('[REC_PROVIDER] Fetching recommendations for user=$userId');
  return ReviewRecommendationService.getRecommendedReviews(userId);
});

/// Display limit for lazy-loading recommended reviews (starts at 10).
final recommendedReviewsDisplayLimitProvider = StateProvider<int>((ref) => 10);

/// Increments the display limit by 10 to show more recommendations.
final loadMoreRecommendedReviewsProvider = Provider<void Function()>((ref) {
  return () {
    final current = ref.read(recommendedReviewsDisplayLimitProvider);
    ref.read(recommendedReviewsDisplayLimitProvider.notifier).state =
        current + 10;
  };
});

/// Force-refreshes recommendations (bypasses cache) and invalidates the provider.
final refreshRecommendationsProvider =
    Provider<Future<void> Function()>((ref) {
  return () async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    debugPrint('[REC_PROVIDER] Force-refreshing recommendations');
    await ReviewRecommendationService.getRecommendedReviews(
      userId,
      forceRefresh: true,
    );
    ref.invalidate(recommendedReviewsProvider);
  };
});
