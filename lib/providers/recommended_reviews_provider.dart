import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/providers/auth_provider.dart';
import 'package:flutter_test_project/providers/reviews_provider.dart'
    show ReviewWithDocId, firestoreProvider;
import 'package:flutter_test_project/services/for_you_service.dart';
import 'package:flutter_test_project/services/review_recommendation_service.dart';

/// The For You list: the recommendations loaded so far, in ranked order, and
/// how many the whole list has (for "load more").
typedef ForYouFeed = ({List<ScoredReview> loaded, int total});

/// The server-built list (review paths only), live. Null when there's none.
final _forYouEntriesProvider =
    StreamProvider.family<List<ForYouEntry>?, String>(
        (ref, userId) => ForYouService.watchEntries(
              userId,
              db: ref.watch(firestoreProvider),
            ));

/// Reviews already fetched for For You, by path (null = deleted since the
/// list was built), so a rebuilt list or "load more" only fetches new ones.
/// Cleared on sign-in changes and pull-to-refresh.
final _forYouReviewCacheProvider =
    Provider<Map<String, ReviewWithDocId?>>((ref) {
  ref.watch(currentUserIdProvider);
  return {};
});

/// True after a pull-to-refresh: For You then reads reviews from the server
/// rather than the device, so edits show.
final _forYouFromServerProvider = StateProvider<bool>((ref) => false);

/// Personalized review recommendations for the current user.
///
/// Reads the list the server builds after each review (CF-RAG over the whole
/// corpus, cached at users/{uid}/forYou/current) and updates live when it is
/// rebuilt. Only the reviews up to [recommendedReviewsDisplayLimitProvider]
/// are fetched; scrolling raises the limit. Cards show as their reviews
/// arrive, in ranked order: one that arrives early waits for those above
/// it, so nothing jumps. Until the list exists — a brand-new user, or the
/// backend not deployed yet — it falls back to on-device ranking.
final recommendedReviewsProvider = StreamProvider<ForYouFeed>((ref) async* {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    yield (loaded: const <ScoredReview>[], total: 0);
    return;
  }

  List<ForYouEntry>? entries;
  try {
    entries = await ref.watch(_forYouEntriesProvider(userId).future);
  } catch (e) {
    // e.g. rules not deployed yet → permission-denied. Never leave the tab empty.
    debugPrint(
        '[REC_PROVIDER] For You cache unavailable ($e); using local ranking');
  }
  if (entries == null) {
    final local =
        await ReviewRecommendationService.getRecommendedReviews(userId);
    yield (loaded: local, total: local.length);
    return;
  }

  final total = entries.length;
  final shown =
      entries.take(ref.watch(recommendedReviewsDisplayLimitProvider)).toList();
  final cache = ref.watch(_forYouReviewCacheProvider);
  final preferCache = !ref.watch(_forYouFromServerProvider);
  final db = ref.read(firestoreProvider);

  // The cards from the top down to the first review not fetched yet
  // (deleted reviews are skipped).
  ForYouFeed ready() {
    final loaded = <ScoredReview>[];
    for (final e in shown) {
      if (!cache.containsKey(e.reviewPath)) break;
      if (cache[e.reviewPath] case final review?) {
        loaded.add(ScoredReview(
          reviewWithDocId: review,
          finalScore: e.score,
          reason: e.reason,
        ));
      }
    }
    return (loaded: loaded, total: total);
  }

  final missing = [
    for (final e in shown)
      if (!cache.containsKey(e.reviewPath)) e.reviewPath,
  ];
  if (missing.isEmpty) {
    yield ready();
    return;
  }

  final arrivals = StreamController<void>();
  var pending = missing.length;
  for (final path in missing) {
    unawaited(
        ForYouService.fetchReview(path, db: db, preferCache: preferCache).then(
      (review) => cache[path] = review,
      onError: (Object e) {
        // Skip it rather than hold up the cards below it.
        debugPrint('[REC_PROVIDER] Could not load $path: $e');
        cache[path] = null;
      },
    ).whenComplete(() {
      if (!arrivals.isClosed) arrivals.add(null);
      if (--pending == 0) arrivals.close();
    }));
  }
  ref.onDispose(arrivals.close);

  // Cards fetched before (e.g. above a "load more") show straight away.
  var shownCount = -1;
  final before = ready();
  if (before.loaded.isNotEmpty) {
    shownCount = before.loaded.length;
    yield before;
  }
  await for (final _ in arrivals.stream) {
    final feed = ready();
    // When another card is ready, or once all have arrived. Never an empty
    // list mid-load: the tab would read it as "no recommendations".
    final moreReady =
        feed.loaded.isNotEmpty && feed.loaded.length != shownCount;
    if (moreReady || pending == 0) {
      shownCount = feed.loaded.length;
      yield feed;
    }
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
    // Re-fetch the reviews too, so edits since they were loaded show.
    ref.read(_forYouFromServerProvider.notifier).state = true;
    ref.invalidate(_forYouReviewCacheProvider);
    if (await ForYouService.refresh()) return;
    ReviewRecommendationService.clearCache(userId);
    ref.invalidate(recommendedReviewsProvider);
  };
});
