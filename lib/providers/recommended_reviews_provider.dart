import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/providers/auth_provider.dart';
import 'package:flutter_test_project/providers/preferences_provider.dart';
import 'package:flutter_test_project/services/new_recommendation_service.dart';
import 'package:flutter_test_project/services/review_recommendation_service.dart';

/// Fetches personalized review recommendations for the current user.
///
/// Uses a simple, uncached service:
/// - read all community reviews
/// - keep reviews matching user's favorite genres
/// Depends on [userPreferencesStreamProvider] so when preferences change,
/// recommendations recompute.
final recommendedReviewsProvider =
    FutureProvider.autoDispose<List<ScoredReview>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  // Refetch when preferences change (e.g. genre weights updated in Profile)
  final prefsAsync = ref.watch(userPreferencesStreamProvider);
  final prefsLastUpdated = prefsAsync.asData?.value.lastUpdated;

  debugPrint('[REC_PROVIDER] Fetching recommendations for user=$userId '
      '(prefsLastUpdated=$prefsLastUpdated)');
  return NewRecommendationService.getRecommendedReviews(
    userId,
  );
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
    await NewRecommendationService.getRecommendedReviews(
      userId,
    );
    ref.invalidate(recommendedReviewsProvider);
  };
});
