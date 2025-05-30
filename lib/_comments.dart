import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import 'Types/reviewTypes.dart';

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

  final double? _rating = 5.0;
  final String userId = FirebaseAuth.instance.currentUser != null
      ? FirebaseAuth.instance.currentUser!.uid
      : "";

  ReviewsList();

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

        return ListView.builder(
          itemCount: reviews.length,
          itemBuilder: (context, index) {
            var review = reviews[index];
            return SizedBox(
              width: double
                  .infinity, // Ensures the card takes up full width within the ListView

              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Card(
                  elevation: 1,
                  margin: const EdgeInsets.all(0),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    side: BorderSide(color: Color.fromARGB(56, 158, 158, 158)),
                  ),
                  color: Colors.black,
                  child: Container(
                    padding: const EdgeInsets.all(8.0),

                    width:
                        double.infinity, // Ensure the card has a defined width

                    child: Column(
                      children: [
                        ListTile(
                          leading: review.albumImageUrl != null
                              ? Image.network(review.albumImageUrl!)
                              : const Icon(Icons.music_note),
                          title: Text(review.title),
                          subtitle: Text(review.artist),
                          trailing: Text(review.userName),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              const Padding(
                                  padding: EdgeInsets.only(left: 0.0)),
                              Flexible(
                                flex: 1,
                                child: RatingBar(
                                  minRating: 0,
                                  maxRating: 5,
                                  allowHalfRating: true,
                                  initialRating: review.score,
                                  itemSize: 24,
                                  itemPadding: const EdgeInsets.symmetric(
                                      horizontal: 5.0),
                                  ratingWidget: RatingWidget(
                                    full: const Icon(Icons.star,
                                        color: Colors.amber),
                                    empty: const Icon(Icons.star,
                                        color: Colors.grey),
                                    half: const Icon(Icons.star_half,
                                        color: Colors.amber),
                                  ),
                                  onRatingUpdate: (rating) {
                                    rating = review.score;
                                    // setState(() {});
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(left: 0.0),
                                child: Flexible(
                                  flex: 1,
                                  child: Text(
                                    review.review,
                                    maxLines: 5,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.0,
                                      fontStyle: FontStyle.italic,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    softWrap: true,
                                    overflow: TextOverflow.clip,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
