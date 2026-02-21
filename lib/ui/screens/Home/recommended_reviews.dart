import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../models/review.dart';
import '../../../providers/auth_provider.dart' show currentUserIdProvider;
import '../../../providers/recommended_reviews_provider.dart';
import '../../../providers/reviews_provider.dart' show ReviewWithDocId;
import '../../../services/review_recommendation_service.dart' show ScoredReview;
import '../../widgets/skeleton_loader.dart';
import '../Profile/ProfileSignIn.dart';
import '../../../routing/MainNavigation.dart';
import '_comments.dart' show ReviewCardWithGenres;

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
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _hasMoreItems = true;
  bool _isRefreshingRecommendations = false;
  Future<List<ScoredReview>>? _genreFilteredFuture;
  String _genreRequestKey = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_isLoadingMore &&
        _hasMoreItems &&
        _scrollController.hasClients &&
        _scrollController.position.userScrollDirection ==
            ScrollDirection.reverse &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    ref.read(loadMoreRecommendedReviewsProvider)();

    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _fetchNewRecommendations() async {
    if (_isRefreshingRecommendations) return;

    setState(() {
      _isRefreshingRecommendations = true;
    });

    ref.read(recommendedReviewsDisplayLimitProvider.notifier).state = 10;
    await ref.read(refreshRecommendationsProvider)();

    if (mounted) {
      setState(() {
        _isRefreshingRecommendations = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final recommendedAsync = ref.watch(recommendedReviewsProvider);
    final displayLimit = ref.watch(recommendedReviewsDisplayLimitProvider);

    // Auth gate
    if (userId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_off, size: 80, color: Colors.grey),
              const SizedBox(height: 24),
              const Text(
                'Sign In Required',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sign in to get personalized review recommendations based on your taste!',
                style: TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const SignInScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.login),
                label: const Text(
                  'Sign In!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.selectedGenres.isNotEmpty) {
      _ensureGenreFilteredFuture(userId);

      return FutureBuilder<List<ScoredReview>>(
        future: _genreFilteredFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView.builder(
              itemCount: 3,
              itemBuilder: (_, __) => const ReviewCardSkeleton(),
            );
          }

          if (snapshot.hasError) {
            debugPrint('[FOR_YOU] Genre full-query error: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Error loading recommendations',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _refreshGenreFilteredFuture(userId),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final allGenreMatchedReviews =
              snapshot.data ?? const <ScoredReview>[];
          if (allGenreMatchedReviews.isEmpty) {
            final selectedLabels = widget.selectedGenres.join(', ');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.tune, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'No recommendations for selected genres',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      selectedLabels.isEmpty
                          ? 'Try choosing a different genre filter.'
                          : 'Try adjusting: $selectedLabels',
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final displayedReviews = allGenreMatchedReviews.length > displayLimit
              ? allGenreMatchedReviews.sublist(0, displayLimit)
              : allGenreMatchedReviews;
          _hasMoreItems =
              displayedReviews.length < allGenreMatchedReviews.length;

          return RefreshIndicator(
            onRefresh: () async {
              ref.read(recommendedReviewsDisplayLimitProvider.notifier).state =
                  10;
              await _refreshGenreFilteredFuture(userId);
            },
            color: Colors.red[600],
            child: Column(
              children: [
                const Gap(10),
                Expanded(
                  child: ListView.builder(
                    key: const PageStorageKey('recommended_reviews_list'),
                    controller: _scrollController,
                    itemCount:
                        displayedReviews.length + (_isLoadingMore ? 1 : 0),
                    cacheExtent: 500,
                    itemBuilder: (context, index) {
                      if (index == displayedReviews.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(
                            child: CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        );
                      }

                      final scored = displayedReviews[index];
                      final review = scored.reviewWithDocId;
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 4.0),
                        child: Card(
                          elevation: 1,
                          margin: const EdgeInsets.all(0),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                            side: BorderSide(
                                color: Color.fromARGB(56, 158, 158, 158)),
                          ),
                          color: Colors.white10,
                          child: ReviewCardWithGenres(
                            review: review.review,
                            reviewId: review.fullReviewId,
                            showLikeButton: true,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    return recommendedAsync.when(
      data: (allReviews) {
        final filteredByGenre =
            _filterScoredReviewsByGenres(allReviews, widget.selectedGenres);

        if (allReviews.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.auto_awesome, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'No recommendations yet',
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Write some reviews to get personalized recommendations',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    final mainNavState =
                        context.findAncestorStateOfType<MainNavState>();
                    if (mainNavState != null) {
                      mainNavState.navigateToTab(1);
                    }
                  },
                  icon: const Icon(Icons.explore),
                  label: const Text('Discover music to review'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        if (filteredByGenre.isEmpty) {
          final selectedLabels = widget.selectedGenres.join(', ');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.tune, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No recommendations for selected genres',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    selectedLabels.isEmpty
                        ? 'Try choosing a different genre filter.'
                        : 'Try adjusting: $selectedLabels',
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // Apply display limit for lazy loading
        final displayedReviews = filteredByGenre.length > displayLimit
            ? filteredByGenre.sublist(0, displayLimit)
            : filteredByGenre;
        _hasMoreItems = displayedReviews.length < filteredByGenre.length;

        return RefreshIndicator(
          onRefresh: _fetchNewRecommendations,
          color: Colors.red[600],
          child: Column(
            children: [
              const Gap(10),
              Expanded(
                child: ListView.builder(
                  key: const PageStorageKey('recommended_reviews_list'),
                  controller: _scrollController,
                  itemCount: displayedReviews.length + (_isLoadingMore ? 1 : 0),
                  cacheExtent: 500,
                  itemBuilder: (context, index) {
                    if (index == displayedReviews.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      );
                    }

                    final scored = displayedReviews[index];
                    final review = scored.reviewWithDocId;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 4.0),
                      child: Card(
                        elevation: 1,
                        margin: const EdgeInsets.all(0),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                          side: BorderSide(
                              color: Color.fromARGB(56, 158, 158, 158)),
                        ),
                        color: Colors.white10,
                        child: ReviewCardWithGenres(
                          review: review.review,
                          reviewId: review.fullReviewId,
                          showLikeButton: true,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
      loading: () {
        _hasMoreItems = false;
        return ListView.builder(
          itemCount: 3,
          itemBuilder: (context, index) {
            return const ReviewCardSkeleton();
          },
        );
      },
      error: (error, stackTrace) {
        _hasMoreItems = false;
        debugPrint('Error loading recommendations: $error');
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Error loading recommendations',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(recommendedReviewsProvider);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      },
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
