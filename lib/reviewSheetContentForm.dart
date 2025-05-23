import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_test_project/ProfileSignUpWidget.dart';
import 'package:flutter_test_project/helpers.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart'; // Import the intl package
import 'package:ionicons/ionicons.dart';

class MyReviewSheetContentForm extends StatefulWidget {
  final String title;
  final String Artist;
  final String albumImageUrl;
  const MyReviewSheetContentForm(
      {super.key,
      required this.title,
      required this.Artist,
      required this.albumImageUrl});

  @override
  State<MyReviewSheetContentForm> createState() => _MyReviewSheetContentForm();
}

/// one idea is to inherit the props from the previous widget, if that widget is a track or album widget.
/// The content of that item will be used to generate the title and the props will be used to autofill some of the form.
class _MyReviewSheetContentForm extends State<MyReviewSheetContentForm> {
  final FirebaseAuth auth = FirebaseAuth.instance;
  late String currentDate;
  late bool liked = false;
  late double ratingScore = 0;
  Color background = Colors.white10;
  final TextEditingController reviewController = TextEditingController();

  @override
  void initState() {
    super.initState();
    DateTime now = DateTime.now();
    currentDate = DateFormat.yMMMMd('en_US').format(now);
  }

  Future<void> showSubmissionAuthErrorModal(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900], // Darker background for the dialog
          title: const Text(
            'User not logged in',
            style: TextStyle(color: Colors.white), // White text for contrast
          ),
          content: const Text(
            'You must be logged in to leave a review',
            style: TextStyle(
                color: Colors.white70), // Slightly lighter text for readability
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.redAccent), // Red for contrast
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (BuildContext context) =>
                            const ProfileSignUp()));
              },
              child: const Text(
                'Log in',
                style: TextStyle(
                    color: Colors.greenAccent), // Green for confirmation
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
    // Clean up controllers
    reviewController.dispose();
  }

  void toggleHeart() {
    setState(() {
      liked = !liked;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: background),
      height: 750,
      width: double.infinity, // or a fixed width
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: BackButton(
                    style: ButtonStyle(
                        elevation: WidgetStateProperty.all<double>(1.0)),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  )),

              Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(auth.currentUser?.displayName ?? "username"),
                  ),
                  Icon(Ionicons.person_circle_outline),
                ],
              )
              //child: const Icon(Ionicons.close))),
            ],
          ),
          Gap(10),
          // ALBUM IMAGE AND INFO
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: ListTile(
                  leading: widget.albumImageUrl != null
                      ? Image.network(widget.albumImageUrl ?? "")
                      : const Icon(Icons
                          .music_note), // Fallback if no image is available,
                  title:
                      Text(widget.title, style: TextStyle(color: Colors.white)),
                  subtitle: Text(widget.Artist),
                ),
              ),
            ],
          ),
          Gap(10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: 2.0,
                  ),
                  child: RatingBar(
                    minRating: 0,
                    maxRating: 5,
                    allowHalfRating: true,
                    itemSize: 24,
                    itemPadding: const EdgeInsets.symmetric(horizontal: 5.0),
                    ratingWidget: RatingWidget(
                      full: const Icon(Icons.star, color: Colors.amber),
                      empty: const Icon(Icons.star, color: Colors.grey),
                      half: const Icon(Icons.star_half, color: Colors.amber),
                    ),
                    // TODO convert to state or send to DB or something..
                    onRatingUpdate: (rating) {
                      print(rating);
                      setState(() {
                        ratingScore = rating;
                      });
                    },
                  ),
                ),
                Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors
                            .transparent, // Removes shadow to keep it fully transparent
                        elevation:
                            0, // Removes the elevation to avoid any shadow effect
                      ),
                      onPressed: toggleHeart,
                      child: Icon(
                        Ionicons.heart,
                        color: liked == true ? Colors.red : Colors.grey,
                      ),
                    ))
              ],
            ),
          ),
          SizedBox(
            width: 500, // Fixed width
            height: 300, // Fixed height
            child: TextField(
              controller: reviewController,
              maxLines: null, // Allows the text to wrap and expand vertically
              decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'What did you think ?',
                  hintStyle: TextStyle(color: Colors.grey)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    if (auth.currentUser != null) {
                      String userId = auth.currentUser!.uid;
                      String review = reviewController.text;
                      try {
                        await submitReview(review, ratingScore, widget.Artist,
                            widget.title, liked, widget.albumImageUrl);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Review Posted!'),
                            action: SnackBarAction(
                              label: 'Ok.',
                              onPressed: () {
                                // Do something when the action is pressed
                                print('Undo pressed');
                              },
                            ),
                          ),
                        );
                        Navigator.pop(context);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content:
                              Text('Could not submit review ${e.toString()}'),
                          action: SnackBarAction(
                            label: 'Undo',
                            onPressed: () {
                              // Do something when the action is pressed
                              print('Undo pressed');
                            },
                          ),
                        ));
                      }

                      print("logged in user made a post");
                    } else {
                      showSubmissionAuthErrorModal(context);
                    }
                    // Action when the button is pressed
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0), // Round radius
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    backgroundColor: Colors.green, // Button color
                  ),
                  child: const Text(
                    'Save Review',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const Gap(10),
        ],
      ),
    );
  }
}
