import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_test_project/GIFs/gifs.dart';
import 'package:flutter_test_project/Profile/auth/following/follow.dart';
import 'package:flutter_test_project/Types/userComments.dart';
import 'package:flutter_test_project/apis.dart';
import 'package:gap/gap.dart';
import 'package:ionicons/ionicons.dart';
import 'package:popover/popover.dart';

class SubComments extends StatefulWidget {
  final String title;
  final String imageUrl;
  final String userId;
  // final String ratingValue;
  const SubComments(
      {super.key,
      required this.title,
      required this.imageUrl,
      required this.userId});

  @override
  State<SubComments> createState() => SubCommentLists();
}

class SubCommentLists extends State<SubComments> {
  late Future<List<UserComment>> comments;
  late Future<List<User>> userReviewInfo;
  double? _rating;

  @override
  void initState() {
    super.initState();
    comments = fetchMockUserComments();
    userReviewInfo = fetchUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          const Gap(50),
          const Padding(
            padding: EdgeInsets.only(left: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                BackButton(color: Colors.white),
              ],
            ),
          ),
          Padding(
              padding: const EdgeInsets.only(left: 4.0),
              // ADD ALBUM ART, ARTIST, AND PARENT COMMENT INFO
              child: Card(
                elevation: 1,
                margin: const EdgeInsets.all(0),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  side: BorderSide(color: Color.fromARGB(56, 158, 158, 158)),
                ),

                //margin: const EdgeInsets.all(0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(0.0),
                      child: Row(
                        children: [
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                FutureBuilder<List<User>>(
                                  future: userReviewInfo,
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      final userReviewInfo = snapshot.data!;
                                      return UserDialog(
                                        userName: userReviewInfo[0].displayName,
                                        reviewCount: 1,
                                        accountCreationDate:
                                            "1st November 2025", // Replace with actual date
                                      );
                                    } else if (snapshot.hasError) {
                                      return const Icon(
                                          Ionicons.person_circle_outline);
                                    }
                                    return const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    );
                                  },
                                ),
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
                          return Padding(
                            padding: const EdgeInsets.all(0.0),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,

                              itemCount: snapshot.data!.length,
                              physics:
                                  const NeverScrollableScrollPhysics(), // Disable
                              shrinkWrap: true,
                              itemBuilder: (context, index) {
                                final comment = snapshot.data![index];
                                //print(track);
                                return Card(
                                  elevation: 0,
                                  margin: const EdgeInsets.all(5),
                                  shape: const RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(8)),
                                    side: BorderSide(
                                        color:
                                            Color.fromARGB(56, 158, 158, 158)),
                                  ),

                                  //margin: const EdgeInsets.all(0),
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(0.0),
                                        child: Row(
                                          children: <Widget>[
                                            Expanded(
                                              child: ListTile(
                                                leading: const Icon(Ionicons
                                                    .person_circle_outline), // Fallback if no image is available,
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
                                                                  Icons
                                                                      .thumb_up;
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
                            ),
                          );
                        } else if (snapshot.hasError) {
                          print(snapshot);
                          return Text('Error: ${snapshot.error}');
                        }
                        return const DiscoBallLoading();
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

Widget _buildInfoRow({
  required IconData icon,
  required String label,
  required String value,
}) {
  return Row(
    children: [
      Icon(
        icon,
        size: 20,
        color: Colors.grey[600],
      ),
      const SizedBox(width: 12),
      Text(
        '$label: ',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.grey[700],
        ),
      ),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.end,
        ),
      ),
    ],
  );
}

class UserDialog extends StatelessWidget {
  final String userName;
  final int reviewCount;
  final String accountCreationDate;
  final VoidCallback? onClose;
  String currentUid = firebase_auth.FirebaseAuth.instance.currentUser!.uid;

  UserDialog({
    Key? key,
    required this.userName,
    required this.reviewCount,
    required this.accountCreationDate,
    this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(color: Colors.white, width: 2),
                  color: Colors.black,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Profile Icon
                    const Icon(
                      Ionicons.person_circle,
                      size: 60,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    // Title
                    Text(
                      userName,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    // User Name
                    _buildInfoRow(
                      icon: Ionicons.person,
                      label: 'Name',
                      value: 'John Doe', // Replace with actual user name
                    ),
                    const SizedBox(height: 12),
                    // Number of Reviews
                    _buildInfoRow(
                      icon: Ionicons.star,
                      label: 'Reviews',
                      value: '24', // Replace with actual review count
                    ),
                    const SizedBox(height: 12),
                    // Account Creation Date
                    _buildInfoRow(
                      icon: Ionicons.calendar,
                      label: 'Member Since',
                      value:
                          'January 2023', // Replace with actual creation date
                    ),
                    const SizedBox(height: 24),
                    // Close Button
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        //Navigator.of(context).pop();
                        print('Following user: $userName as $currentUid');
                        followUser(currentUid, userName).then((_) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Followed successfully!'),
                            ),
                          );
                        }).catchError((error) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error following user: $error'),
                            ),
                          );
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Follow'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      child: const Padding(
        padding: EdgeInsets.only(left: 3.0, right: 5.0),
        child: Icon(Ionicons.person_circle_outline),
      ),
    );
  }
}
