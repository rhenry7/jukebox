import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../providers/auth_provider.dart' show currentUserIdProvider;
import '../../../providers/recommended_reviews_provider.dart';
import '../../widgets/skeleton_loader.dart';
import '../Profile/ProfileSignIn.dart';
import '../../../routing/MainNavigation.dart';
import '_comments.dart' show ReviewCardWithGenres;

/// "For You" tab — shows NLP-recommended community reviews
/// personalized to the user's taste profile.
class RecommendedReviewsCollection extends ConsumerStatefulWidget {
  const RecommendedReviewsCollection({super.key});

  @override
  ConsumerState<RecommendedReviewsCollection> createState() =>
      _RecommendedReviewsCollectionState();
}

class _RecommendedReviewsCollectionState
    extends ConsumerState<RecommendedReviewsCollection> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;

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
        _scrollController.hasClients &&
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

    return recommendedAsync.when(
      data: (allReviews) {
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

        // Apply display limit for lazy loading
        final displayedReviews = allReviews.length > displayLimit
            ? allReviews.sublist(0, displayLimit)
            : allReviews;

        return RefreshIndicator(
          onRefresh: () async {
            ref.read(recommendedReviewsDisplayLimitProvider.notifier).state = 10;
            await ref.read(refreshRecommendationsProvider)();
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
      loading: () => ListView.builder(
        itemCount: 3,
        itemBuilder: (context, index) {
          return const ReviewCardSkeleton();
        },
      ),
      error: (error, stackTrace) {
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
}
