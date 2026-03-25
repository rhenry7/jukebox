import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/providers/reviews_provider.dart';
import 'package:flutter_test_project/providers/music_profile_insights_provider.dart';
import 'package:flutter_test_project/ui/screens/Profile/ProfileButton.dart';
import 'package:flutter_test_project/ui/screens/Profile/profile_analytics_dashboard.dart';
import 'package:flutter_test_project/ui/screens/Profile/review_heatmap.dart';
import 'package:flutter_test_project/ui/screens/Profile/review_stats_cards.dart';
import 'package:flutter_test_project/ui/widgets/skeleton_loader.dart';
import 'package:ionicons/ionicons.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(userReviewsProvider);
    final insightsAsync = ref.watch(musicProfileInsightsAutoProvider);
    final user = FirebaseAuth.instance.currentUser;
    final reviewCount = ref.watch(reviewCountProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          // Profile header
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                bottom: 8,
              ),
              child: _ProfileHeader(
                displayName: user?.displayName ?? 'User',
                reviewCount: reviewCount,
                joinDate: user?.metadata.creationTime,
              ),
            ),
          ),

          // Main content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: reviewsAsync.when(
                data: (reviewsWithDocIds) {
                  final reviews =
                      reviewsWithDocIds.map((r) => r.review).toList();

                  if (reviews.isEmpty) {
                    return _EmptyState();
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Heatmap
                      ReviewHeatmap(reviews: reviews),
                      const SizedBox(height: 16),

                      // Stats cards
                      ReviewStatsCards(reviews: reviews),
                      const SizedBox(height: 16),

                      // Score trend chart
                      ReviewScoreChartCard(reviews: reviews),
                      const SizedBox(height: 16),

                      // Music insights
                      insightsAsync.when(
                        data: (insights) =>
                            InsightsSummaryCard(insights: insights),
                        loading: () => const SkeletonLoader(
                          width: double.infinity,
                          height: 150,
                          borderRadius:
                              BorderRadius.all(Radius.circular(12)),
                        ),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
                loading: () => const _LoadingSkeleton(),
                error: (_, __) => const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      'Error loading reviews',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Navigation buttons
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Card(
                color: Colors.grey[900],
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color: Colors.white.withOpacity(0.1), width: 1),
                ),
                child: Column(
                  children: [
                    const ProfileButton(
                      name: 'Notifications',
                      icon: Ionicons.notifications_outline,
                    ),
                    Divider(color: Colors.white.withOpacity(0.05), height: 1),
                    const ProfileButton(
                      name: 'Preferences',
                      icon: Ionicons.analytics_outline,
                    ),
                    Divider(color: Colors.white.withOpacity(0.05), height: 1),
                    const ProfileButton(
                      name: 'LogOut',
                      icon: Ionicons.exit_outline,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom padding for nav bar clearance
          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.of(context).padding.bottom + 80,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String displayName;
  final int reviewCount;
  final DateTime? joinDate;

  const _ProfileHeader({
    required this.displayName,
    required this.reviewCount,
    this.joinDate,
  });

  @override
  Widget build(BuildContext context) {
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final joinText = joinDate != null
        ? 'Joined ${_formatJoinDate(joinDate!)}'
        : '';

    return Row(
      children: [
        // Avatar
        CircleAvatar(
          radius: 30,
          backgroundColor: Colors.red[600],
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Name and stats
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$reviewCount review${reviewCount == 1 ? '' : 's'}',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              if (joinText.isNotEmpty)
                Text(
                  joinText,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatJoinDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No reviews yet',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Start reviewing music to see your activity!',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Heatmap skeleton
        SkeletonLoader(
          width: double.infinity,
          height: 180,
          borderRadius: BorderRadius.circular(12),
        ),
        const SizedBox(height: 16),
        // Stats cards skeleton
        Row(
          children: [
            Expanded(
              child: SkeletonLoader(
                width: double.infinity,
                height: 100,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SkeletonLoader(
                width: double.infinity,
                height: 100,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Chart skeleton
        SkeletonLoader(
          width: double.infinity,
          height: 250,
          borderRadius: BorderRadius.circular(12),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
