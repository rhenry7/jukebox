import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/review.dart';
import '../../../providers/auth_provider.dart' show currentUserIdProvider;
import '../../../providers/recommended_reviews_provider.dart';
import '../../../providers/reviews_provider.dart' show ReviewWithDocId;
import '../../../services/review_recommendation_service.dart';
import '../Profile/ProfileSignIn.dart';
import '../../../routing/MainNavigation.dart';
import 'package:flutter_test_project/ui/widgets/app_states.dart';
import 'package:flutter_test_project/ui/widgets/reason_label.dart';
import 'package:flutter_test_project/ui/widgets/review_feed.dart';

/// "For You" tab — shows NLP-recommended community reviews
/// personalized to the user's taste profile.
class RecommendedReviewsCollection extends ConsumerStatefulWidget {
  const RecommendedReviewsCollection({
    super.key,
    this.selectedGenres = const <String>{},
  });

  final Set<String> selectedGenres;

  @override
  ConsumerState<RecommendedReviewsCollection> createState() =>
      _RecommendedReviewsCollectionState();
}

class _RecommendedReviewsCollectionState
    extends ConsumerState<RecommendedReviewsCollection> {
  bool _isRefreshingRecommendations = false;
  Future<List<ScoredReview>>? _genreFilteredFuture;
  String _genreRequestKey = '';

  // Tab-focus tracking — detects when the For You tab (index 2) is selected.
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    // Check on first mount in case a review was written before the tab opened.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndRefresh());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tc = DefaultTabController.of(context);
    if (_tabController != tc) {
      _tabController?.removeListener(_onTabChanged);
      _tabController = tc;
      tc.addListener(_onTabChanged);
    }
  }

  void _onTabChanged() {
    // For You is tab index 2; only act once animation has settled.
    if (_tabController?.index == 2 &&
        !(_tabController?.indexIsChanging ?? true)) {
      _checkAndRefresh();
    }
  }

  /// If a review was submitted or preferences saved since last load, re-fetch.
  void _checkAndRefresh() {
    if (!mounted) return;
    if (ReviewRecommendationService.consumeNeedsRefresh()) {
      debugPrint('[FOR_YOU] Dirty flag detected — refreshing recommendations');
      ref.invalidate(recommendedReviewsProvider);
    }
  }

  @override
  void dispose() {
    _tabController?.removeListener(_onTabChanged);
    super.dispose();
  }

  Future<void> _loadMore() async {
    ref.read(loadMoreRecommendedReviewsProvider)();
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> _fetchNewRecommendations() async {
    if (_isRefreshingRecommendations) return;
    _isRefreshingRecommendations = true;

    ref.read(recommendedReviewsDisplayLimitProvider.notifier).state = 5;
    await ref.read(refreshRecommendationsProvider)();

    _isRefreshingRecommendations = false;
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final recommendedAsync = ref.watch(recommendedReviewsProvider);
    final displayLimit = ref.watch(recommendedReviewsDisplayLimitProvider);

    // Auth gate — must be signed in for personalized recommendations
    if (userId == null) {
      return AppEmptyState(
        icon: Icons.person_off,
        title: 'Sign In Required',
        message:
            'Sign in to get personalized review recommendations based on your taste!',
        action: AppStateAction(
          label: 'Sign In!',
          icon: Icons.login,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const SignInScreen()),
            );
          },
        ),
      );
    }

    if (widget.selectedGenres.isNotEmpty) {
      _ensureGenreFilteredFuture(userId);

      return FutureBuilder<List<ScoredReview>>(
        future: _genreFilteredFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ReviewFeedSkeleton();
          }

          if (snapshot.hasError) {
            debugPrint('[FOR_YOU] Genre full-query error: ${snapshot.error}');
            return AppErrorState(
              title: 'Error loading recommendations',
              error: snapshot.error,
              onRetry: () => _refreshGenreFilteredFuture(userId),
            );
          }

          final allGenreMatchedReviews =
              snapshot.data ?? const <ScoredReview>[];
          if (allGenreMatchedReviews.isEmpty) {
            return _noGenreMatches();
          }

          return _feed(
            storageKey: 'recommended_genre_reviews_list',
            scored: allGenreMatchedReviews,
            displayLimit: displayLimit,
            onRefresh: () async {
              ref.read(recommendedReviewsDisplayLimitProvider.notifier).state =
                  10;
              await _refreshGenreFilteredFuture(userId);
            },
          );
        },
      );
    }

    return recommendedAsync.when(
      data: (allReviews) {
        final filteredByGenre =
            _filterScoredReviewsByGenres(allReviews, widget.selectedGenres);

        if (allReviews.isEmpty) {
          return AppEmptyState(
            icon: Icons.auto_awesome,
            title: 'No recommendations yet',
            message: 'Write some reviews to get personalized recommendations',
            action: AppStateAction(
              label: 'Discover music to review',
              icon: Icons.explore,
              onPressed: () {
                context
                    .findAncestorStateOfType<MainNavState>()
                    ?.navigateToTab(1);
              },
            ),
          );
        }

        if (filteredByGenre.isEmpty) {
          return _noGenreMatches();
        }

        return _feed(
          storageKey: 'recommended_reviews_list',
          scored: filteredByGenre,
          displayLimit: displayLimit,
          onRefresh: _fetchNewRecommendations,
        );
      },
      loading: () => const ReviewFeedSkeleton(),
      error: (error, stackTrace) {
        debugPrint('Error loading recommendations: $error');
        return AppErrorState(
          title: 'Error loading recommendations',
          error: error,
          onRetry: () => ref.invalidate(recommendedReviewsProvider),
        );
      },
    );
  }

  /// Shows the first [displayLimit] of [scored]; scrolling raises the limit.
  Widget _feed({
    required String storageKey,
    required List<ScoredReview> scored,
    required int displayLimit,
    required Future<void> Function() onRefresh,
  }) {
    final displayed = scored.take(displayLimit);
    final reasons = {
      for (final s in scored)
        if (s.reason case final reason? when reason.isNotEmpty)
          s.reviewWithDocId.fullReviewId: reason,
    };
    return ReviewFeed(
      storageKey: storageKey,
      reviews: [for (final s in displayed) s.reviewWithDocId],
      hasMore: scored.length > displayLimit,
      onLoadMore: _loadMore,
      onRefresh: onRefresh,
      itemWrapper: (context, review, card) =>
          WithReason(reason: reasons[review.fullReviewId], child: card),
    );
  }

  Widget _noGenreMatches() {
    final selectedLabels = widget.selectedGenres.join(', ');
    return AppEmptyState(
      icon: Icons.tune,
      title: 'No recommendations for selected genres',
      message: selectedLabels.isEmpty
          ? 'Try choosing a different genre filter.'
          : 'Try adjusting: $selectedLabels',
    );
  }

  List<ScoredReview> _filterScoredReviewsByGenres(
    List<ScoredReview> reviews,
    Set<String> selectedGenres,
  ) {
    if (selectedGenres.isEmpty) return reviews;

    return reviews.where((scoredReview) {
      final reviewGenres = scoredReview.reviewWithDocId.review.genres;
      if (reviewGenres == null || reviewGenres.isEmpty) return false;

      final normalizedReviewGenres = reviewGenres
          .map((genre) => genre.toLowerCase().trim())
          .where((genre) => genre.isNotEmpty)
          .toList();

      for (final selected in selectedGenres) {
        for (final reviewGenre in normalizedReviewGenres) {
          if (reviewGenre == selected ||
              reviewGenre.contains(selected) ||
              selected.contains(reviewGenre)) {
            return true;
          }
        }
      }
      return false;
    }).toList();
  }

  void _ensureGenreFilteredFuture(String userId) {
    final key = '$userId|${_genresKey(widget.selectedGenres)}';
    if (_genreRequestKey == key && _genreFilteredFuture != null) {
      return;
    }
    _genreRequestKey = key;
    _genreFilteredFuture = _fetchFullGenreMatchedRecommendations(
      userId,
      widget.selectedGenres,
    );
  }

  Future<void> _refreshGenreFilteredFuture(String userId) async {
    setState(() {
      _genreRequestKey = '';
      _genreFilteredFuture = _fetchFullGenreMatchedRecommendations(
        userId,
        widget.selectedGenres,
      );
    });
    await _genreFilteredFuture;
  }

  String _genresKey(Set<String> selectedGenres) {
    final sorted = selectedGenres.toList()..sort();
    return sorted.join('|');
  }

  Future<List<ScoredReview>> _fetchFullGenreMatchedRecommendations(
    String userId,
    Set<String> selectedGenres,
  ) async {
    final snapshot = await FirebaseFirestore.instance
        .collectionGroup('reviews')
        .orderBy('date', descending: true)
        .limit(400)
        .get();

    final allReviews = <ReviewWithDocId>[];
    for (final doc in snapshot.docs) {
      try {
        final review = Review.fromFirestore(doc.data());
        if (review.userId == userId) {
          continue;
        }
        allReviews.add(
          ReviewWithDocId(
            review: review,
            docId: doc.id,
            fullReviewId: doc.reference.path,
          ),
        );
      } catch (e) {
        debugPrint('[FOR_YOU] Error parsing full-query review ${doc.id}: $e');
      }
    }

    final scored = allReviews
        .map(
            (reviewWithDocId) => ScoredReview(reviewWithDocId: reviewWithDocId))
        .toList();

    return _filterScoredReviewsByGenres(scored, selectedGenres);
  }
}
