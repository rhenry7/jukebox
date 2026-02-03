import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_test_project/GIFs/gifs.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/Api/apis.dart';
import 'package:flutter_test_project/ui/screens/feed/comments_responding_to_post.dart';
import 'package:flutter_test_project/ui/screens/feed/user_profile_interaction_dialog.dart';
import 'package:gap/gap.dart';

class SubComments extends StatefulWidget {
  final String title;
  final String imageUrl;
  final String userId;
  final String displayName;
  final String reviews;
  final String joinDate;
  // final String ratingValue;
  const SubComments({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.userId,
    required this.displayName,
    required this.joinDate,
    required this.reviews,
  });

  @override
  State<SubComments> createState() => SubCommentLists();
}

class SubCommentLists extends State<SubComments> {
  late Future<List<Review>> comments;
  double? _rating;

  @override
  void initState() {
    super.initState();
    comments = fetchMockUserComments();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Column(
        children: [
          const Gap(50),
          const Padding(
            padding: EdgeInsets.only(left: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                BackButton(color: Colors.white),
              ],
            ),
          ),
          Padding(
              padding: const EdgeInsets.only(left: 4.0),
              // ADD ALBUM ART, ARTIST, AND PARENT COMMENT INFO
              child: Card(
                elevation: 1,
                margin: const EdgeInsets.all(0),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  side: BorderSide(color: Color.fromARGB(56, 158, 158, 158)),
                ),

                //margin: const EdgeInsets.all(0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(0.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              title: Text(widget.title),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(0.0),
                          child: SizedBox(
                            height: 300.0,
                            child: Ink.image(
                              image: NetworkImage(widget.imageUrl),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          // TODO: use comment data from object passed as prop
                          child: Text(
                            'Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo. Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit',
                            maxLines: 3,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.0,
                              fontStyle: FontStyle.italic,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                FutureBuilder<List<Review>>(
                                  future: comments,
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      final userReviewInfo = snapshot.data!;
                                      return UserProfileInteractionDialog(
                                        displayName: widget.displayName,
                                        reviewCount: 1,
                                        accountCreationDate: widget
                                            .joinDate, // Replace with actual date
                                      );
                                    } else if (snapshot.hasError) {
                                      return const Text('error found: no user');
                                    }
                                    return const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: DiscoBallLoading(),
                                    );
                                  },
                                ),
                              ],
                            ),
                            // RATING BAR
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: RatingBar(
                                  minRating: 1,
                                  maxRating: 5,
                                  allowHalfRating: false,
                                  itemSize: 18,
                                  itemPadding: const EdgeInsets.symmetric(
                                      horizontal: 2.0),
                                  ratingWidget: RatingWidget(
                                    full: const Icon(Icons.star,
                                        color: Colors.white),
                                    empty: const Icon(Icons.star,
                                        color: Colors.white),
                                    half: const Icon(Icons.star_half,
                                        color: Colors.white),
                                  ),
                                  onRatingUpdate: (rating) {
                                    rating;
                                  }),
                            ),
                          ]),
                    ),
                  ],
                ),
              )),
          // SUB COMMENTS
          CommentsRespondingToPost(
            comments: comments,
          ),
        ],
      ),
    );
  }
}
