import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_test_project/models/enhanced_user_preferences.dart';
import 'package:flutter_test_project/ui/screens/Profile/ProfileSignUpWidget.dart';
import 'package:flutter_test_project/utils/helpers.dart';
import 'package:flutter_test_project/utils/reviews/review_helpers.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';

class MyReviewSheetContentForm extends StatefulWidget {
  final String title;
  final String artist; // Fixed capitalization
  final String albumImageUrl;

  const MyReviewSheetContentForm({
    super.key,
    required this.title,
    required this.artist, // Fixed capitalization
    required this.albumImageUrl,
  });

  @override
  State<MyReviewSheetContentForm> createState() =>
      _MyReviewSheetContentFormState();
}

class _MyReviewSheetContentFormState extends State<MyReviewSheetContentForm> {
  final FirebaseAuth auth = FirebaseAuth.instance;
  late String currentDate;
  bool liked = false;
  double ratingScore = 0;
  final Color background = Colors.white10;
  final TextEditingController reviewController = TextEditingController();

  @override
  void initState() {
    super.initState();
    DateTime now = DateTime.now();
    currentDate = DateFormat.yMMMMd('en_US').format(now);
  }

  @override
  void dispose() {
    reviewController.dispose();
    super.dispose();
  }

  Future<void> showSubmissionAuthErrorModal(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'User not logged in',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'You must be logged in to leave a review',
            style: TextStyle(color: Colors.white70),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog first
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (BuildContext context) => const ProfileSignUp(),
                  ),
                );
              },
              child: const Text(
                'Log in',
                style: TextStyle(color: Colors.greenAccent),
              ),
            ),
          ],
        );
      },
    );
  }

  void toggleHeart() {
    setState(() {
      liked = !liked;
    });
  }

  Future<void> handleSubmit() async {
    if (auth.currentUser == null) {
      showSubmissionAuthErrorModal(context);
      return;
    }

    String review = reviewController.text.trim();

    // Basic validation
    if (review.isEmpty && ratingScore == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a rating or write a review'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await submitReview(
        review,
        ratingScore,
        widget.artist,
        widget.title,
        liked,
        widget.albumImageUrl,
      );

      final String userId = FirebaseAuth.instance.currentUser != null
          ? FirebaseAuth.instance.currentUser!.uid
          : "";
      EnhancedUserPreferences? preferences = null;

      Future<EnhancedUserPreferences?> _fetchPreferences() async {
        if (userId.isEmpty) {
          print("User not logged in, cannot fetch preferences.");
          return EnhancedUserPreferences(
              favoriteGenres: [], favoriteArtists: []);
        }

        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('musicPreferences')
            .doc('profile')
            .get();

        if (doc.exists) {
          preferences = EnhancedUserPreferences.fromJson(doc.data()!);
          return preferences;
        } else {
          return EnhancedUserPreferences(
              favoriteGenres: [], favoriteArtists: []);
        }
      }

      Future<void> _uploadPreferences() async {
        if (userId.isEmpty) {
          print("User not logged in, cannot upload preferences.");
          return;
        }

        final data = preferences?.toJson();
        data?['lastUpdated'] = DateTime.now().toIso8601String();

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('musicPreferences')
            .doc('profile')
            .set(data!, SetOptions(merge: true));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review Posted!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not submit review: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: background),
      height: MediaQuery.of(context).size.height * 0.9, // Responsive height
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with back button and user info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              Row(
                children: [
                  Text(
                    auth.currentUser?.displayName ?? "Guest",
                    style: const TextStyle(color: Colors.white),
                  ),
                  const Gap(8),
                  const Icon(
                    Ionicons.person_circle_outline,
                    color: Colors.white,
                  ),
                ],
              ),
            ],
          ),

          const Gap(16),

          // Album info section
          Row(
            children: [
              // Album image
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[800],
                ),
                child: widget.albumImageUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          widget.albumImageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.music_note, color: Colors.white),
                        ),
                      )
                    : const Icon(Icons.music_note, color: Colors.white),
              ),

              const Gap(16),

              // Title and artist
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(4),
                    Text(
                      widget.artist,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Gap(24),

          // Rating and like section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Rating stars
              RatingBar(
                initialRating: ratingScore,
                minRating: 0,
                maxRating: 5,
                allowHalfRating: true,
                itemSize: 32,
                itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                ratingWidget: RatingWidget(
                  full: const Icon(Icons.star, color: Colors.amber),
                  empty: const Icon(Icons.star_border, color: Colors.grey),
                  half: const Icon(Icons.star_half, color: Colors.amber),
                ),
                onRatingUpdate: (rating) {
                  setState(() {
                    ratingScore = rating;
                  });
                },
              ),

              // Like button
              IconButton(
                onPressed: toggleHeart,
                icon: Icon(
                  liked ? Ionicons.heart : Ionicons.heart_outline,
                  color: liked ? Colors.red : Colors.grey,
                  size: 28,
                ),
              ),
            ],
          ),

          const Gap(24),

          // Review text field
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[700]!),
              ),
              child: TextField(
                controller: reviewController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'What did you think?',
                  hintStyle: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ),

          const Gap(24),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Save Review',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const Gap(16),
        ],
      ),
    );
  }
}
