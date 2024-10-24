import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_test_project/Types/userComments.dart';
import 'package:flutter_test_project/apis.dart';
import 'package:flutter_test_project/loadingWidget.dart';
import 'package:gap/gap.dart';
import 'package:ionicons/ionicons.dart';

class SubComments extends StatefulWidget {
  final String title;
  final String imageUrl;
  // final String ratingValue;
  const SubComments({super.key, required this.title, required this.imageUrl});

  @override
  State<SubComments> createState() => SubCommentLists();
}

class SubCommentLists extends State<SubComments> {
  late Future<List<UserComment>> comments;
  double? _rating;

  @override
  void initState() {
    super.initState();
    comments = fetchMockUserComments();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          const Gap(50),
          Padding(
              padding: const EdgeInsets.all(0.0),
              // ADD ALBUM ART, ARTIST, AND PARENT COMMENT INFO
              child: Card(
                elevation: 0,
                //margin: const EdgeInsets.all(0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(0.0),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: ListTile(
                              // leading: Icon(Ionicons
                              //     .person_circle_outline), // Fallback if no image is available,
                              title: Text(widget.title),
                              //subtitle: Text(comment.), use post time data
                            ),
                          ),
                          //Text(comment.comment),
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
                            "Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo. Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit",
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
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Padding(
                                  padding:
                                      EdgeInsets.only(left: 3.0, right: 5.0),
                                  child: Icon(Ionicons.person_circle_outline),
                                ),
                                Text("UserName")
                              ],
                            ),
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
                    Padding(
                      padding: const EdgeInsets.all(0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          // LIKES
                          Padding(
                            padding: const EdgeInsets.all(0),
                            child: Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(0.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                                Ionicons.heart_outline,
                                                color: Colors.white),
                                            onPressed: () {
                                              // Navigator.push(
                                              //     context,
                                              //     MaterialPageRoute(
                                              //         builder: (BuildContext
                                              //                 context) =>
                                              //             const SubComments()));
                                              setState(() {
                                                "Liked!";
                                                Icons.thumb_up;
                                              });
                                            },
                                          ),
                                          InkWell(
                                            onTap: () {
                                              print(
                                                  "tapped inkwell, should route");
                                            },
                                            child: Text(
                                              "1231".toString(),
                                              style: const TextStyle(
                                                  color: Colors.white),
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
                                  padding: const EdgeInsets.only(right: 0),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                            Ionicons.chatbubble_outline,
                                            color: Colors.white),
                                        onPressed: () {
                                          setState(() {
                                            "Liked!";
                                            Icons.thumb_up;
                                          });
                                        },
                                      ),
                                      Text("1231".toString(),
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
                                        icon: const Icon(Ionicons.repeat,
                                            color: Colors.white),
                                        onPressed: () {
                                          setState(() {
                                            "Liked!";
                                            Icons.thumb_up;
                                          });
                                        },
                                      ),
                                      Text("123".toString(),
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
                            padding: const EdgeInsets.all(0),
                            child: Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 0),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                            Ionicons.paper_plane_outline,
                                            color: Colors.white),
                                        onPressed: () {
                                          setState(() {
                                            "Liked!";
                                            Icons.thumb_up;
                                          });
                                        },
                                      ),
                                      Text("23134".toString(),
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
              )),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Center(
                    child: FutureBuilder<List<UserComment>>(
                      future: comments,
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return ListView.builder(
                            itemCount: snapshot.data!.length,
                            physics:
                                const NeverScrollableScrollPhysics(), // Disable
                            shrinkWrap: true,
                            itemBuilder: (context, index) {
                              final comment = snapshot.data![index];

                              //print(track);
                              return Card(
                                elevation: 0,
                                //margin: const EdgeInsets.all(0),
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Row(
                                        children: <Widget>[
                                          Expanded(
                                            child: ListTile(
                                              leading: const Icon(Ionicons
                                                  .person_add_outline), // Fallback if no image is available,
                                              title: Text(comment.name),
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
                                        comment.comment,
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
                                                                color: Colors
                                                                    .white),
                                                            onPressed: () {
                                                              // Navigator.push(
                                                              //     context,
                                                              //     MaterialPageRoute(
                                                              //         builder: (BuildContext
                                                              //                 context) =>
                                                              //             const SubComments()));
                                                              setState(() {
                                                                "Liked!";
                                                                Icons.thumb_up;
                                                              });
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
                                                              style: const TextStyle(
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
                                                  padding:
                                                      const EdgeInsets.only(
                                                          right: 0),
                                                  child: Row(
                                                    children: [
                                                      IconButton(
                                                        icon: const Icon(
                                                            Ionicons
                                                                .chatbubble_outline,
                                                            color:
                                                                Colors.white),
                                                        onPressed: () {
                                                          setState(() {
                                                            "Liked!";
                                                            Icons.thumb_up;
                                                          });
                                                        },
                                                      ),
                                                      Text(
                                                          comment.replies
                                                              .toString(),
                                                          style:
                                                              const TextStyle(
                                                                  color: Colors
                                                                      .white)),
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
                                                  padding:
                                                      const EdgeInsets.all(0),
                                                  child: Row(
                                                    children: [
                                                      IconButton(
                                                        icon: const Icon(
                                                            Ionicons.repeat,
                                                            color:
                                                                Colors.white),
                                                        onPressed: () {
                                                          setState(() {
                                                            "Liked!";
                                                            Icons.thumb_up;
                                                          });
                                                        },
                                                      ),
                                                      Text(
                                                          comment.reposts
                                                              .toString(),
                                                          style:
                                                              const TextStyle(
                                                                  color: Colors
                                                                      .white)),
                                                    ],
                                                  ),
                                                )
                                              ],
                                            ),
                                          ),
                                          // SHARES
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                right: 4.0),
                                            child: Row(
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          right: 0),
                                                  child: Row(
                                                    children: [
                                                      IconButton(
                                                        icon: const Icon(
                                                            Ionicons
                                                                .paper_plane_outline,
                                                            color:
                                                                Colors.white),
                                                        onPressed: () {
                                                          setState(() {
                                                            "Liked!";
                                                            Icons.thumb_up;
                                                          });
                                                        },
                                                      ),
                                                      Text(
                                                          comment.shares
                                                              .toString(),
                                                          style:
                                                              const TextStyle(
                                                                  color: Colors
                                                                      .white)),
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
                          );
                        } else if (snapshot.hasError) {
                          print(snapshot);
                          return Text('Error: ${snapshot.error}');
                        }
                        return const LoadingWidget();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
