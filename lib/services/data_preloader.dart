import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/providers/preferences_provider.dart';
import 'package:flutter_test_project/providers/recommended_albums_provider.dart';
import 'package:flutter_test_project/providers/recommended_artists_provider.dart';
import 'package:flutter_test_project/providers/popular_tracks_provider.dart';
import 'package:flutter_test_project/providers/recommended_reviews_provider.dart';
import 'package:flutter_test_project/ui/screens/Trending/trending_tracks.dart';

/// Invisible widget that eagerly kicks off data fetches for the Trending
/// and Discovery tabs as soon as the main navigation mounts.
///
/// Wraps the current page body. In [initState] it fires off background reads
/// of key providers so the data is cached by the time the user navigates there.
/// All reads are fire-and-forget with silent error handling — the tab widgets
/// handle their own loading / error states independently.
class DataPreloader extends ConsumerStatefulWidget {
  final Widget child;

  const DataPreloader({super.key, required this.child});

  @override
  ConsumerState<DataPreloader> createState() => _DataPreloaderState();
}

class _DataPreloaderState extends ConsumerState<DataPreloader> {
  bool _preloaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_preloaded) {
        _preloaded = true;
        _preloadData();
      }
    });
  }

  Future<void> _preloadData() async {
    debugPrint('[PRELOADER] Starting background data preload...');

    // 1. Kick off recommended reviews (feeds into albums provider)
    try {
      // ignore: unused_local_variable
      final _ = ref.read(recommendedReviewsProvider.future);
      debugPrint('[PRELOADER] Triggered recommendedReviewsProvider');
    } catch (e) {
      debugPrint('[PRELOADER] recommendedReviewsProvider trigger failed: $e');
    }

    // 2. Kick off recommended albums (derived from reviews, starts when reviews resolve)
    try {
      // ignore: unused_local_variable
      final _ = ref.read(recommendedAlbumsProvider.future);
      debugPrint('[PRELOADER] Triggered recommendedAlbumsProvider');
    } catch (e) {
      debugPrint('[PRELOADER] recommendedAlbumsProvider trigger failed: $e');
    }

    // 3. Kick off AI-powered artist recommendations (independent call)
    try {
      // ignore: unused_local_variable
      final _ = ref.read(recommendedArtistsProvider.future);
      debugPrint('[PRELOADER] Triggered recommendedArtistsProvider');
    } catch (e) {
      debugPrint('[PRELOADER] recommendedArtistsProvider trigger failed: $e');
    }

    // 4. Kick off globally popular tracks (no user dependency)
    try {
      // ignore: unused_local_variable
      final _ = ref.read(popularTracksProvider.future);
      debugPrint('[PRELOADER] Triggered popularTracksProvider');
    } catch (e) {
      debugPrint('[PRELOADER] popularTracksProvider trigger failed: $e');
    }

    // 5. Kick off user preferences, then use the result to trigger trending tracks
    try {
      final preferences = await ref.read(userPreferencesProvider.future);
      debugPrint('[PRELOADER] Preferences loaded, triggering trendingTracksProvider');
      // ignore: unused_local_variable
      final _ = ref.read(trendingTracksProvider(preferences).future);
    } catch (e) {
      debugPrint('[PRELOADER] trendingTracksProvider trigger failed: $e');
    }

    debugPrint('[PRELOADER] All background fetches triggered');
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
