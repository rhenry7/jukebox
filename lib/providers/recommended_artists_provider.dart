import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/providers/auth_provider.dart';
import 'package:flutter_test_project/services/artist_recommendation_service.dart';

/// Re-export [RecommendedArtist] so UI files only need this one import.
export 'package:flutter_test_project/services/artist_recommendation_service.dart'
    show RecommendedArtist;

/// Fetches AI-powered artist recommendations for the current user.
///
/// Uses OpenAI to analyse the user's review history and suggest new artists,
/// then resolves artist images via MusicBrainz + Cover Art Archive.
/// Results are cached in memory for 15 minutes.
final recommendedArtistsProvider =
    FutureProvider<List<RecommendedArtist>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  debugPrint('[ARTIST_REC_PROVIDER] Fetching artist recommendations for user=$userId');
  return ArtistRecommendationService.getRecommendedArtists(userId);
});
