import 'package:flutter/material.dart';
import 'package:flutter_test_project/GIFs/gifs.dart';
import 'package:flutter_test_project/ui/screens/feed/comment_body.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/Api/apis.dart' as myApi;
import 'package:flutter_test_project/Api/apis.dart';
import 'package:gap/gap.dart';
import 'package:spotify/spotify.dart';

class CommentWidget extends StatefulWidget {
  const CommentWidget({super.key});
  @override
  CommentWidgetState createState() => CommentWidgetState();
}

class CommentWithMusicInfo {
  final List<Review> reviews;
  final List<Album> albums;

  CommentWithMusicInfo({
    required this.reviews,
    required this.albums,
  });
}

Future<CommentWithMusicInfo> fetchCombinedData() async {
  final results = await Future.wait([
    //fetchUserReviews(),
    myApi.fetchMockUserComments(),
    fetchPopularAlbums(),
  ]);

  return CommentWithMusicInfo(
    reviews: results[0] as List<Review>,
    albums: results[1] as List<Album>,
  );
}

class CommentWidgetState extends State<CommentWidget> {
  Color _middleIconColor = Colors.white;
  late Future<CommentWithMusicInfo> comments;

  @override
  void initState() {
    super.initState();
    comments = fetchCombinedData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Center(
      child: Container(
        padding: const EdgeInsets.only(left: 2, bottom: 10),
        child: Column(
          children: [
            Container(
              alignment: Alignment.bottomLeft,
              padding: const EdgeInsets.only(left: 10),
              child: const Column(
                children: [
                  Gap(10),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  setState(() {
                    comments = fetchCombinedData();
                  });
                  await comments;
                },
                color: Colors.red[600],
                child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                  children: [
                    FutureBuilder<CommentWithMusicInfo>(
                      future: comments,
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          if (snapshot.data!.albums.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.comment_outlined, 
                                        size: 64, color: Colors.grey),
                                    SizedBox(height: 16),
                                    Text(
                                      'No community posts yet',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 20),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Be the first to share your thoughts!',
                                      style: TextStyle(color: Colors.white70),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          return ListView.builder(
                              itemCount: snapshot.data!.albums.length,
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              itemBuilder: (context, index) {
                                return CommentsBody(
                                  commentWithMusicInfo: snapshot.data!,
                                  index: index,
                                  onStateChanged: () {
                                    setState(() {
                                      _middleIconColor = Colors.white;
                                    });
                                  },
                                );
                              });
                        } else if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error_outline, 
                                      size: 64, color: Colors.red),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Error loading comments',
                                    style: TextStyle(color: Colors.white, fontSize: 18),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${snapshot.error}',
                                    style: const TextStyle(color: Colors.white70),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        comments = fetchCombinedData();
                                      });
                                    },
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return const Padding(
                          padding: EdgeInsets.all(32.0),
                          child: DiscoBallLoading(),
                        );
                      },
                    )
                  ],
                )),
              ),
            ),
          ],
        ),
      ),
    ));
  }
}
