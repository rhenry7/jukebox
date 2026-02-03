import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../models/review.dart';
import '../../../providers/auth_provider.dart' show currentUserIdProvider;
import '../../../providers/reviews_provider.dart' show ReviewWithDocId, userReviewsProvider;
import '../../../providers/review_likes_provider.dart';
import '../../../services/genre_cache_service.dart';
import '../../../services/review_likes_service.dart';
import '../../../utils/helpers.dart';
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
        print('✅ Reviews loaded: ${reviews.length} reviews');
        if (reviews.isEmpty) {
          print('⚠️ No reviews found for user: $userId');
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
        print('❌ Error loading reviews: $error');
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

class FriendsReviewList extends ConsumerWidget {
  final List<ReviewWithDocId> reviews;
  const FriendsReviewList({super.key, required this.reviews});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      itemCount: reviews.length,
      itemBuilder: (context, index) {
        final review = reviews[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Dismissible(
            key:
                Key(review.docId.toString()), // Assuming Review has an id field
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
                child:
                    ReviewCardWithGenres(review: review.review), // Pass review data with genre loading
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
                  'Review by ${review.review.displayName ?? "Unknown"}', // Assuming Review has userName
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

class ReviewCardWidget extends ConsumerWidget {
  final Review review;
  final String? reviewId; // Full review ID for likes: users/{userId}/reviews/{docId}
  final bool showLikeButton; // Only show like button in community tab
  
  const ReviewCardWidget({
    super.key, 
    required this.review,
    this.reviewId,
    this.showLikeButton = false,
  });
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Image, Artist, Song, Rating, Like Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Album Cover
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: review.albumImageUrl != null
                    ? Image.network(
                        review.albumImageUrl!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.music_note, size: 80, color: Colors.white70);
                        },
                      )
                    : const Icon(Icons.music_note, size: 80, color: Colors.white70),
              ),
              const SizedBox(width: 16),
              // Artist, Song, and Rating
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: Artist Name and Like Button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            review.artist,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        // Like Button (top right) - only show in community tab
                        if (showLikeButton && reviewId != null)
                          _LikeButton(reviewId: reviewId!),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Song Title
                    Text(
                      review.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Rating Bar and Timestamp in a Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Rating Bar
                        RatingBar(
                          minRating: 0,
                          maxRating: 5,
                          allowHalfRating: true,
                          initialRating: review.score,
                          itemSize: 20,
                          itemPadding: const EdgeInsets.only(right: 4.0),
                          ratingWidget: RatingWidget(
                            full: const Icon(Icons.star, color: Colors.amber),
                            empty: const Icon(Icons.star, color: Colors.grey),
                            half: const Icon(Icons.star_half, color: Colors.amber),
                          ),
                          ignoreGestures: true,
                          onRatingUpdate: (rating) {},
                        ),
                        // Small gap before timestamp
                        if (review.date != null) const SizedBox(width: 5),
                        // Timestamp (relative time)
                        if (review.date != null)
                          Text(
                            formatRelativeTime(review.date),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 7,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Bottom Row: Review Text (full width) - only show if review text exists
          if (review.review.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              review.review,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14.0,
                fontStyle: FontStyle.italic,
              ),
              maxLines: null,
              overflow: TextOverflow.visible,
            ),
          ],
          // Username row - left aligned, italic, small font
          if (review.displayName.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  review.displayName,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
          // Genre Tags (pills at the bottom)
          if (review.genres != null && review.genres!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: review.genres!.take(5).map((genre) {
                return Chip(
                  label: Text(
                    genre,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  backgroundColor: Colors.white.withOpacity(0.1),
                  side: BorderSide(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// Like button widget for review cards
class _LikeButton extends ConsumerWidget {
  final String reviewId;
  
  const _LikeButton({required this.reviewId});
  
  String _formatLikeCount(int count) {
    if (count >= 1000) {
      final k = (count / 1000).toStringAsFixed(1);
      return k.endsWith('.0') ? '${k.substring(0, k.length - 2)}k' : '${k}k';
    }
    return count.toString();
  }
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    final likeCountAsync = ref.watch(reviewLikeCountProvider(reviewId));
    final isLikedAsync = userId != null 
        ? ref.watch(reviewUserLikeStatusProvider(reviewId))
        : const AsyncValue.data(false);
    
    return likeCountAsync.when(
      data: (likeCount) {
        final isLiked = isLikedAsync.value ?? false;
        
        return GestureDetector(
          onTap: userId != null ? () async {
            try {
              final service = ReviewLikesService();
              await service.toggleLike(reviewId, userId);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            }
          } : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                color: isLiked ? Colors.red : Colors.white70,
                size: 18,
              ),
              if (likeCount > 0) ...[
                const SizedBox(width: 4),
                Text(
                  _formatLikeCount(likeCount),
                  style: TextStyle(
                    color: isLiked ? Colors.red : Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }
}

// Helper widget to fetch and display genres for reviews
class ReviewCardWithGenres extends StatefulWidget {
  final Review review;
  final String? reviewId; // Full review ID for likes
  final bool showLikeButton; // Only show like button in community tab
  
  const ReviewCardWithGenres({
    super.key, 
    required this.review,
    this.reviewId,
    this.showLikeButton = false,
  });

  @override
  State<ReviewCardWithGenres> createState() => _ReviewCardWithGenresState();
}

class _ReviewCardWithGenresState extends State<ReviewCardWithGenres> {
  List<String>? _genres;
  bool _isLoadingGenres = false;

  @override
  void initState() {
    super.initState();
    _genres = widget.review.genres;
    // If no genres, fetch them
    if (_genres == null || _genres!.isEmpty) {
      _loadGenres();
    }
  }

  Future<void> _loadGenres() async {
    if (_isLoadingGenres) return;
    
    setState(() {
      _isLoadingGenres = true;
    });

    try {
      // Use cache service: checks Firestore cache first, then MusicBrainz API
      final genres = await GenreCacheService.getGenresWithCache(
        widget.review.title,
        widget.review.artist,
      );

      if (genres.isNotEmpty && mounted) {
        setState(() {
          _genres = genres;
          _isLoadingGenres = false;
        });
        return;
      }
    } catch (e) {
      print('Error loading genres: $e');
    }

    // If MusicBrainz fails, genres remain null/empty
    if (mounted) {
      setState(() {
        _isLoadingGenres = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use genres from state if available, otherwise use review's genres
    final genres = _genres ?? widget.review.genres;
    
    return ReviewCardWidget(
      review: widget.review.copyWith(genres: genres),
      reviewId: widget.reviewId,
      showLikeButton: widget.showLikeButton,
    );
  }
}

// Extension to add copyWith to Review
extension ReviewCopyWith on Review {
  Review copyWith({
    String? displayName,
    String? userId,
    String? artist,
    String? review,
    double? score,
    DateTime? date,
    String? albumImageUrl,
    String? userImageUrl,
    int? likes,
    int? replies,
    int? reposts,
    String? title,
    List<String>? genres,
  }) {
    return Review(
      displayName: displayName ?? this.displayName,
      userId: userId ?? this.userId,
      artist: artist ?? this.artist,
      review: review ?? this.review,
      score: score ?? this.score,
      date: date ?? this.date,
      albumImageUrl: albumImageUrl ?? this.albumImageUrl,
      userImageUrl: userImageUrl ?? this.userImageUrl,
      likes: likes ?? this.likes,
      replies: replies ?? this.replies,
      reposts: reposts ?? this.reposts,
      title: title ?? this.title,
      genres: genres ?? this.genres,
    );
  }
}
