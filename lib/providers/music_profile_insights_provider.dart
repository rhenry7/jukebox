import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/providers/auth_provider.dart';
import 'package:flutter_test_project/providers/reviews_provider.dart';
import 'package:flutter_test_project/services/music_profile_insights_service.dart';

/// Provider for music profile insights (favorite artists, genres, most common album)
final musicProfileInsightsProvider = FutureProvider<MusicProfileInsights>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  
  if (userId == null) {
    return MusicProfileInsights(
      favoriteArtists: [],
      favoriteGenres: [],
      mostCommonAlbum: null,
    );
  }
  
  return MusicProfileInsightsService.getProfileInsights(userId);
});

/// Provider that auto-refreshes when reviews change
final musicProfileInsightsAutoProvider = FutureProvider<MusicProfileInsights>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  
  // Watch reviews to trigger refresh when they change
  ref.watch(userReviewsProvider);
  
  if (userId == null) {
    return MusicProfileInsights(
      favoriteArtists: [],
      favoriteGenres: [],
      mostCommonAlbum: null,
    );
  }
  
  return MusicProfileInsightsService.getProfileInsights(userId);
});
