import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_test_project/apis.dart';
import 'package:flutter_test_project/Types/userComments.dart';
import 'package:flutter_test_project/categoryTapBar.dart';
import 'package:gap/gap.dart';
import 'package:ionicons/ionicons.dart';
import 'package:spotify/spotify.dart';
import 'package:flutter/widgets.dart' as flutter;

class CommentWidget extends StatefulWidget {
  const CommentWidget({super.key});
  @override
  CommentWidgetState createState() => CommentWidgetState();
}

class HeaderTextStyle {
  static TextStyle extraLarge = TextStyle(
    fontSize: 38,
    color: Colors.white,
    fontWeight: FontWeight.bold,
    wordSpacing: 0.1,
  );
  static const TextStyle large = TextStyle(
    fontSize: 24,
    color: Colors.black,
    fontWeight: FontWeight.bold,
  );
}

// This is dumb. I shouldnt have to fuse these two types together, especially since I just want the data for only the album info

class CommentWithMusicInfo {
  final List<UserComment> comments;
  final List<Album> albums;

  CommentWithMusicInfo({
    required this.comments,
    required this.albums,
  });
}

Future<CommentWithMusicInfo> fetchCombinedData() async {
  final results = await Future.wait([
    fetchMockUserComments(), // Future for comments
    fetchSpotifyAlbums(), // Future for albums
  ]);

  return CommentWithMusicInfo(
    comments: results[0] as List<UserComment>,
    albums: results[1] as List<Album>,
  );
}

class CommentWidgetState extends State<CommentWidget> {
  // Define state variables
  Color _middleIconColor = Colors.black;
  //late Future<List<UserComment>> comments;
  late Future<List<Album>> albums;
  late Future<CommentWithMusicInfo>
      comments; // Future to handle both comments and albums

  @override
  void initState() {
    super.initState();
    comments = fetchCombinedData();
  }

  String formatDateTimeDifference(String isoDateTime) {
    DateTime dateTime = DateTime.parse(isoDateTime);
    Duration difference = DateTime.now().difference(dateTime);

    if (difference.inDays >= 1) {
      return '${difference.inDays}d';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes}m';
    } else {
      return '${difference.inSeconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Container(
      padding: const EdgeInsets.only(left: 2, top: 10),
      child: Column(
        children: [
          Container(
            //color: Colors.blue,
            alignment: Alignment.bottomLeft,
            padding: const EdgeInsets.only(left: 10),
            child: Column(
              children: [
                Gap(10),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
                child: Column(
              children: [
                FutureBuilder<CommentWithMusicInfo>(
                  future: comments,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return ListView.builder(
                          itemCount: snapshot.data!.albums.length,
                          physics:
                              const NeverScrollableScrollPhysics(), // Disable scrolling for ListView
                          shrinkWrap: true, // Take only the necessary space
                          itemBuilder: (context, index) {
                            final comment = snapshot.data!.comments[index];
                            final album = snapshot.data!.albums[index];
                            final albumImages = album.images;
                            final smallImageUrl = albumImages!.isNotEmpty
                                ? albumImages.last.url
                                : null;

                            return Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Card(
                                  elevation: 1,
                                  margin: const EdgeInsets.all(0),
                                  shape: const RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(8)),
                                    side: BorderSide(
                                        color:
                                            Color.fromARGB(56, 158, 158, 158)),
                                  ),
                                  color: Colors.white,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        // NAME AND TIME
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              right: 8.0,
                                              left: 10.0,
                                              top: 10.0,
                                              bottom: 0.0),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              // USER POST INFO ROW
                                              Row(
                                                children: [
                                                  const Padding(
                                                    padding: EdgeInsets.only(
                                                        right: 5),
                                                    child: Icon(
                                                      Ionicons
                                                          .person_circle_outline,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                  Text(
                                                    comment.name,
                                                    style: const TextStyle(
                                                        fontSize: 14.0,
                                                        fontWeight:
                                                            FontWeight.normal,
                                                        color: Colors.black),
                                                  ),
                                                  // TIME STAMP
                                                  Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 2.0),
                                                    child: Text(
                                                      formatDateTimeDifference(
                                                          comment.time
                                                              .toIso8601String()),
                                                      style: const TextStyle(
                                                        fontSize: 12.0,
                                                        color: Colors.black,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              // VIEW MORE BUTTON
                                              ElevatedButton(
                                                child: Icon(Ionicons
                                                    .ellipsis_horizontal_circle),
                                                onPressed: () => print("hey"),
                                                // ignore: prefer_const_constructors
                                                style: ButtonStyle(
                                                  elevation:
                                                      MaterialStateProperty.all(
                                                          0.0),
                                                  backgroundColor:
                                                      MaterialStateProperty.all<
                                                              Color>(
                                                          const Color.fromARGB(
                                                              0,
                                                              255,
                                                              224,
                                                              130)),
                                                ),
                                              )
                                            ],
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12.0),
                                          child: RatingBar(
                                              minRating: 3,
                                              maxRating: 3,
                                              allowHalfRating: true,
                                              itemSize: 18,
                                              itemPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 2.0),
                                              ratingWidget: RatingWidget(
                                                full: const Icon(Icons.star,
                                                    color: Colors.black),
                                                empty: const Icon(Icons.star,
                                                    color: Colors.black),
                                                half: const Icon(
                                                    Icons.star_half,
                                                    color: Colors.black),
                                              ),
                                              onRatingUpdate: (rating) {
                                                rating;
                                              }),
                                        ),
                                        // Middle Row (Text and Icon)
                                        // COMMENT AND IMAGE
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              left: 12.0,
                                              top: 14.0,
                                              right: 10.0),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            children: <Widget>[
                                              // COMMENT

                                              // IMAGE
                                              Padding(
                                                padding: const flutter
                                                    .EdgeInsets.only(
                                                    right: 10.0),
                                                child: flutter.Image.network(
                                                  smallImageUrl ?? "",
                                                  errorBuilder: (context, error,
                                                      stackTrace) {
                                                    return const Icon(Icons
                                                        .error); // Placeholder icon or widget
                                                  },
                                                  loadingBuilder: (context,
                                                      child, loadingProgress) {
                                                    if (loadingProgress ==
                                                        null) {
                                                      return child;
                                                    } else {
                                                      return const Center(
                                                          child:
                                                              CircularProgressIndicator()); // Loading indicator
                                                    }
                                                  },
                                                ),
                                              ),

                                              Flexible(
                                                child: Text(
                                                  comment.comment,
                                                  maxLines: 3,
                                                  style: const TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 12.0,
                                                    fontStyle: FontStyle.italic,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),

                                              const SizedBox(width: 8.0),
                                            ],
                                          ),
                                        ),
                                        // Bottom Row (Icons)
                                        Padding(
                                          padding: const EdgeInsets.all(10),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: <Widget>[
                                              // LIKES
                                              Padding(
                                                padding:
                                                    const EdgeInsets.all(0),
                                                child: Row(
                                                  children: [
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              0.0),
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              IconButton(
                                                                icon: const Icon(
                                                                    Ionicons
                                                                        .heart_outline,
                                                                    color: Colors
                                                                        .black),
                                                                onPressed: () {
                                                                  setState(() {
                                                                    "Liked!";
                                                                    Icons
                                                                        .thumb_up;
                                                                    _middleIconColor =
                                                                        Colors
                                                                            .black;
                                                                  });
                                                                },
                                                              ),
                                                              Text(
                                                                comment.likes
                                                                    .toString(),
                                                                style: TextStyle(
                                                                    color: Colors
                                                                        .black),
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
                                                padding:
                                                    const EdgeInsets.all(0),
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
                                                                color: Colors
                                                                    .black),
                                                            onPressed: () {
                                                              setState(() {
                                                                "Liked!";
                                                                Icons.thumb_up;
                                                                _middleIconColor =
                                                                    Colors
                                                                        .black;
                                                              });
                                                            },
                                                          ),
                                                          Text(
                                                              comment.replies
                                                                  .toString(),
                                                              style: TextStyle(
                                                                  color: Colors
                                                                      .black)),
                                                        ],
                                                      ),
                                                    )
                                                  ],
                                                ),
                                              ),
                                              // REPOSTS
                                              Padding(
                                                padding:
                                                    const EdgeInsets.all(0),
                                                child: Row(
                                                  children: [
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              0),
                                                      child: Row(
                                                        children: [
                                                          IconButton(
                                                            icon: const Icon(
                                                                Ionicons.repeat,
                                                                color: Colors
                                                                    .black),
                                                            onPressed: () {
                                                              setState(() {
                                                                "Liked!";
                                                                Icons.thumb_up;
                                                                _middleIconColor =
                                                                    Colors
                                                                        .black;
                                                              });
                                                            },
                                                          ),
                                                          Text(
                                                              comment.reposts
                                                                  .toString(),
                                                              style: TextStyle(
                                                                  color: Colors
                                                                      .black)),
                                                        ],
                                                      ),
                                                    )
                                                  ],
                                                ),
                                              ),
                                              // SHARES
                                              Padding(
                                                padding:
                                                    const EdgeInsets.all(0),
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
                                                                color: Colors
                                                                    .black),
                                                            onPressed: () {
                                                              setState(() {
                                                                "Liked!";
                                                                Icons.thumb_up;
                                                                _middleIconColor =
                                                                    Colors
                                                                        .black;
                                                              });
                                                            },
                                                          ),
                                                          Text(
                                                              comment.shares
                                                                  .toString(),
                                                              style: TextStyle(
                                                                  color: Colors
                                                                      .black)),
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
                            );
                          });
                    } else if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}');
                    }
                    return const CircularProgressIndicator();
                  },
                )
              ],
            )),
          ),
        ],
      ),
    ));
  }
}
