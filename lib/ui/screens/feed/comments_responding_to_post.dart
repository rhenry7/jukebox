import 'package:flutter/material.dart';
import 'package:flutter_test_project/GIFs/gifs.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:ionicons/ionicons.dart';

class CommentsRespondingToPost extends StatelessWidget {
  final Future<List<Review>> comments;
  const CommentsRespondingToPost({super.key, required this.comments});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SingleChildScrollView(
        child: Column(
          children: [
            Center(
              child: FutureBuilder<List<Review>>(
                future: comments,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Padding(
                      padding: const EdgeInsets.all(0.0),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: snapshot.data!.length,
                        physics:
                            const NeverScrollableScrollPhysics(), // Disable
                        shrinkWrap: true,
                        itemBuilder: (context, index) {
                          /**
                                 * Because there is only one source for mock data for subcomments, the first subcomment user will show as the same user who made the initial review. To fix this, I am skipping that inital user in the line below. This is not a good solution, and can be approved by having additional mock users or real users.
                                 */
                          final comment = snapshot.data![
                              index]; // TODO: REPLACE WHEN WE HAVE ACTUAL USERS
                          //print(track);
                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.all(5),
                            shape: const RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8)),
                              side: BorderSide(
                                  color: Color.fromARGB(56, 158, 158, 158)),
                            ),

                            //margin: const EdgeInsets.all(0),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(0.0),
                                  child: Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: ListTile(
                                          leading: const Icon(Ionicons
                                              .person_circle_outline), // Fallback if no image is available,
                                          title: Text(comment.displayName),
                                          //subtitle: Text(comment.), use post time data
                                        ),
                                      ),
                                      //Text(comment.comment),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    comment.review,
                                    maxLines: 3,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.0,
                                      fontStyle: FontStyle.italic,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: <Widget>[
                                      // LIKES
                                      Padding(
                                        padding: const EdgeInsets.all(0),
                                        child: Row(
                                          children: [
                                            Padding(
                                              padding:
                                                  const EdgeInsets.all(0.0),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      IconButton(
                                                        icon: const Icon(
                                                            Ionicons
                                                                .heart_outline,
                                                            color:
                                                                Colors.white),
                                                        onPressed: () {
                                                          // Navigator.push(
                                                          //     context,
                                                          //     MaterialPageRoute(
                                                          //         builder: (BuildContext
                                                          //                 context) =>
                                                          //             const SubComments()));
                                                          // setState(() {
                                                          //   "Liked!";
                                                          //   Icons.thumb_up;
                                                          // });
                                                        },
                                                      ),
                                                      InkWell(
                                                        onTap: () {
                                                          print(
                                                              "tapped inkwell, should route");
                                                        },
                                                        child: Text(
                                                          comment.likes
                                                              .toString(),
                                                          style:
                                                              const TextStyle(
                                                                  color: Colors
                                                                      .white),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            )
                                          ],
                                        ),
                                      ),
                                      // REPLIES
                                      Padding(
                                        padding: const EdgeInsets.all(0),
                                        child: Row(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  right: 0),
                                              child: Row(
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(
                                                        Ionicons
                                                            .chatbubble_outline,
                                                        color: Colors.white),
                                                    onPressed: () {
                                                      // setState(() {
                                                      //   "Liked!";
                                                      //   Icons.thumb_up;
                                                      // });
                                                    },
                                                  ),
                                                  Text(
                                                      comment.replies
                                                          .toString(),
                                                      style: const TextStyle(
                                                          color: Colors.white)),
                                                ],
                                              ),
                                            )
                                          ],
                                        ),
                                      ),
                                      // REPOSTS
                                      Padding(
                                        padding: const EdgeInsets.all(0),
                                        child: Row(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.all(0),
                                              child: Row(
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(
                                                        Ionicons.repeat,
                                                        color: Colors.white),
                                                    onPressed: () {
                                                      // thumbs up
                                                    },
                                                  ),
                                                  Text(
                                                      comment.reposts
                                                          .toString(),
                                                      style: const TextStyle(
                                                          color: Colors.white)),
                                                ],
                                              ),
                                            )
                                          ],
                                        ),
                                      ),
                                      // SHARES
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(right: 4.0),
                                        child: Row(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  right: 0),
                                              child: Row(
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(
                                                        Ionicons
                                                            .paper_plane_outline,
                                                        color: Colors.white),
                                                    onPressed: () {
                                                      // setState(() {
                                                      //   "Liked!";
                                                      //   Icons.thumb_up;
                                                      // });
                                                      // add state, update DB and UI to reflect change
                                                    },
                                                  ),
                                                  Text(
                                                      comment.reposts
                                                          .toString(),
                                                      style: const TextStyle(
                                                          color: Colors.white)),
                                                ],
                                              ),
                                            )
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  } else if (snapshot.hasError) {
                    print(snapshot);
                    return Text('Error: ${snapshot.error}');
                  }
                  return const DiscoBallLoading();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
