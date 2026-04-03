import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../models/review.dart';
import '../../../providers/auth_provider.dart' show currentUserIdProvider;
import '../../../providers/reviews_provider.dart'
    show ReviewWithDocId, userReviewsProvider;
import '../../widgets/review_card.dart';
import '../../widgets/skeleton_loader.dart';
import '../Profile/ProfileSignIn.dart';
import '../../../routing/MainNavigation.dart';

// ReviewWithDocId moved to providers/reviews_provider.dart

class UserReviewsCollection extends ConsumerWidget {
  const UserReviewsCollection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use Riverpod providers instead of direct Firebase calls
    final userId = ref.watch(currentUserIdProvider);
    final reviewsAsync = ref.watch(userReviewsProvider);

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
                'This app only works when you\'re signed in. Please sign in to view your reviews and discover new music!',
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

    // Use Riverpod's AsyncValue pattern
    return reviewsAsync.when(
      data: (reviews) {
        // Debug logging
        debugPrint('✅ Reviews loaded: ${reviews.length} reviews');
        if (reviews.isEmpty) {
          debugPrint('⚠️ No reviews found for user: $userId');
        }

        if (reviews.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.music_note, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'No reviews yet',
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Start reviewing music to see it here!',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to discovery tab (index 1)
                    final mainNavState =
                        context.findAncestorStateOfType<MainNavState>();
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

        // Reviews already come with docIds from the provider
        final List<ReviewWithDocId> reviewsWithDocIds = reviews;

        return RefreshIndicator(
          onRefresh: () async {
            // Invalidate provider to refresh data
            ref.invalidate(userReviewsProvider);
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
                  child: FriendsReviewList(
                    reviews: reviewsWithDocIds,
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
          return const ReviewCardSkeleton();
        },
      ),
      error: (error, stackTrace) {
        debugPrint('❌ Error loading reviews: $error');
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Error loading reviews',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'If you see an index error, check Firebase Console → Firestore → Indexes',
                style: TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(userReviewsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class FriendsReviewList extends ConsumerStatefulWidget {
  final List<ReviewWithDocId> reviews;
  const FriendsReviewList({super.key, required this.reviews});

  @override
  ConsumerState<FriendsReviewList> createState() => _FriendsReviewListState();
}

class _FriendsReviewListState extends ConsumerState<FriendsReviewList> {
  static const int _pageSize = 20;
  int _displayLimit = _pageSize;

  @override
  void didUpdateWidget(FriendsReviewList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset pagination when the review list is replaced (e.g. refresh)
    if (oldWidget.reviews != widget.reviews) {
      _displayLimit = _pageSize;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.reviews.take(_displayLimit).toList();
    final hasMore = widget.reviews.length > _displayLimit;

    return ListView.builder(
      itemCount: visible.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == visible.length) {
          // "Load more" footer
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Center(
              child: TextButton(
                onPressed: () =>
                    setState(() => _displayLimit += _pageSize),
                child: const Text(
                  'Load more',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          );
        }

        final review = visible[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Dismissible(
            key: Key(review.docId.toString()),
            direction: DismissDirection.endToStart,
            confirmDismiss: (direction) async {
              _showReviewOptionsDialog(context, review);
              return false;
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
              onLongPress: () => _showReviewOptionsDialog(context, review),
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

  void _showReviewOptionsDialog(
      BuildContext context, ReviewWithDocId review) {
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
              if (_isUserReview(review.review))
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
              if (_isUserReview(review.review))
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
                    _deleteReview(context, review);
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
  bool _isUserReview(Review review) {
    final userId = ref.read(currentUserIdProvider);
    return review.userId == userId;
  }

  void _editReview(BuildContext context, ReviewWithDocId review) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Edit review: ${review.docId}')),
    );
  }

  void _deleteReview(BuildContext context, ReviewWithDocId review) {
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
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection('reviews')
                    .doc(review.docId)
                    .delete();

                // Invalidate provider to refresh UI automatically
                ref.invalidate(userReviewsProvider);

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
