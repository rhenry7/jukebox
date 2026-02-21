import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../models/review.dart';
import '../../../providers/auth_provider.dart' show currentUserIdProvider;
import '../../../providers/friends_provider.dart';
import '../../../providers/reviews_provider.dart' show ReviewWithDocId;
import '../../widgets/skeleton_loader.dart';
import '../Profile/ProfileSignIn.dart';
import '_comments.dart' show ReviewCardWithGenres;

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
    final ref = this.ref;
    final userId = ref.watch(currentUserIdProvider);

    // Not signed in
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
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sign in to see reviews from your friends!',
                style: TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (context) => const SignInScreen()),
                  );
                },
                icon: const Icon(Icons.login),
                label: const Text('Sign In!',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final friendsReviewsAsync = ref.watch(friendsReviewsProvider);
    final friendIdsAsync = ref.watch(friendIdsProvider);
    final friendIds = friendIdsAsync.value ?? [];

    if (widget.selectedGenres.isNotEmpty && friendIds.isNotEmpty) {
      _ensureGenreFilteredFuture(userId, friendIds);
    } else {
      _genreFilteredFuture = null;
      _genreRequestKey = '';
    }

    // No friends added yet — prompt
    if (friendIds.isEmpty && !friendIdsAsync.isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.people_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'No friends yet',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
              const SizedBox(height: 8),
              const Text(
                'Head to the Community tab and tap on a reviewer\'s name to add them as a friend!',
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  // Switch to the Community tab (index 1 inside CategoryTapBar)
                  DefaultTabController.of(context).animateTo(1);
                },
                icon: const Icon(Icons.public),
                label: const Text('Go to Community'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.selectedGenres.isNotEmpty && friendIds.isNotEmpty) {
      return FutureBuilder<List<ReviewWithDocId>>(
        future: _genreFilteredFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView.builder(
              itemCount: 3,
              itemBuilder: (_, __) => const ReviewCardSkeleton(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Error loading friends\' reviews',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _refreshGenreFilteredFuture(friendIds),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final filteredReviews = snapshot.data ?? <ReviewWithDocId>[];
          if (filteredReviews.isEmpty) {
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
                      'No reviews for selected genres',
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

          return RefreshIndicator(
            onRefresh: () => _refreshGenreFilteredFuture(friendIds),
            color: Colors.red[600],
            child: Column(
              children: [
                const Gap(10),
                Expanded(
                  child: _FriendsReviewList(reviews: filteredReviews),
                ),
              ],
            ),
          );
        },
      );
    }

    return friendsReviewsAsync.when(
      data: (reviews) {
        if (reviews.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.music_note, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'Your ${friendIds.length} friend${friendIds.length == 1 ? " hasn't" : "s haven't"} posted any reviews yet',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(friendsReviewsProvider);
            await Future.delayed(const Duration(milliseconds: 500));
          },
          color: Colors.red[600],
          child: Column(
            children: [
              const Gap(10),
              Expanded(
                child: _FriendsReviewList(reviews: reviews),
              ),
            ],
          ),
        );
      },
      loading: () => ListView.builder(
        itemCount: 3,
        itemBuilder: (_, __) => const ReviewCardSkeleton(),
      ),
      error: (error, _) {
        debugPrint('Error loading friends reviews: $error');
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Error loading friends\' reviews',
                  style: TextStyle(color: Colors.white, fontSize: 18)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(friendsReviewsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
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

/// Simple list of friend reviews reusing the existing review card widgets.
class _FriendsReviewList extends StatelessWidget {
  final List<ReviewWithDocId> reviews;
  const _FriendsReviewList({required this.reviews});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const PageStorageKey('friends_reviews_list'),
      itemCount: reviews.length,
      itemBuilder: (context, index) {
        final review = reviews[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Card(
            elevation: 1,
            margin: EdgeInsets.zero,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              side: BorderSide(color: Color.fromARGB(56, 158, 158, 158)),
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
    );
  }
}
