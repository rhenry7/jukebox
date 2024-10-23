import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:gap/gap.dart';
import 'package:ionicons/ionicons.dart';

class MyReviewSheetContentForm extends StatefulWidget {
  const MyReviewSheetContentForm({super.key, required this.title});
  final String title;

  @override
  State<MyReviewSheetContentForm> createState() => _MyReviewSheetContentForm();
}

/// one idea is to inherit the props from the previous widget, if that widget is a track or album widget.
/// The content of that item will be used to generate the title and the props will be used to autofill some of the form.
class _MyReviewSheetContentForm extends State<MyReviewSheetContentForm> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 700,
        width: double.infinity, // or a fixed width
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: EdgeInsets.all(2.0),
                  child: Text("Date/Date/Date"),
                ),
                // TODO: Fix, use actual date
                Padding(
                  padding: EdgeInsets.all(2.0),
                  child: Text("Date/Date/Date"),
                )
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: BackButton(
                          style: ButtonStyle(
                              elevation:
                                  MaterialStateProperty.all<double>(1.0)),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        )),
                    //child: const Icon(Ionicons.close))),
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        'Title Of Review',
                        style: TextStyle(
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Ionicons.person_circle_outline,
                        color: Colors.blueGrey)),
              ],
            ),
            const SizedBox(height: 12.0),
            const Expanded(
              child: TextField(
                maxLines: null, // Allows the text to wrap and expand vertically

                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'What to review?',
                ),
              ),
            ),
            const Gap(5),
            Padding(
              padding: const EdgeInsets.all(8.0),
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
                        setState(() {});
                      },
                    ),
                  ),
                  const Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        Ionicons.heart,
                        color: Colors.grey,
                      ))
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  //Expanded
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      // Action when the button is pressed
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(30.0), // Round radius
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      backgroundColor: Colors.green, // Button color
                    ),
                    child: const Text(
                      'Rounded Button',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const Gap(10),
          ],
        ),
      ),
    );
  }
}
