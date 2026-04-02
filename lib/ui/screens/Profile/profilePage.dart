import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/providers/friends_provider.dart';
import 'package:flutter_test_project/providers/reviews_provider.dart';
import 'package:flutter_test_project/providers/music_profile_insights_provider.dart';
import 'package:flutter_test_project/providers/spotify_artist_provider.dart';
import 'package:flutter_test_project/providers/user_playlist_provider.dart';
import 'package:flutter_test_project/ui/screens/Profile/ProfileButton.dart';
import 'package:flutter_test_project/ui/screens/Profile/genre_distribution_chart.dart';
import 'package:flutter_test_project/ui/screens/Profile/profile_analytics_dashboard.dart';
import 'package:flutter_test_project/ui/screens/Profile/review_heatmap.dart';
import 'package:flutter_test_project/ui/screens/Profile/review_stats_cards.dart';
import 'package:flutter_test_project/ui/screens/Profile/top_artists_card.dart';
import 'package:flutter_test_project/ui/screens/Profile/helpers/profileHelpers.dart';
import 'package:flutter_test_project/ui/widgets/review_card.dart' show ReviewCardWithGenres;
import 'package:flutter_test_project/ui/screens/playlists/playlist_detail_screen.dart';
import 'package:flutter_test_project/ui/widgets/skeleton_loader.dart';
import 'package:ionicons/ionicons.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selectedTab = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reviewsAsync = ref.watch(userReviewsProvider);
    final insightsAsync = ref.watch(musicProfileInsightsAutoProvider);
    final topArtistsAsync = ref.watch(spotifyTopArtistsProvider);
    final user = FirebaseAuth.instance.currentUser;
    final reviewCount = ref.watch(reviewCountProvider);
    final crateCount = ref.watch(userPlaylistsProvider).value?.length ?? 0;
    final friendCount = ref.watch(friendIdsProvider).value?.length ?? 0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          // ── Profile header ──────────────────────────────────────
          SliverToBoxAdapter(
            child: _ProfileHeader(
              displayName: user?.displayName ?? 'User',
              reviewCount: reviewCount,
              crateCount: crateCount,
              friendCount: friendCount,
              joinDate: user?.metadata.creationTime,
              onEditProfile: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(body: profileRoute('Preferences')),
                ),
              ),
            ),
          ),

          // ── Sticky tab bar ─────────────────────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(_tabController),
          ),

          // ── Tab content ────────────────────────────────────────
          SliverToBoxAdapter(
            child: _TabContent(
              selectedTab: _selectedTab,
              reviewsAsync: reviewsAsync,
              insightsAsync: insightsAsync,
              topArtistsAsync: topArtistsAsync,
            ),
          ),

          // ── Bottom padding ─────────────────────────────────────
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

// ── Tab bar persistent header ─────────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController tabController;
  _TabBarDelegate(this.tabController);

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.black,
      child: TabBar(
        controller: tabController,
        indicatorColor: const Color.fromARGB(255, 227, 44, 27),
        indicatorWeight: 2.5,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: const Color.fromARGB(255, 220, 40, 23),
        unselectedLabelColor: Colors.white38,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.4,
        ),
        tabs: const [
          Tab(text: 'CRATES'),
          Tab(text: 'ACTIVITY'),
          Tab(text: 'REVIEWS'),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}

// ── Tab content switcher ──────────────────────────────────────────────────────

class _TabContent extends ConsumerWidget {
  final int selectedTab;
  final AsyncValue<List<ReviewWithDocId>> reviewsAsync;
  final AsyncValue<dynamic> insightsAsync;
  final AsyncValue<dynamic> topArtistsAsync;

  const _TabContent({
    required this.selectedTab,
    required this.reviewsAsync,
    required this.insightsAsync,
    required this.topArtistsAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: KeyedSubtree(
        key: ValueKey(selectedTab),
        child: switch (selectedTab) {
          0 => _CratesContent(ref: ref),
          1 => _ActivityContent(
              reviewsAsync: reviewsAsync,
              insightsAsync: insightsAsync,
              topArtistsAsync: topArtistsAsync,
            ),
          2 => _ReviewsListContent(reviewsAsync: reviewsAsync),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }
}

// ── CRATES content ────────────────────────────────────────────────────────────

class _CratesContent extends StatelessWidget {
  final WidgetRef ref;
  const _CratesContent({required this.ref});

  @override
  Widget build(BuildContext context) {
    final playlistsAsync = ref.watch(userPlaylistsProvider);

    return playlistsAsync.when(
      data: (playlists) {
        if (playlists.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 64),
            child: Center(
              child: Column(
                children: [
                  Icon(Ionicons.albums_outline,
                      size: 56, color: Colors.white24),
                  SizedBox(height: 16),
                  Text('No crates yet',
                      style: TextStyle(color: Colors.white, fontSize: 18)),
                  SizedBox(height: 8),
                  Text('Make your first crate and start curating music',
                      style: TextStyle(color: Colors.white54)),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          itemCount: playlists.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final pl = playlists[i];
            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlaylistDetailScreen(playlistId: pl.id),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.08), width: 1),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: pl.coverImageUrl != null
                          ? Image.network(
                              pl.coverImageUrl!,
                              width: 54,
                              height: 54,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _CratePlaceholder(size: 54),
                            )
                          : _CratePlaceholder(size: 54),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pl.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${pl.tracks.length} track${pl.tracks.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12),
                          ),
                          if (pl.tags.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              children: pl.tags.take(3).map((tag) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: Colors.white30, width: 1),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    tag,
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 11),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        color: Colors.white24, size: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Text('Error loading crates',
              style: TextStyle(color: Colors.white54)),
        ),
      ),
    );
  }
}

class _CratePlaceholder extends StatelessWidget {
  final double size;
  const _CratePlaceholder({required this.size});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: Colors.grey[850],
      child: const Icon(Ionicons.musical_notes_outline,
          color: Colors.white24, size: 22),
    );
  }
}

// ── ACTIVITY content (analytics) ─────────────────────────────────────────────

class _ActivityContent extends StatelessWidget {
  final AsyncValue<List<ReviewWithDocId>> reviewsAsync;
  final AsyncValue<dynamic> insightsAsync;
  final AsyncValue<dynamic> topArtistsAsync;

  const _ActivityContent({
    required this.reviewsAsync,
    required this.insightsAsync,
    required this.topArtistsAsync,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: reviewsAsync.when(
        data: (reviewsWithDocIds) {
          final List<Review> reviews =
              reviewsWithDocIds.map((r) => r.review).toList();

          if (reviews.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.bar_chart, size: 56, color: Colors.white24),
                    SizedBox(height: 16),
                    Text('No reviews yet',
                        style: TextStyle(color: Colors.white, fontSize: 18)),
                    SizedBox(height: 8),
                    Text('Start reviewing music to see your stats!',
                        style: TextStyle(color: Colors.white54),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ReviewHeatmap(reviews: reviews),
              const SizedBox(height: 16),
              topArtistsAsync.when(
                data: (artists) => Column(
                  children: [
                    TopArtistsCard(artists: artists),
                    const SizedBox(height: 16),
                    GenreDistributionChart(artists: artists),
                    const SizedBox(height: 16),
                  ],
                ),
                loading: () => Column(
                  children: [
                    SkeletonLoader(
                        width: double.infinity,
                        height: 160,
                        borderRadius: BorderRadius.circular(12)),
                    const SizedBox(height: 16),
                    SkeletonLoader(
                        width: double.infinity,
                        height: 230,
                        borderRadius: BorderRadius.circular(12)),
                    const SizedBox(height: 16),
                  ],
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
              ReviewStatsCards(reviews: reviews),
              const SizedBox(height: 16),
              ReviewScoreChartCard(reviews: reviews),
              const SizedBox(height: 16),
              insightsAsync.when(
                data: (insights) => InsightsSummaryCard(insights: insights),
                loading: () => const SkeletonLoader(
                  width: double.infinity,
                  height: 150,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 8),
            ],
          );
        },
        loading: () => const _LoadingSkeleton(),
        error: (_, __) => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text('Error loading reviews',
                style: TextStyle(color: Colors.white70)),
          ),
        ),
      ),
    );
  }
}

// ── REVIEWS list content (ReviewCardWithGenres) ───────────────────────────────

class _ReviewsListContent extends StatelessWidget {
  final AsyncValue<List<ReviewWithDocId>> reviewsAsync;
  const _ReviewsListContent({required this.reviewsAsync});

  @override
  Widget build(BuildContext context) {
    return reviewsAsync.when(
      data: (reviewsWithDocIds) {
        if (reviewsWithDocIds.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 64),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.bar_chart, size: 56, color: Colors.white24),
                  SizedBox(height: 16),
                  Text('No reviews yet',
                      style: TextStyle(color: Colors.white, fontSize: 18)),
                  SizedBox(height: 8),
                  Text('Start reviewing music to see your reviews here',
                      style: TextStyle(color: Colors.white54),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }

        final sorted = List.of(reviewsWithDocIds)
          ..sort((a, b) {
            final aDate = a.review.date;
            final bDate = b.review.date;
            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return bDate.compareTo(aDate);
          });

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          itemCount: sorted.length,
          itemBuilder: (context, i) {
            final item = sorted[i];
            return Card(
              elevation: 1,
              margin: const EdgeInsets.all(5),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                side: BorderSide(color: Color.fromARGB(56, 158, 158, 158)),
              ),
              color: Colors.white10,
              child: ReviewCardWithGenres(
                review: item.review,
                reviewId: item.fullReviewId,
                showLikeButton: true,
              ),
            );
          },
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Text('Error loading reviews',
              style: TextStyle(color: Colors.white54)),
        ),
      ),
    );
  }
}

// ── Profile header ────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final String displayName;
  final int reviewCount;
  final int crateCount;
  final int friendCount;
  final DateTime? joinDate;
  final VoidCallback onEditProfile;

  const _ProfileHeader({
    required this.displayName,
    required this.reviewCount,
    required this.crateCount,
    required this.friendCount,
    required this.onEditProfile,
    this.joinDate,
  });

  @override
  Widget build(BuildContext context) {
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final handle = '@${displayName.toLowerCase().replaceAll(' ', '_')}';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 24,
        bottom: 20,
        left: 24,
        right: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Avatar with glow ──────────────────────────────────
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.55),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
              border: Border.all(color: Colors.white24, width: 2),
            ),
            child: CircleAvatar(
              radius: 48,
              backgroundColor: Colors.grey[850],
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Display name ──────────────────────────────────────
          Text(
            displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),

          // ── @handle ───────────────────────────────────────────
          Text(
            handle,
            style: TextStyle(
              color: Colors.red[300],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),

          // ── Join date ─────────────────────────────────────────
          if (joinDate != null) ...[
            const SizedBox(height: 6),
            Text(
              'Member since ${_formatJoinDate(joinDate!)}',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
          const SizedBox(height: 22),

          // ── Action buttons ────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: onEditProfile,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 11),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 138, 138, 138),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Edit Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Share profile — coming soon'),
                      duration: Duration(seconds: 2)),
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white30, width: 1.2),
                  ),
                  child: const Text(
                    'Share',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Stats row ─────────────────────────────────────────
          Row(
            children: [
              Expanded(child: _StatBox(value: '$crateCount', label: 'CRATES')),
              const SizedBox(width: 10),
              Expanded(
                  child: _StatBox(value: '$friendCount', label: 'FRIENDS')),
              const SizedBox(width: 10),
              Expanded(
                  child: _StatBox(value: '$reviewCount', label: 'REVIEWS')),
            ],
          ),
        ],
      ),
    );
  }

  String _formatJoinDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  const _StatBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.3,
            ),
          ),
        ],
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
        SkeletonLoader(
          width: double.infinity,
          height: 180,
          borderRadius: BorderRadius.circular(12),
        ),
        const SizedBox(height: 16),
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
