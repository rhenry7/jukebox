import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' as flutter;
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_test_project/Types/userComments.dart';
import 'package:flutter_test_project/apis.dart';
import 'package:flutter_test_project/loadingWidget.dart';
import 'package:flutter_test_project/subComments.dart';
import 'package:gap/gap.dart';
import 'package:ionicons/ionicons.dart';
import 'package:spotify/spotify.dart';

import 'helpers.dart';

class CommentWidget extends StatefulWidget {
  const CommentWidget({super.key});
  @override
  CommentWidgetState createState() => CommentWidgetState();
}

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
  Color _middleIconColor = Colors.white;
  //late Future<List<UserComment>> comments;
  late Future<List<Album>> albums;
  late Future<CommentWithMusicInfo>
      comments; // Future to handle both comments and albums

  @override
  void initState() {
    super.initState();
    comments = fetchCombinedData();
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
            child: const Column(
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
                            final String? largeImageUrl =
                                albumImages!.isNotEmpty
                                    ? albumImages.first.url
                                    : "";
                            final smallImageUrl = albumImages.isNotEmpty
                                ? albumImages.last.url
                                : null;

                            return Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: GestureDetector(
                                onTap: () {
                                  // Navigate to DetailPage on tap
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => SubComments(
                                              title: album.name ?? "",
                                              imageUrl: largeImageUrl ?? "",
                                            )),
                                  );
                                },
                                child: Card(
                                    elevation: 1,
                                    margin: const EdgeInsets.all(0),
                                    shape: const RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.all(Radius.circular(8)),
                                      side: BorderSide(
                                          color: Color.fromARGB(
                                              56, 158, 158, 158)),
                                    ),
                                    color: Colors.black,
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
                                                  MainAxisAlignment
                                                      .spaceBetween,
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
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    Text(
                                                      comment.name,
                                                      style: const TextStyle(
                                                          fontSize: 14.0,
                                                          fontWeight:
                                                              FontWeight.normal,
                                                          color: Colors.white),
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
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                // VIEW MORE BUTTON
                                                Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 12.0),
                                                  child: RatingBar(
                                                      minRating: 3,
                                                      maxRating: 3,
                                                      allowHalfRating: false,
                                                      ignoreGestures: true,
                                                      itemSize: 18,
                                                      itemPadding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                              horizontal: 2.0),
                                                      ratingWidget:
                                                          RatingWidget(
                                                        full: const Icon(
                                                            Icons.star,
                                                            color:
                                                                Colors.yellow),
                                                        empty: const Icon(
                                                            Icons.star,
                                                            color:
                                                                Colors.yellow),
                                                        half: const Icon(
                                                            Icons.star_half,
                                                            color:
                                                                Colors.white),
                                                      ),
                                                      onRatingUpdate: (rating) {
                                                        rating;
                                                      }),
                                                ),
                                              ],
                                            ),
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
                                                    errorBuilder: (context,
                                                        error, stackTrace) {
                                                      return const Icon(Icons
                                                          .error); // Placeholder icon or widget
                                                    },
                                                    loadingBuilder: (context,
                                                        child,
                                                        loadingProgress) {
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
                                                    maxLines: 5,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12.0,
                                                      fontStyle:
                                                          FontStyle.italic,
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

                                          // Padding(
                                          //   padding: const EdgeInsets.all(5),
                                          //   child: Row(
                                          //     mainAxisAlignment:
                                          //         MainAxisAlignment.spaceBetween,
                                          //     children: <Widget>[
                                          //       // LIKES
                                          //       Padding(
                                          //         padding:
                                          //             const EdgeInsets.all(0),
                                          //         child: Row(
                                          //           children: [
                                          //             Padding(
                                          //               padding:
                                          //                   const EdgeInsets.all(
                                          //                       0.0),
                                          //               child: Row(
                                          //                 mainAxisAlignment:
                                          //                     MainAxisAlignment
                                          //                         .start,
                                          //                 children: [
                                          //                   Row(
                                          //                     children: [
                                          //                       IconButton(
                                          //                         icon: const Icon(
                                          //                             Ionicons
                                          //                                 .heart_outline,
                                          //                             color: Colors
                                          //                                 .white),
                                          //                         onPressed: () {
                                          //                           setState(() {
                                          //                             "Liked!";
                                          //                             Icons
                                          //                                 .thumb_up;
                                          //                             _middleIconColor =
                                          //                                 Colors
                                          //                                     .white;
                                          //                           });
                                          //                         },
                                          //                       ),
                                          //                       InkWell(
                                          //                         onTap: () {
                                          //                           print(
                                          //                               "tapped inkwell, should route");
                                          //                         },
                                          //                         child: Text(
                                          //                           comment.likes
                                          //                               .toString(),
                                          //                           style: const TextStyle(
                                          //                               color: Colors
                                          //                                   .white),
                                          //                         ),
                                          //                       ),
                                          //                     ],
                                          //                   ),
                                          //                 ],
                                          //               ),
                                          //             )
                                          //           ],
                                          //         ),
                                          //       ),
                                          //       // REPLIES
                                          //       Padding(
                                          //         padding:
                                          //             const EdgeInsets.all(0),
                                          //         child: Row(
                                          //           children: [
                                          //             Padding(
                                          //               padding:
                                          //                   const EdgeInsets.only(
                                          //                       right: 0),
                                          //               child: Row(
                                          //                 children: [
                                          //                   IconButton(
                                          //                     icon: const Icon(
                                          //                         Ionicons
                                          //                             .chatbubble_outline,
                                          //                         color: Colors
                                          //                             .white),
                                          //                     onPressed: () {
                                          //                       Navigator.push(
                                          //                           context,
                                          //                           MaterialPageRoute(
                                          //                               builder: (BuildContext
                                          //                                       context) =>
                                          //                                   SubComments(
                                          //                                     title:
                                          //                                         album.name ?? "",
                                          //                                     imageUrl:
                                          //                                         largeImageUrl ?? "",
                                          //                                   )));
                                          //                     },
                                          //                   ),
                                          //                   Text(
                                          //                       comment.replies
                                          //                           .toString(),
                                          //                       style: const TextStyle(
                                          //                           color: Colors
                                          //                               .white)),
                                          //                 ],
                                          //               ),
                                          //             )
                                          //           ],
                                          //         ),
                                          //       ),
                                          //       // REPOSTS
                                          //       Padding(
                                          //         padding:
                                          //             const EdgeInsets.all(0),
                                          //         child: Row(
                                          //           children: [
                                          //             Padding(
                                          //               padding:
                                          //                   const EdgeInsets.all(
                                          //                       0),
                                          //               child: Row(
                                          //                 children: [
                                          //                   IconButton(
                                          //                     icon: const Icon(
                                          //                         Ionicons.repeat,
                                          //                         color: Colors
                                          //                             .white),
                                          //                     onPressed: () {
                                          //                       setState(() {
                                          //                         "Liked!";
                                          //                         Icons.thumb_up;
                                          //                         _middleIconColor =
                                          //                             Colors
                                          //                                 .white;
                                          //                       });
                                          //                     },
                                          //                   ),
                                          //                   Text(
                                          //                       comment.reposts
                                          //                           .toString(),
                                          //                       style: const TextStyle(
                                          //                           color: Colors
                                          //                               .white)),
                                          //                 ],
                                          //               ),
                                          //             )
                                          //           ],
                                          //         ),
                                          //       ),
                                          //       // SHARES
                                          //       Padding(
                                          //         padding:
                                          //             const EdgeInsets.all(0),
                                          //         child: Row(
                                          //           children: [
                                          //             Padding(
                                          //               padding:
                                          //                   const EdgeInsets.only(
                                          //                       right: 0),
                                          //               child: Row(
                                          //                 children: [
                                          //                   IconButton(
                                          //                     icon: const Icon(
                                          //                         Ionicons
                                          //                             .paper_plane_outline,
                                          //                         color: Colors
                                          //                             .white),
                                          //                     onPressed: () {
                                          //                       setState(() {
                                          //                         "Liked!";
                                          //                         Icons.thumb_up;
                                          //                         _middleIconColor =
                                          //                             Colors
                                          //                                 .white;
                                          //                       });
                                          //                     },
                                          //                   ),
                                          //                   Text(
                                          //                       comment.shares
                                          //                           .toString(),
                                          //                       style: const TextStyle(
                                          //                           color: Colors
                                          //                               .white)),
                                          //                 ],
                                          //               ),
                                          //             )
                                          //           ],
                                          //         ),
                                          //       ),

                                          //     ],
                                          //   ),
                                          // ),
                                        ],
                                      ),
                                    )),
                              ),
                            );
                          });
                    } else if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}');
                    }
                    return const LoadingWidget();
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
