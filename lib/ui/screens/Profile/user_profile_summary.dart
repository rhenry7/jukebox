import 'package:flutter/material.dart';
import 'package:flutter_test_project/GIFs/gifs.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/models/user_models.dart';
import 'package:flutter_test_project/services/user_services.dart';
import 'package:flutter_test_project/ui/screens/Profile/profile_analytics_dashboard.dart';
import 'package:ionicons/ionicons.dart';

class UserProfileSummary extends StatefulWidget {
  const UserProfileSummary({
    super.key,
    this.color = const Color(0xFF2DBD3A),
    this.child,
  });

  final Color color;
  final Widget? child;

  @override
  State<UserProfileSummary> createState() => _UserProfileSummaryState();
}

class _UserProfileSummaryState extends State<UserProfileSummary> {
  late final Future<UserReviewInfo> userReviewInfo;

  @override
  void initState() {
    userReviewInfo = UserServices().fetchCurrentUserInfo();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
          child: FutureBuilder<UserReviewInfo>(
              future: userReviewInfo,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
                if (!snapshot.hasData || snapshot.data == null) {
                  return const DiscoBallLoading();
                } else if (snapshot.hasData) {
                  final UserReviewInfo? userInfo = snapshot.data;
                  final reviews =
                      userInfo?.reviews ?? []; // Provide empty list fallback
                  print(snapshot.data?.reviews);
                  if (userInfo == null) {
                    return const Center(child: Text('no data from user info'));
                  }
                  return Column(
                    children: [
                      // BACK BUTTON
                      const Padding(
                        padding: EdgeInsets.only(
                          top: 60.0,
                          left: 16.0,
                          right: 16.0,
                        ),
                        child: Row(
                          children: [
                            BackButton(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // CARD CONTENT
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: ProfileCardHeader(
                          userInfo: userInfo,
                          reviews: reviews,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ProfileStatsContainer(
                          userInfo: userInfo,
                          reviews: reviews,
                        ),
                      ),
                    ],
                  );
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else {
                  return const Center(child: DiscoBallLoading());
                }
              })),
    );
  }
}

class ProfileCardHeader extends StatelessWidget {
  const ProfileCardHeader({
    super.key,
    required this.userInfo,
    required this.reviews,
  });

  final UserReviewInfo? userInfo;
  final List<Review> reviews;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[900],
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Ionicons.person_circle_outline,
                color: Colors.white,
                size: 50.0,
              ),
            ),
            const SizedBox(width: 16),
            // User Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    userInfo?.displayName ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You already have ${reviews.length.toString()} reviews!',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (userInfo?.joinDate != null)
                    Text(
                      'juxeboxxn since ${userInfo!.joinDate!.year.toString()}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileStatsContainer extends StatelessWidget {
  const ProfileStatsContainer({
    super.key,
    required this.userInfo,
    required this.reviews,
  });

  final UserReviewInfo? userInfo;
  final List<Review> reviews;

  @override
  Widget build(BuildContext context) {
    return const Expanded(
      child: ProfileAnalyticsDashboard(),
    );
  }
}
