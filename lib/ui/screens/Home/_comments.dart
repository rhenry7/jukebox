import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:gap/gap.dart';

import '../../../models/review.dart';
import '../../../services/get_album_service.dart';
import '../../../services/genre_cache_service.dart';
import '../../widgets/skeleton_loader.dart';

class ReviewWithDocId {
  final Review review;
  final String docId;

  ReviewWithDocId({required this.review, required this.docId});
}

class UserReviewsCollection extends StatefulWidget {
  const UserReviewsCollection({super.key});

  @override
  State<UserReviewsCollection> createState() => ReviewsList();
}

class ReviewsList extends State<UserReviewsCollection> {
  @override
  void initState() {
    super.initState();
  }

  final String userId = FirebaseAuth.instance.currentUser != null
      ? FirebaseAuth.instance.currentUser!.uid
      : "";

  @override
  Widget build(BuildContext context) {
    if (userId.isEmpty) {
      return const Center(child: Text('User not logged in.'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reviews')
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView.builder(
            itemCount: 3,
            itemBuilder: (context, index) {
              return ReviewCardSkeleton();
            },
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error loading reviews',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  '${snapshot.error}',
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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
                    // Navigate to add review
                    Navigator.pushNamed(context, '/add-review');
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Write Your First Review'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        final List<ReviewWithDocId> reviewsWithDocIds =
            snapshot.data!.docs.map((doc) {
          final review =
              Review.fromFirestore(doc.data() as Map<String, dynamic>);
          final docId = doc.id;
          return ReviewWithDocId(review: review, docId: docId);
        }).toList();

        return RefreshIndicator(
          onRefresh: () async {
            // Force refresh by rebuilding
            setState(() {});
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
    );
  }
}

class FriendsReviewList extends StatelessWidget {
  final List<ReviewWithDocId> reviews;
  const FriendsReviewList({super.key, required this.reviews});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: reviews.length,
      itemBuilder: (context, index) {
        var review = reviews[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Dismissible(
            key:
                Key(review.docId.toString()), // Assuming Review has an id field
            direction: DismissDirection.endToStart,
            confirmDismiss: (direction) async {
              // Show dialog instead of dismissing
              _showReviewOptionsDialog(context, review);
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
              onLongPress: () => _showReviewOptionsDialog(context, review),
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

  void _showReviewOptionsDialog(BuildContext context, ReviewWithDocId review) {
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
    // Replace with your actual user ID logic
    // return review.userId == FirebaseAuth.instance.currentUser?.uid;
    final String userId = FirebaseAuth.instance.currentUser != null
        ? FirebaseAuth.instance.currentUser!.uid
        : "";
    return review.userId == userId; // Placeholder
  }

  void _editReview(BuildContext context, ReviewWithDocId review) {
    // Navigate to edit review screen or show edit dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Edit review: ${review.docId}')),
    );
  }

  void _deleteReview(BuildContext context, ReviewWithDocId review) {
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
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser?.uid)
                    .collection('reviews')
                    .doc(review.docId)
                    .delete();
                // Remove from user's reviews list
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser?.uid)
                    .collection('reviews')
                    .doc(review.docId)
                    .update({
                  'reviews': FieldValue.arrayRemove([review.docId]),
                });

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

class ReviewCardWidget extends StatelessWidget {
  final Review review;
  const ReviewCardWidget({super.key, required this.review});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Image, Artist, Song, Rating
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
                    // Artist Name
                    Text(
                      review.artist,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
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
                    const SizedBox(height: 12),
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
                  ],
                ),
              ),
            ],
          ),
          // Bottom Row: Review Text (full width)
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

// Helper widget to fetch and display genres for reviews
class ReviewCardWithGenres extends StatefulWidget {
  final Review review;
  const ReviewCardWithGenres({super.key, required this.review});

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
