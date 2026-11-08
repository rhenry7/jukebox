import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/review.dart';
import '../../../providers/community_reviews_provider.dart';
import '../../../providers/reviews_provider.dart' show ReviewWithDocId;
import '../../../routing/MainNavigation.dart';
import 'package:flutter_test_project/ui/widgets/app_states.dart';
import 'package:flutter_test_project/ui/widgets/review_feed.dart';
import 'package:flutter_test_project/ui/widgets/review_options.dart';

/// Popular tab: community reviews with real text and album art, in a fresh
/// random order each time the tab is shown (or pulled to refresh), revealed
/// a page at a time.
class CommunityReviewsCollection extends ConsumerStatefulWidget {
  const CommunityReviewsCollection({
    super.key,
    this.selectedGenres = const <String>{},
  });

  final Set<String> selectedGenres;

  @override
  ConsumerState<CommunityReviewsCollection> createState() =>
      _CommunityReviewsCollectionState();
}

class _CommunityReviewsCollectionState
    extends ConsumerState<CommunityReviewsCollection> {
  static const int _pageSize = 20;

  Future<List<ReviewWithDocId>>? _genreFilteredFuture;
  String _genreRequestKey = '';

  /// Picks the random order. A new one each time this tab is built (the
  /// TabBarView rebuilds it whenever the tab is selected) and on refresh.
  int _shuffleSeed = math.Random().nextInt(1 << 31);
  int _visibleCount = _pageSize;

  /// Reviews in the order they were dealt (see [keepPlacedOrder]), so cards
  /// keep their places as more of the pool arrives. Cleared on reshuffle.
  List<String> _placedIds = const [];

  Future<void> _loadMore() async {
    setState(() => _visibleCount += _pageSize);
  }

  /// Pull-to-refresh: re-reads the pool (it isn't kept live) and deals a
  /// new order.
  Future<void> _reshuffle() async {
    ref.invalidate(communityReviewsProvider);
    try {
      await ref.read(communityReviewsProvider.future);
    } catch (_) {
      // The tab shows the error state with its own Retry.
    }
    if (!mounted) return;
    setState(() {
      _shuffleSeed = math.Random().nextInt(1 << 31);
      _visibleCount = _pageSize;
      _placedIds = const [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final reviewsAsync = ref.watch(communityReviewsProvider);

    if (widget.selectedGenres.isNotEmpty) {
      _ensureGenreFilteredFuture();

      return FutureBuilder<List<ReviewWithDocId>>(
        future: _genreFilteredFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ReviewFeedSkeleton();
          }

          if (snapshot.hasError) {
            debugPrint(
                '❌ Error loading full community genre query: ${snapshot.error}');
            return AppErrorState(
              title: 'Error loading community reviews',
              error: snapshot.error,
              onRetry: _refreshGenreFilteredFuture,
            );
          }

          final filteredReviews = snapshot.data ?? <ReviewWithDocId>[];
          if (filteredReviews.isEmpty) {
            final selectedLabels = widget.selectedGenres.join(', ');
            return AppEmptyState(
              icon: Icons.tune,
              title: 'No reviews for selected genres',
              message: selectedLabels.isEmpty
                  ? 'Try choosing a different genre filter.'
                  : 'Try adjusting: $selectedLabels',
            );
          }

          return ReviewFeed(
            storageKey: 'community_genre_reviews_list',
            reviews: filteredReviews,
            onRefresh: _refreshGenreFilteredFuture,
            itemWrapper: _withReviewOptions,
          );
        },
      );
    }

    return reviewsAsync.when(
      data: (reviews) {
        if (reviews.isEmpty) {
          return AppEmptyState(
            icon: Icons.music_note,
            title: 'No community reviews yet',
            message: 'Be the first to share your music reviews!',
            action: AppStateAction(
              label: 'Write a review',
              icon: Icons.add,
              onPressed: () {
                context
                    .findAncestorStateOfType<MainNavState>()
                    ?.navigateToTab(MainNavState.addTab);
              },
            ),
          );
        }

        final shuffled = keepPlacedOrder(reviews, _placedIds, _shuffleSeed);
        _placedIds = [for (final r in shuffled) r.fullReviewId ?? r.docId];
        return ReviewFeed(
          storageKey: 'community_reviews_list',
          reviews: shuffled.take(_visibleCount).toList(),
          hasMore: shuffled.length > _visibleCount,
          onLoadMore: _loadMore,
          onRefresh: _reshuffle,
          itemWrapper: _withReviewOptions,
        );
      },
      loading: () => const ReviewFeedSkeleton(),
      error: (error, stackTrace) {
        debugPrint('❌ Error loading community reviews: $error');
        return AppErrorState(
          title: 'Error loading community reviews',
          error: error,
          onRetry: () => ref.invalidate(communityReviewsProvider),
        );
      },
    );
  }

  Widget _withReviewOptions(
          BuildContext context, ReviewWithDocId review, Widget card) =>
      OwnReviewOptions(
        review: review,
        onDeleted: () => ref.invalidate(communityReviewsProvider),
        child: card,
      );

  void _ensureGenreFilteredFuture() {
    final key = _genresKey(widget.selectedGenres);
    if (_genreRequestKey == key && _genreFilteredFuture != null) {
      return;
    }
    _genreRequestKey = key;
    _genreFilteredFuture = _fetchFullCommunityGenreFilteredReviews(
      widget.selectedGenres,
    );
  }

  Future<void> _refreshGenreFilteredFuture() async {
    setState(() {
      _genreRequestKey = '';
      _genreFilteredFuture = _fetchFullCommunityGenreFilteredReviews(
        widget.selectedGenres,
      );
    });
    await _genreFilteredFuture;
  }

  String _genresKey(Set<String> selectedGenres) {
    final sorted = selectedGenres.toList()..sort();
    return sorted.join('|');
  }

  Future<List<ReviewWithDocId>> _fetchFullCommunityGenreFilteredReviews(
    Set<String> selectedGenres,
  ) async {
    final snapshot = await FirebaseFirestore.instance
        .collectionGroup('reviews')
        .orderBy('date', descending: true)
        .get();

    final reviews = <ReviewWithDocId>[];
    for (final doc in snapshot.docs) {
      try {
        final review = Review.fromFirestore(doc.data());
        reviews.add(
          ReviewWithDocId(
            review: review,
            docId: doc.id,
            fullReviewId: doc.reference.path,
          ),
        );
      } catch (e) {
        debugPrint('[COMMUNITY] Error parsing full-query review ${doc.id}: $e');
      }
    }

    return shuffleReviews(
      _filterReviewsByGenres(
        reviews.where((r) => isPopularEligible(r.review)).toList(),
        selectedGenres,
      ),
      _shuffleSeed,
    );
  }

  List<ReviewWithDocId> _filterReviewsByGenres(
    List<ReviewWithDocId> reviews,
    Set<String> selectedGenres,
  ) {
    if (selectedGenres.isEmpty) return reviews;

    return reviews.where((reviewWithDocId) {
      final reviewGenres = reviewWithDocId.review.genres;
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
}
