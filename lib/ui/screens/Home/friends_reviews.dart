import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/review.dart';
import '../../../providers/auth_provider.dart' show currentUserIdProvider;
import '../../../providers/friends_provider.dart';
import '../../../providers/reviews_provider.dart' show ReviewWithDocId;
import '../Profile/helpers/profileHelpers.dart' show openSignIn;
import 'package:flutter_test_project/ui/widgets/app_states.dart';
import 'package:flutter_test_project/ui/widgets/review_feed.dart';

/// Friends reviews feed – shows reviews from users the current user has added
/// as friends. Mirrors the layout and UX of [CommunityReviewsCollection].
class FriendsReviewsCollection extends ConsumerStatefulWidget {
  const FriendsReviewsCollection({
    super.key,
    this.selectedGenres = const <String>{},
  });

  final Set<String> selectedGenres;

  @override
  ConsumerState<FriendsReviewsCollection> createState() =>
      _FriendsReviewsCollectionState();
}

class _FriendsReviewsCollectionState
    extends ConsumerState<FriendsReviewsCollection> {
  Future<List<ReviewWithDocId>>? _genreFilteredFuture;
  String _genreRequestKey = '';

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);

    // Not signed in
    if (userId == null) {
      return AppEmptyState(
        icon: Icons.person_off,
        title: 'Sign In Required',
        message: 'Sign in to see reviews from your friends!',
        action: AppStateAction(
          label: 'Sign In!',
          icon: Icons.login,
          onPressed: () {
            openSignIn(context);
          },
        ),
      );
    }

    final friendsReviewsAsync = ref.watch(friendsReviewsProvider);
    final friendIdsAsync = ref.watch(friendIdsProvider);
    final friendIds = friendIdsAsync.valueOrNull ?? [];

    if (widget.selectedGenres.isNotEmpty && friendIds.isNotEmpty) {
      _ensureGenreFilteredFuture(userId, friendIds);
    } else {
      _genreFilteredFuture = null;
      _genreRequestKey = '';
    }

    // No friends added yet — prompt
    if (friendIds.isEmpty && !friendIdsAsync.isLoading) {
      return AppEmptyState(
        icon: Icons.people_outline,
        title: 'No friends yet',
        message:
            'Head to the Community tab and tap on a reviewer\'s name to add them as a friend!',
        action: AppStateAction(
          label: 'Go to Community',
          icon: Icons.public,
          // Switch to the Community tab (index 1 inside CategoryTapBar)
          onPressed: () => DefaultTabController.of(context).animateTo(1),
        ),
      );
    }

    if (widget.selectedGenres.isNotEmpty && friendIds.isNotEmpty) {
      return FutureBuilder<List<ReviewWithDocId>>(
        future: _genreFilteredFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ReviewFeedSkeleton();
          }

          if (snapshot.hasError) {
            return AppErrorState(
              title: 'Error loading friends\' reviews',
              onRetry: () => _refreshGenreFilteredFuture(friendIds),
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
            storageKey: 'friends_genre_reviews_list',
            reviews: filteredReviews,
            onRefresh: () => _refreshGenreFilteredFuture(friendIds),
          );
        },
      );
    }

    return friendsReviewsAsync.when(
      data: (reviews) {
        if (reviews.isEmpty) {
          return AppEmptyState(
            icon: Icons.music_note,
            title:
                'Your ${friendIds.length} friend${friendIds.length == 1 ? " hasn't" : "s haven't"} posted any reviews yet',
          );
        }

        return ReviewFeed(
          storageKey: 'friends_reviews_list',
          reviews: reviews,
          onRefresh: () async {
            ref.invalidate(friendsReviewsProvider);
            await Future.delayed(const Duration(milliseconds: 500));
          },
        );
      },
      loading: () => const ReviewFeedSkeleton(),
      error: (error, _) {
        debugPrint('Error loading friends reviews: $error');
        return AppErrorState(
          title: 'Error loading friends\' reviews',
          onRetry: () => ref.invalidate(friendsReviewsProvider),
        );
      },
    );
  }

  void _ensureGenreFilteredFuture(String userId, List<String> friendIds) {
    final key =
        '$userId|${_genresKey(widget.selectedGenres)}|${friendIds.join(",")}';
    if (_genreRequestKey == key && _genreFilteredFuture != null) {
      return;
    }
    _genreRequestKey = key;
    _genreFilteredFuture = _fetchFullFriendsGenreFilteredReviews(
      friendIds,
      widget.selectedGenres,
    );
  }

  Future<void> _refreshGenreFilteredFuture(List<String> friendIds) async {
    setState(() {
      _genreRequestKey = '';
      _genreFilteredFuture = _fetchFullFriendsGenreFilteredReviews(
        friendIds,
        widget.selectedGenres,
      );
    });
    await _genreFilteredFuture;
  }

  String _genresKey(Set<String> selectedGenres) {
    final sorted = selectedGenres.toList()..sort();
    return sorted.join('|');
  }

  Future<List<ReviewWithDocId>> _fetchFullFriendsGenreFilteredReviews(
    List<String> friendIds,
    Set<String> selectedGenres,
  ) async {
    final queryFutures = friendIds.map((friendId) {
      return FirebaseFirestore.instance
          .collection('users')
          .doc(friendId)
          .collection('reviews')
          .orderBy('date', descending: true)
          .get();
    }).toList();

    final snapshots = await Future.wait(queryFutures);
    final allReviews = <ReviewWithDocId>[];

    for (final snapshot in snapshots) {
      for (final doc in snapshot.docs) {
        try {
          final review = Review.fromFirestore(doc.data());
          allReviews.add(
            ReviewWithDocId(
              review: review,
              docId: doc.id,
              fullReviewId: doc.reference.path,
            ),
          );
        } catch (e) {
          debugPrint('Error parsing friend review ${doc.id}: $e');
        }
      }
    }

    allReviews.sort((a, b) {
      final dateA = a.review.date ?? DateTime(2000);
      final dateB = b.review.date ?? DateTime(2000);
      return dateB.compareTo(dateA);
    });

    return _filterReviewsByGenres(allReviews, selectedGenres);
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
