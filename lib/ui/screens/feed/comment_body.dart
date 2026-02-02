import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_test_project/GIFs/gifs.dart';
import 'package:flutter_test_project/ui/screens/feed/comments.dart';
import 'package:flutter_test_project/ui/screens/feed/subComments.dart';
import 'package:flutter_test_project/utils/helpers.dart';
import 'package:ionicons/ionicons.dart';

class CommentsBody extends StatelessWidget {
  final CommentWithMusicInfo commentWithMusicInfo;
  final int index;
  final VoidCallback onStateChanged;

  const CommentsBody({
    super.key,
    required this.commentWithMusicInfo,
    required this.index,
    required this.onStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final review = commentWithMusicInfo.reviews[index];
    final album = commentWithMusicInfo.albums[index];
    final albumImages = album.images;
    final String largeImageUrl =
        albumImages?.isNotEmpty == true ? albumImages!.first.url ?? "" : "";
    final String smallImageUrl =
        albumImages?.isNotEmpty == true ? albumImages!.last.url ?? "" : "";

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => SubComments(
                      title: album.name ?? "",
                      imageUrl: largeImageUrl,
                      userId: review.userId ?? "",
                      displayName: review.displayName,
                      joinDate: '',
                      reviews: '',
                    )),
          );
        },
        child: Card(
            elevation: 1,
            margin: const EdgeInsets.all(0),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              side: BorderSide(color: Color.fromARGB(56, 158, 158, 158)),
            ),
            color: Colors.black,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // NAME AND TIME
                  Padding(
                    padding: const EdgeInsets.only(
                        right: 8.0, left: 10.0, top: 10.0, bottom: 0.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // USER POST INFO ROW
                        Row(
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(right: 5),
                              child: Icon(
                                Ionicons.person_circle_outline,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              (review.displayName.length <= 12
                                  ? review.displayName
                                  : '${review.displayName.substring(0, 12)}…'),
                              style: const TextStyle(
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.normal,
                                  color: Colors.white),
                            ),
                            // TIME STAMP
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2.0),
                              child: Text(
                                formatDateTimeDifference(
                                    review.date?.toIso8601String() ?? ''),
                                style: const TextStyle(
                                  fontSize: 12.0,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // RATING BAR
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: RatingBar(
                              minRating: 3,
                              maxRating: 3,
                              allowHalfRating: false,
                              ignoreGestures: true,
                              itemSize: 18,
                              itemPadding:
                                  const EdgeInsets.symmetric(horizontal: 2.0),
                              ratingWidget: RatingWidget(
                                full: const Icon(Icons.star,
                                    color: Colors.yellow),
                                empty: const Icon(Icons.star,
                                    color: Colors.yellow),
                                half: const Icon(Icons.star_half,
                                    color: Colors.white),
                              ),
                              onRatingUpdate: (rating) {
                                // Handle rating update
                              }),
                        ),
                      ],
                    ),
                  ),

                  // COMMENT AND IMAGE - only show if review text exists
                  if ((review.review ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 12.0, top: 14.0, right: 10.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: <Widget>[
                          // IMAGE
                          Padding(
                            padding: const EdgeInsets.only(right: 10.0),
                            child: Image.network(
                              smallImageUrl,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.error);
                              },
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) {
                                  return child;
                                } else {
                                  return const Center(
                                      child: DiscoBallLoading());
                                }
                              },
                            ),
                          ),
                          Flexible(
                            child: Text(
                              review.review ?? '',
                              maxLines: 5,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.0,
                                fontStyle: FontStyle.italic,
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
                    padding: const EdgeInsets.all(5),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        // LIKES
                        _buildActionButton(
                          icon: Ionicons.heart_outline,
                          count: review.likes.toString() ?? '0',
                          onPressed: onStateChanged,
                        ),
                        // REPLIES
                        _buildActionButton(
                          icon: Ionicons.chatbubble_outline,
                          count: review.replies.toString() ?? '0',
                          onPressed: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (BuildContext context) =>
                                        SubComments(
                                          title: review.title ?? "",
                                          imageUrl: largeImageUrl,
                                          userId: review.userId ?? "",
                                          displayName: review.displayName,
                                          joinDate: '',
                                          reviews: '',
                                        )));
                          },
                        ),
                        // REPOSTS
                        _buildActionButton(
                          icon: Ionicons.repeat,
                          count: review.reposts.toString() ?? '0',
                          onPressed: onStateChanged,
                        ),
                        // SHARES
                        _buildActionButton(
                          icon: Ionicons.paper_plane_outline,
                          count: review.likes.toString() ?? '0',
                          onPressed: onStateChanged,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String count,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.all(0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(icon, color: Colors.white),
            onPressed: onPressed,
          ),
          Text(
            count,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
