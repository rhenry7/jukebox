import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_test_project/Types/userComments.dart';
import 'package:flutter_test_project/apis.dart';
import 'package:flutter/widgets.dart' as flutter;
import 'package:ionicons/ionicons.dart';
import 'package:spotify/spotify.dart';
import 'package:gap/gap.dart';

class SubComments extends StatefulWidget {
  const SubComments({super.key});

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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          // ADD ALBUM ART, ARTIST, AND PARENT COMMENT INFO
          child: Container(
            height: 250.0,
            color: Colors.blue,
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const Gap(10),
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
                                            leading: Icon(Ionicons
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
                                                              color:
                                                                  Colors.white),
                                                          onPressed: () {
                                                            Navigator.push(
                                                                context,
                                                                MaterialPageRoute(
                                                                    builder: (BuildContext
                                                                            context) =>
                                                                        SubComments()));
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
                                                        setState(() {
                                                          "Liked!";
                                                          Icons.thumb_up;
                                                        });
                                                      },
                                                    ),
                                                    Text(
                                                        comment.replies
                                                            .toString(),
                                                        style: const TextStyle(
                                                            color:
                                                                Colors.white)),
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
                                                          color: Colors.white),
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
                                                        style: const TextStyle(
                                                            color:
                                                                Colors.white)),
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
                                                        setState(() {
                                                          "Liked!";
                                                          Icons.thumb_up;
                                                        });
                                                      },
                                                    ),
                                                    Text(
                                                        comment.shares
                                                            .toString(),
                                                        style: const TextStyle(
                                                            color:
                                                                Colors.white)),
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
                      return const CircularProgressIndicator();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
