import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/review.dart';
import '../../../providers/auth_provider.dart' show currentUserIdProvider;
import '../../../providers/community_reviews_provider.dart';
import '../../../providers/reviews_provider.dart' show ReviewWithDocId;
import '../../../routing/MainNavigation.dart';
import 'package:flutter_test_project/ui/theme/tokens.dart';
import 'package:flutter_test_project/ui/widgets/app_states.dart';
import 'package:flutter_test_project/ui/widgets/review_feed.dart';

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

  Future<void> _loadMore() async {
    setState(() => _visibleCount += _pageSize);
  }

  Future<void> _reshuffle() async {
    setState(() {
      _shuffleSeed = math.Random().nextInt(1 << 31);
      _visibleCount = _pageSize;
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

        final shuffled = shuffleReviews(reviews, _shuffleSeed);
        return ReviewFeed(
          storageKey: 'community_reviews_list',
          reviews: shuffled.take(_visibleCount).toList(),
          hasMore: shuffled.length > _visibleCount,
          onLoadMore: _loadMore,
          // The pool is a live stream, so refreshing only needs a new order.
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

  /// Swipe left or long-press a card to open the review options dialog.
  Widget _withReviewOptions(
      BuildContext context, ReviewWithDocId review, Widget card) {
    return Dismissible(
      key: Key(review.docId.toString()),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        // Show dialog instead of dismissing
        _showReviewOptionsDialog(context, review, ref);
        return false; // Don't actually dismiss the card
      },
      background: Container(
        decoration: const BoxDecoration(
          color: Color.fromARGB(255, 220, 53, 69),
          borderRadius: AppRadius.cardAll,
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.xl),
        child: const Icon(
          Icons.more_vert,
          color: Colors.white,
          size: 28,
        ),
      ),
      child: GestureDetector(
        onLongPress: () => _showReviewOptionsDialog(context, review, ref),
        child: card,
      ),
    );
  }

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

  void _showReviewOptionsDialog(
      BuildContext context, ReviewWithDocId review, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Review Options',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Show review info
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  'Review by ${review.review.displayName.isNotEmpty ? review.review.displayName : "Unknown"}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ),
              // Edit option (if it's user's own review)
              if (_isUserReview(review.review, ref))
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Edit Review'),
                  textColor: Colors.white,
                  onTap: () {
                    Navigator.pop(context);
                    _editReview(context, review);
                  },
                ),
              // Delete option (if it's user's own review)
              if (_isUserReview(review.review, ref))
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    'Delete Review',
                  ),
                  textColor: Colors.white,
                  titleTextStyle: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteReview(context, review, ref);
                  },
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  // Helper method to check if review belongs to current user
  bool _isUserReview(Review review, WidgetRef ref) {
    final userId = ref.read(currentUserIdProvider);
    return review.userId == userId;
  }

  void _editReview(BuildContext context, ReviewWithDocId review) {
    // Navigate to edit review screen or show edit dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Edit review: ${review.docId}')),
    );
  }

  void _deleteReview(
      BuildContext context, ReviewWithDocId review, WidgetRef ref) {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You must be signed in to delete reviews')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Delete Review',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        content: const Text(
          'Are you sure you want to delete this review? This action cannot be undone.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // Delete review from Firestore
                // Need to get the full path: users/{userId}/reviews/{reviewId}
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection('reviews')
                    .doc(review.docId)
                    .delete();

                // Invalidate providers to refresh UI
                ref.invalidate(communityReviewsProvider);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Review deleted successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting review: $e')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
