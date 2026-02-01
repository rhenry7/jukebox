import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../models/review.dart';
import '../../../providers/auth_provider.dart' show currentUserIdProvider;
import '../../../providers/community_reviews_provider.dart';
import '../../../providers/reviews_provider.dart' show ReviewWithDocId;
import '../../../services/genre_cache_service.dart';
import '../../../utils/helpers.dart';
import '../../widgets/skeleton_loader.dart';
import '../Profile/ProfileSignIn.dart';
import '../../../routing/MainNavigation.dart';
import '_comments.dart' show ReviewCardWithGenres;

/// Community reviews widget - shows all users' reviews with lazy loading
class CommunityReviewsCollection extends ConsumerStatefulWidget {
  const CommunityReviewsCollection({super.key});

  @override
  ConsumerState<CommunityReviewsCollection> createState() => _CommunityReviewsCollectionState();
}

class _CommunityReviewsCollectionState extends ConsumerState<CommunityReviewsCollection> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  int _previousItemCount = 0;
  double _previousScrollPosition = 0.0;

  @override
  void initState() {
    super.initState();
    // Listen to scroll events for lazy loading
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Load more when user scrolls near the bottom (80% of the way)
    if (!_isLoadingMore && 
        _scrollController.hasClients &&
        _scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent * 0.8) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    
    // Save current scroll position and item count before loading
    if (_scrollController.hasClients) {
      _previousScrollPosition = _scrollController.position.pixels;
      // Get current item count from the provider
      final currentLimit = ref.read(communityReviewsLimitProvider);
      final currentReviewsAsync = ref.read(communityReviewsProvider(currentLimit));
      _previousItemCount = currentReviewsAsync.value?.length ?? 0;
    }
    
    setState(() {
      _isLoadingMore = true;
    });

    // Increase the limit to load more reviews
    ref.read(loadMoreCommunityReviewsProvider)();
    
    // Wait a bit for the data to load
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (mounted) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _restoreScrollPosition(int newItemCount) {
    // Only restore if we actually loaded more items (lazy loading scenario)
    if (newItemCount > _previousItemCount && _scrollController.hasClients) {
      final wasNearBottom = _previousScrollPosition >= 
          (_scrollController.position.maxScrollExtent * 0.9);
      
      // Use post-frame callback to restore position after rebuild completes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients && mounted) {
          // Wait one more frame to ensure list is fully built
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients && mounted) {
              if (wasNearBottom) {
                // If user was near bottom, scroll to new bottom to show new items
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 100),
                  curve: Curves.easeOut,
                );
              } else {
                // Otherwise, restore the exact previous position
                _scrollController.jumpTo(_previousScrollPosition);
              }
            }
          });
        }
      });
    }
    _previousItemCount = newItemCount;
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final limit = ref.watch(communityReviewsLimitProvider);
    final reviewsAsync = ref.watch(communityReviewsProvider(limit));
    
    // Check if user is authenticated
    if (userId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.person_off,
                size: 80,
                color: Colors.grey,
              ),
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
                'This app only works when you\'re signed in. Please sign in to view community reviews and discover new music!',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
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

    return reviewsAsync.when(
      data: (reviews) {
        // Restore scroll position after new items are loaded (only if we're loading more)
        if (_isLoadingMore || reviews.length > _previousItemCount) {
          _restoreScrollPosition(reviews.length);
        }
        
        if (reviews.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.music_note, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'No community reviews yet',
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Be the first to share your music reviews!',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to discovery tab (index 1)
                    final mainNavState = context.findAncestorStateOfType<MainNavState>();
                    if (mainNavState != null) {
                      mainNavState.navigateToTab(1);
                    }
                  },
                  icon: const Icon(Icons.explore),
                  label: const Text('Discover new music to review'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            // Reset limit and refresh
            ref.read(communityReviewsLimitProvider.notifier).state = 20;
            ref.invalidate(communityReviewsProvider(limit));
            await Future.delayed(const Duration(milliseconds: 500));
          },
          color: Colors.red[600],
          child: Container(
            decoration: const BoxDecoration(),
            margin: const EdgeInsets.symmetric(),
            padding: const EdgeInsets.symmetric(),
            child: Column(
              children: [
                const Gap(10),
                Expanded(
                  child: CommunityReviewList(
                    key: ValueKey('community_reviews_${reviews.length}'), // Key to help maintain state
                    reviews: reviews,
                    scrollController: _scrollController,
                    isLoadingMore: _isLoadingMore,
                    onLoadMore: _loadMore,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => ListView.builder(
        itemCount: 3,
        itemBuilder: (context, index) {
          return ReviewCardSkeleton();
        },
      ),
      error: (error, stackTrace) {
        print('❌ Error loading community reviews: $error');
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Error loading community reviews',
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
                  ref.invalidate(communityReviewsProvider(limit));
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

/// List widget for community reviews - same UI as FriendsReviewList
class CommunityReviewList extends ConsumerWidget {
  final List<ReviewWithDocId> reviews;
  final ScrollController scrollController;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;

  const CommunityReviewList({
    super.key,
    required this.reviews,
    required this.scrollController,
    required this.isLoadingMore,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      key: const PageStorageKey('community_reviews_list'), // Preserve scroll position
      controller: scrollController,
      itemCount: reviews.length + (isLoadingMore ? 1 : 0),
      cacheExtent: 500, // Cache more items to prevent scroll jumps
      itemBuilder: (context, index) {
        // Show loading indicator at the bottom when loading more
        if (index == reviews.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: CircularProgressIndicator(
                color: Colors.red,
              ),
            ),
          );
        }

        var review = reviews[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Dismissible(
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
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(
                Icons.more_vert,
                color: Colors.white,
                size: 28,
              ),
            ),
            child: GestureDetector(
              onLongPress: () => _showReviewOptionsDialog(context, review, ref),
              child: Card(
                elevation: 1,
                margin: const EdgeInsets.all(0),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  side: BorderSide(color: Color.fromARGB(56, 158, 158, 158)),
                ),
                color: Colors.white10,
                child: ReviewCardWithGenres(review: review.review),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showReviewOptionsDialog(BuildContext context, ReviewWithDocId review, WidgetRef ref) {
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
                  'Review by ${review.review.displayName ?? "Unknown"}',
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

  void _deleteReview(BuildContext context, ReviewWithDocId review, WidgetRef ref) {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in to delete reviews')),
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
                final currentLimit = ref.read(communityReviewsLimitProvider);
                ref.invalidate(communityReviewsProvider(currentLimit));

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
