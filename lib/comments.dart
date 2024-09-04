import 'package:flutter/material.dart';
import 'package:flutter_test_project/apis.dart';
import 'package:flutter_test_project/Types/userComments.dart';
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
  static const TextStyle extraLarge = TextStyle(
    fontSize: 24,
    color: Color.fromRGBO(22, 110, 216, 1),
    fontWeight: FontWeight.bold,
  );
  static const TextStyle large = TextStyle(
    fontSize: 18,
    color: Color.fromRGBO(22, 110, 216, 1),
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
  Color _middleIconColor = Color.fromRGBO(22, 110, 216, 1);
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
      return '${difference.inDays} d';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours} h';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes} m';
    } else {
      return '${difference.inSeconds} s';
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
            child: const Column(
              children: [
                Gap(10),
                Text(
                  "Popular this week",
                  style: HeaderTextStyle.large,
                ),
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
                            final albumImages = album!.images;
                            final smallImageUrl = albumImages!.isNotEmpty
                                ? albumImages.last.url
                                : null;

                            return Card(
                                elevation: 0,
                                margin: const EdgeInsets.all(0),
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.horizontal(),
                                  side: BorderSide(
                                      color: Color.fromARGB(56, 158, 158, 158)),
                                ),
                                color: Colors.transparent,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    // NAME AND TIME
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          right: 8.0,
                                          left: 10.0,
                                          top: 10.0,
                                          bottom: 5.0),
                                      child: Row(
                                        children: [
                                          const Padding(
                                            padding: EdgeInsets.only(right: 5),
                                            child: Icon(
                                              Ionicons.person_circle_outline,
                                              color: Color.fromRGBO(
                                                  22, 110, 216, 1),
                                            ),
                                          ),
                                          Text(
                                            comment.name,
                                            style: const TextStyle(
                                                fontSize: 14.0,
                                                fontWeight: FontWeight.w500,
                                                color: Color.fromRGBO(
                                                    22, 110, 216, 1)),
                                          ),
                                          // TIME STAMP
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12.0),
                                            child: Text(
                                              formatDateTimeDifference(comment
                                                  .time
                                                  .toIso8601String()),
                                              style: const TextStyle(
                                                fontSize: 12.0,
                                                fontWeight: FontWeight.w300,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Middle Row (Text and Icon)
                                    // COMMENT AND IMAGE
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          left: 12.0, top: 4.0, right: 10.0),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: <Widget>[
                                          // COMMENT
                                          Flexible(
                                            child: Text(
                                              comment.comment,
                                              maxLines: 3,
                                              style: const TextStyle(
                                                fontSize: 12.0,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                          // IMAGE
                                          Padding(
                                            padding:
                                                const flutter.EdgeInsets.only(
                                                    right: 10.0),
                                            child: flutter.Image.network(
                                              smallImageUrl ?? "",
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                return const Icon(Icons
                                                    .error); // Placeholder icon or widget
                                              },
                                              loadingBuilder: (context, child,
                                                  loadingProgress) {
                                                if (loadingProgress == null) {
                                                  return child;
                                                } else {
                                                  return const Center(
                                                      child:
                                                          CircularProgressIndicator()); // Loading indicator
                                                }
                                              },
                                            ),
                                          ),

                                          const SizedBox(width: 8.0),
                                        ],
                                      ),
                                    ),
                                    // Bottom Row (Icons)
                                    Padding(
                                      padding: const EdgeInsets.all(0),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: <Widget>[
                                          // LIKES
                                          Padding(
                                            padding: const EdgeInsets.all(0),
                                            child: Row(
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          right: 8.0),
                                                  child: Row(
                                                    children: [
                                                      IconButton(
                                                        icon: const Icon(
                                                            Ionicons
                                                                .heart_outline,
                                                            color:
                                                                Color.fromRGBO(
                                                                    22,
                                                                    110,
                                                                    216,
                                                                    1)),
                                                        onPressed: () {
                                                          setState(() {
                                                            "Liked!";
                                                            Icons.thumb_up;
                                                            _middleIconColor =
                                                                Colors.blue;
                                                          });
                                                        },
                                                      ),
                                                      Text(comment.likes
                                                          .toString()),
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
                                                          right: 8.0),
                                                  child: Row(
                                                    children: [
                                                      IconButton(
                                                        icon: const Icon(
                                                            Ionicons
                                                                .chatbubble_outline,
                                                            color:
                                                                Color.fromRGBO(
                                                                    22,
                                                                    110,
                                                                    216,
                                                                    1)),
                                                        onPressed: () {
                                                          setState(() {
                                                            "Liked!";
                                                            Icons.thumb_up;
                                                            _middleIconColor =
                                                                Colors.blue;
                                                          });
                                                        },
                                                      ),
                                                      Text(comment.replies
                                                          .toString()),
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
                                                      const EdgeInsets.only(
                                                          right: 8.0),
                                                  child: Row(
                                                    children: [
                                                      IconButton(
                                                        icon: const Icon(
                                                            Ionicons.repeat,
                                                            color:
                                                                Color.fromRGBO(
                                                                    22,
                                                                    110,
                                                                    216,
                                                                    1)),
                                                        onPressed: () {
                                                          setState(() {
                                                            "Liked!";
                                                            Icons.thumb_up;
                                                            _middleIconColor =
                                                                Colors.blue;
                                                          });
                                                        },
                                                      ),
                                                      Text(comment.likes
                                                          .toString()),
                                                    ],
                                                  ),
                                                )
                                              ],
                                            ),
                                          ),
                                          // SHARES
                                          Padding(
                                            padding: const EdgeInsets.all(10),
                                            child: Row(
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          right: 10),
                                                  child: Row(
                                                    children: [
                                                      IconButton(
                                                        icon: const Icon(
                                                            Ionicons
                                                                .paper_plane_outline,
                                                            color:
                                                                Color.fromRGBO(
                                                                    22,
                                                                    110,
                                                                    216,
                                                                    1)),
                                                        onPressed: () {
                                                          setState(() {
                                                            "Liked!";
                                                            Icons.thumb_up;
                                                            _middleIconColor =
                                                                Colors.blue;
                                                          });
                                                        },
                                                      ),
                                                      Text(comment.shares
                                                          .toString()),
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
                                ));
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
