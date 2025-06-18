import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:gap/gap.dart';
import '../../../models/review.dart';

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
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No reviews found.'));
        }

        List<Review> reviews = snapshot.data!.docs.map((doc) {
          return Review.fromFirestore(doc.data() as Map<String, dynamic>);
        }).toList();
        // TODO fix
        // Create a model to hold both Review and its Firestore document ID

        final List<ReviewWithDocId> reviewsWithDocIds =
            snapshot.data!.docs.map((doc) {
          final review =
              Review.fromFirestore(doc.data() as Map<String, dynamic>);
          final docId = doc.id;
          return ReviewWithDocId(review: review, docId: docId);
        }).toList();

        return Container(
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
            ));
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
          padding: const EdgeInsets.all(8.0),
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
                color: Colors.black,
                child:
                    ReviewCardWidget(review: review.review), // Pass review data
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
            style: const TextStyle(
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
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        content: const Text(
          'Are you sure you want to delete this review? This action cannot be undone.',
          style: const TextStyle(
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
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: review.albumImageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      review.albumImageUrl!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.music_note, size: 56);
                      },
                    ),
                  )
                : const Icon(Icons.music_note, size: 56),
            title: Text(
              review.title,
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              review.artist,
              style: const TextStyle(color: Colors.white70),
            ),
            trailing: Text(
              review.displayName,
              style: const TextStyle(color: Colors.white60),
            ),
          ),
          const SizedBox(height: 8),
          // Rating and Review Section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rating Bar
              RatingBar(
                minRating: 0,
                maxRating: 5,
                allowHalfRating: true,
                initialRating: review.score,
                itemSize: 24,
                itemPadding: const EdgeInsets.symmetric(horizontal: 2.0),
                ratingWidget: RatingWidget(
                  full: const Icon(Icons.star, color: Colors.amber),
                  empty: const Icon(Icons.star, color: Colors.grey),
                  half: const Icon(Icons.star_half, color: Colors.amber),
                ),
                ignoreGestures: true, // Make it read-only
                onRatingUpdate: (rating) {
                  // Do nothing - this is display only
                },
              ),
              const SizedBox(height: 8),
              // Review Text
              Text(
                review.review,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.0,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
