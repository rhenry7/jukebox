import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' as flutter;
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_test_project/GIFs/gifs.dart';
import 'package:flutter_test_project/ui/screens/feed/comment_body.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/models/user_comments.dart';
import 'package:flutter_test_project/Api/apis.dart' as myApi;
import 'package:flutter_test_project/Api/apis.dart';
import 'package:flutter_test_project/ui/screens/feed/subComments.dart';
import 'package:flutter_test_project/utils/reviews/review_helpers.dart';
import 'package:gap/gap.dart';
import 'package:ionicons/ionicons.dart';
import 'package:spotify/spotify.dart';
import '../../../utils/helpers.dart';

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
              child: SingleChildScrollView(
                  child: Column(
                children: [
                  FutureBuilder<CommentWithMusicInfo>(
                    future: comments,
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
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
                        return Text('Error: ${snapshot.error}');
                      }
                      return const DiscoBallLoading();
                    },
                  )
                ],
              )),
            ),
          ],
        ),
      ),
    ));
  }
}
