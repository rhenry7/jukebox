import 'package:flutter/material.dart';
import 'package:flutter_test_project/apis.dart';
import 'package:flutter_test_project/Types/userComments.dart';
import 'package:gap/gap.dart';
import 'package:ionicons/ionicons.dart';

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

class CommentWidgetState extends State<CommentWidget> {
  // Define state variables
  Color _middleIconColor = Color.fromRGBO(22, 110, 216, 1);
  late Future<List<UserComment>> comments;

  @override
  void initState() {
    super.initState();
    comments = fetchMockUserComments();
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
      padding: EdgeInsets.only(left: 2, top: 10),
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
                FutureBuilder<List<UserComment>>(
                  future: comments,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return ListView.builder(
                          itemCount: snapshot.data!.length,
                          physics:
                              NeverScrollableScrollPhysics(), // Disable scrolling for ListView
                          shrinkWrap: true, // Take only the necessary space
                          itemBuilder: (context, index) {
                            final comment = snapshot.data![index];
                            return Card(
                                elevation: 0,
                                margin: const EdgeInsets.all(0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.horizontal(),
                                  side: BorderSide(
                                      color: const Color.fromARGB(
                                          56, 158, 158, 158)),
                                ),
                                color: Colors.transparent,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    // Top Text (Title)
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Row(
                                        children: [
                                          Text(
                                            comment.name,
                                            style: const TextStyle(
                                                fontSize: 14.0,
                                                fontWeight: FontWeight.w500,
                                                color: Color.fromRGBO(
                                                    22, 110, 216, 1)),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12.0),
                                            child: Text(
                                              formatDateTimeDifference(
                                                  comment.time.toIso8601String()
                                                      as String),
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
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          left: 12.0, top: 4.0, right: 10.0),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: <Widget>[
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
                                          const SizedBox(width: 8.0),
                                        ],
                                      ),
                                    ),
                                    // Bottom Row (Icons)
                                    Padding(
                                      padding: const EdgeInsets.all(0),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceAround,
                                        children: <Widget>[
                                          // LIKES
                                          Padding(
                                            padding: const EdgeInsets.all(0),
                                            child: Row(
                                              children: [
                                                IconButton(
                                                  icon: const Icon(
                                                      Ionicons.heart_outline,
                                                      color: Color.fromRGBO(
                                                          22, 110, 216, 1)),
                                                  onPressed: () {
                                                    setState(() {
                                                      "Liked!";
                                                      Icons.thumb_up;
                                                      _middleIconColor =
                                                          Colors.blue;
                                                    });
                                                  },
                                                ),
                                                Text(comment.likes.toString())
                                              ],
                                            ),
                                          ),
                                          // REPLIES
                                          Padding(
                                            padding: const EdgeInsets.all(0),
                                            child: Row(
                                              children: [
                                                IconButton(
                                                  icon: const Icon(
                                                      Ionicons
                                                          .chatbubble_outline,
                                                      color: Color.fromRGBO(
                                                          22, 110, 216, 1)),
                                                  onPressed: () {
                                                    setState(() {
                                                      "Liked!";
                                                      Icons.thumb_up;
                                                      _middleIconColor =
                                                          Colors.blue;
                                                    });
                                                  },
                                                ),
                                                Text(comment.replies.toString())
                                              ],
                                            ),
                                          ),
                                          // REPOSTS
                                          Padding(
                                            padding: const EdgeInsets.all(0),
                                            child: Row(
                                              children: [
                                                IconButton(
                                                  icon: const Icon(
                                                      Ionicons.repeat,
                                                      color: Color.fromRGBO(
                                                          22, 110, 216, 1)),
                                                  onPressed: () {
                                                    setState(() {
                                                      "Liked!";
                                                      Icons.thumb_up;
                                                      _middleIconColor =
                                                          Colors.blue;
                                                    });
                                                  },
                                                ),
                                                Text(comment.reposts.toString())
                                              ],
                                            ),
                                          ),
                                          // SHARES
                                          Padding(
                                            padding: const EdgeInsets.all(0),
                                            child: Row(
                                              children: [
                                                IconButton(
                                                  icon: const Icon(
                                                      Ionicons
                                                          .paper_plane_outline,
                                                      color: Color.fromRGBO(
                                                          22, 110, 216, 1)),
                                                  onPressed: () {
                                                    setState(() {
                                                      "Liked!";
                                                      Icons.thumb_up;
                                                      _middleIconColor =
                                                          Colors.blue;
                                                    });
                                                  },
                                                ),
                                                Text(comment.shares.toString())
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
