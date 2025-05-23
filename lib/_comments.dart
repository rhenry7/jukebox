import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'Types/reviewTypes.dart';

class ReviewsList extends StatelessWidget {
  final String userId = FirebaseAuth.instance.currentUser != null
      ? FirebaseAuth.instance.currentUser!.uid
      : "";

  ReviewsList();

  @override
  Widget build(BuildContext context) {
    if (userId.isEmpty) {
      return Center(child: Text('User not logged in.'));
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
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No reviews found.'));
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
                    padding: EdgeInsets.all(8.0),

                    width:
                        double.infinity, // Ensure the card has a defined width

                    child: Column(
                      children: [
                        ListTile(
                          leading: review.albumImageUrl != null
                              ? Image.network(review.albumImageUrl!)
                              : Icon(Icons.music_note),
                          title: Text(review.title),
                          subtitle: Text(
                              'Artist: ${review.artist}\nScore: ${review.score}'),
                          trailing: Text(review.userName),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
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
