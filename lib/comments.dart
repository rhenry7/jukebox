import 'package:flutter/material.dart';
import 'package:flutter_test_project/apis.dart';
import 'package:flutter_test_project/userComments.dart';
import 'package:gap/gap.dart';

class CommentWidget extends StatefulWidget {
  const CommentWidget({super.key});
  @override
  CommentWidgetState createState() => CommentWidgetState();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Container(
      padding: EdgeInsets.only(left: 2, top: 10),
      child: Column(
        children: [
          Container(
            alignment: Alignment.bottomLeft,
            padding: const EdgeInsets.only(left: 10),
            child: const Text("Popular This Week"),
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
                                child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                // Top Text (Title)
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    comment.name,
                                    style: const TextStyle(
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                // Middle Row (Text and Icon)
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 12.0, top: 4.0, right: 10.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
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
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: <Widget>[
                                      IconButton(
                                        icon: const Icon(
                                            Icons.favorite_border_outlined,
                                            color: Color.fromRGBO(
                                                22, 110, 216, 1)),
                                        onPressed: () {
                                          setState(() {
                                            "Liked!";
                                            Icons.thumb_up;
                                            _middleIconColor = Colors.blue;
                                          });
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.message_rounded,
                                            color: Color.fromRGBO(
                                                22, 110, 216, 1)),
                                        onPressed: () {
                                          setState(() {
                                            "Commented!";
                                          });
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.send_rounded,
                                            color: Color.fromRGBO(
                                                22, 110, 216, 1)),
                                        onPressed: () {
                                          setState(() {
                                            "Shared!";
                                          });
                                        },
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
