import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:gap/gap.dart';

import '../../../models/review.dart';

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

        return Container(
            decoration: const BoxDecoration(),
            margin: const EdgeInsets.symmetric(),
            padding: const EdgeInsets.symmetric(),
            child: Column(
              children: [
                const Gap(10),
                Expanded(
                  child: FriendsReviewList(reviews: reviews),
                ),
              ],
            ));
      },
    );
  }
}

class FriendsReviewList extends StatelessWidget {
  final List<Review> reviews;
  const FriendsReviewList({super.key, required this.reviews});
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: reviews.length,
      itemBuilder: (context, index) {
        var review = reviews[index];
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Card(
            elevation: 1,
            margin: const EdgeInsets.all(0),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              side: BorderSide(color: Color.fromARGB(56, 158, 158, 158)),
            ),
            color: Colors.black,
            child: Padding(
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
                        itemPadding:
                            const EdgeInsets.symmetric(horizontal: 2.0),
                        ratingWidget: RatingWidget(
                          full: const Icon(Icons.star, color: Colors.amber),
                          empty: const Icon(Icons.star, color: Colors.grey),
                          half:
                              const Icon(Icons.star_half, color: Colors.amber),
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
            ),
          ),
        );
      },
    );
  }
}
