import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ionicons/ionicons.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/providers/activity_provider.dart';
import 'package:flutter_test_project/providers/auth_provider.dart';
import 'package:flutter_test_project/providers/bookmarks_provider.dart';
import 'package:flutter_test_project/providers/friends_provider.dart';
import 'package:flutter_test_project/providers/reviews_provider.dart';
import 'package:flutter_test_project/providers/spotify_artist_provider.dart';
import 'package:flutter_test_project/providers/user_profile_provider.dart';
import 'package:flutter_test_project/routing/MainNavigation.dart';
import 'package:flutter_test_project/services/activity_service.dart';
import 'package:flutter_test_project/services/spotify_open/spotify_open.dart';
import 'package:flutter_test_project/ui/screens/review_detail/review_detail_page.dart';
import 'package:flutter_test_project/ui/theme/tokens.dart';
import 'package:flutter_test_project/ui/widgets/app_states.dart';
import 'package:flutter_test_project/ui/widgets/friend_toggle.dart';
import 'package:flutter_test_project/ui/widgets/genre_pills.dart';
import 'package:flutter_test_project/ui/widgets/review_options.dart';
import 'package:flutter_test_project/ui/widgets/review_card.dart'
    show ReviewCardWithGenres;
import 'package:flutter_test_project/utils/cached_image.dart';
import 'package:flutter_test_project/ui/widgets/skeleton_loader.dart';
import 'package:flutter_test_project/utils/helpers.dart';

/// A user's profile: header, then their reviews.
///
/// With no [userId] (or the signed-in user's own) it is the Profile tab:
/// Edit Profile, and tabs for reviews, bookmarks and activity. Another
/// user's profile is pushed as its own page, with an Add Friend button and
/// only their reviews — bookmarks and activity are private.
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key, this.userId, this.displayName});

  /// Whose profile; null for the signed-in user.
  final String? userId;

  /// Name to show for [userId] until their profile loads.
  final String? displayName;

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage>
    with SingleTickerProviderStateMixin {
  static const int _reviewsTab = 0;
  static const int _bookmarksTab = 1;

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging) setState(() {});
      });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final otherId = widget.userId;
    final isOwn =
        otherId == null || otherId == ref.watch(currentUserIdProvider);

    final reviews = isOwn
        ? ref.watch(userReviewsProvider)
        : ref.watch(reviewsByUserProvider(otherId));
    final ownReviews = [
      for (final r in reviews.valueOrNull ?? const <ReviewWithDocId>[])
        if (!r.review.isRepost) r,
    ];
    final topCategories =
        rankTags([for (final r in ownReviews) r.review.genres]);
    final topArtists = isOwn
        ? ref.watch(spotifyTopArtistsProvider)
        : ref.watch(topArtistsForUserProvider(otherId));

    final String displayName;
    final DateTime? joinDate;
    if (isOwn) {
      final user = FirebaseAuth.instance.currentUser;
      displayName = user?.displayName ?? 'User';
      joinDate = user?.metadata.creationTime;
    } else {
      final info = ref.watch(userProfileInfoProvider(otherId)).valueOrNull;
      displayName = info?.displayName ?? widget.displayName ?? 'User';
      joinDate = info?.joinDate;
    }

    final reviewsList = _ReviewsList(
      reviews: reviews,
      isOwn: isOwn,
      onRetry: () => isOwn
          ? ref.invalidate(userReviewsProvider)
          : ref.invalidate(reviewsByUserProvider(otherId)),
    );

    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLowest,
      appBar: isOwn
          ? null
          : AppBar(
              backgroundColor: AppColors.surfaceContainerLowest,
              surfaceTintColor: Colors.transparent,
              foregroundColor: AppColors.onSurface,
              elevation: 0,
            ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _ProfileHeader(
              displayName: displayName,
              reviewCount: ownReviews.length,
              joinDate: joinDate,
              topCategories: topCategories,
              topArtists: topArtists,
              primaryAction: isOwn
                  ? const _EditProfileButton()
                  : _FriendButton(userId: otherId, name: displayName),
              topPadding: isOwn ? AppSpacing.lg : AppSpacing.xs,
            ),
          ),
          if (isOwn) ...[
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(_tabController),
            ),
            switch (_tabController.index) {
              _reviewsTab => reviewsList,
              _bookmarksTab => const _Bookmarks(),
              _ => const _Activity(),
            },
          ] else
            reviewsList,
          const SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.dockClearance),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

/// Profile header: avatar beside the @handle, with the review count and join
/// date under it, then top categories and top artists, then the profile
/// actions. One spacing rhythm throughout: [_gapS] inside a group,
/// [_gapL] between groups.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.displayName,
    required this.reviewCount,
    required this.joinDate,
    required this.topCategories,
    required this.topArtists,
    required this.primaryAction,
    required this.topPadding,
  });

  final String displayName;
  final int reviewCount;
  final DateTime? joinDate;
  final List<String> topCategories;
  final AsyncValue<List<TopArtistData>> topArtists;

  /// The wide button beside Share: Edit Profile, or Add Friend.
  final Widget primaryAction;
  final double topPadding;

  static const double _avatarSize = 56;
  static const double _buttonHeight = 44;
  static const double _gapS = AppSpacing.md;
  static const double _gapL = AppSpacing.xl;
  static const int _categoryCount = 5;

  @override
  Widget build(BuildContext context) {
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final handle = displayName.toLowerCase().replaceAll(' ', '');

    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.pageGutter, topPadding, AppSpacing.pageGutter, _gapL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar, then the handle with the user's stats under it.
          Row(
            children: [
              _Avatar(initial: initial, size: _avatarSize),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@$handle',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        color: AppColors.onSurface,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text.rich(
                      TextSpan(children: [
                        _countSpan(reviewCount),
                        const TextSpan(text: ' reviews'),
                        if (joinDate != null)
                          TextSpan(
                              text:
                                  '  ·  Member since ${_formatJoinDate(joinDate!)}'),
                      ]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.onSurfaceVariant, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (topCategories.isNotEmpty) ...[
            const SizedBox(height: _gapL),
            const _SectionLabel('Top categories'),
            GenrePills(
              tags: topCategories,
              maxTags: _categoryCount,
              topPadding: _gapS - AppSpacing.xs,
            ),
          ],

          if (_hasArtists) ...[
            const SizedBox(height: _gapL),
            const _SectionLabel('Top artists'),
            const SizedBox(height: _gapS),
            _TopArtistsRow(artists: topArtists),
          ],

          const SizedBox(height: _gapL),
          Row(
            children: [
              Expanded(
                child: SizedBox(height: _buttonHeight, child: primaryAction),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox.square(
                dimension: _buttonHeight,
                child: OutlinedButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Share profile — coming soon'),
                      duration: Duration(seconds: 2),
                    ),
                  ),
                  style: _outlinedStyle.copyWith(
                      padding: const WidgetStatePropertyAll(EdgeInsets.zero)),
                  child: const Icon(Ionicons.shareOutline, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Show the artists row while loading, or once there are any.
  bool get _hasArtists =>
      topArtists.isLoading || (topArtists.valueOrNull?.isNotEmpty ?? false);

  static String _formatJoinDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  static TextSpan _countSpan(int value) => TextSpan(
        text: '$value',
        style: const TextStyle(
            color: AppColors.onSurface, fontWeight: FontWeight.w700),
      );

  static final ButtonStyle _outlinedStyle = OutlinedButton.styleFrom(
    backgroundColor: AppColors.surfaceContainerHigh,
    foregroundColor: AppColors.onSurface,
    side: const BorderSide(color: AppColors.ghostBorder),
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
  );
}

class _EditProfileButton extends StatelessWidget {
  const _EditProfileButton();

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      // No destination yet.
      onPressed: () {},
      style: _ProfileHeader._outlinedStyle,
      child: const Text(
        'Edit Profile',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Add Friend on someone else's profile; once added, it reads "Friends" and
/// tapping it removes them.
class _FriendButton extends ConsumerStatefulWidget {
  const _FriendButton({required this.userId, required this.name});

  final String userId;
  final String name;

  @override
  ConsumerState<_FriendButton> createState() => _FriendButtonState();
}

class _FriendButtonState extends ConsumerState<_FriendButton> {
  bool _busy = false;

  Future<void> _toggle() async {
    setState(() => _busy = true);
    await toggleFriend(context, ref,
        friendId: widget.userId, friendName: widget.name);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final isFriend = ref.watch(isFriendProvider(widget.userId));
    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(isFriend ? Icons.check : Icons.person_add_alt_1, size: 18),
        const SizedBox(width: AppSpacing.sm),
        Text(
          isFriend ? 'Friends' : 'Add Friend',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ],
    );
    final onPressed = _busy ? null : _toggle;
    // Filled until they're a friend, then the same outline as Edit Profile.
    return isFriend
        ? OutlinedButton(
            onPressed: onPressed,
            style: _ProfileHeader._outlinedStyle,
            child: label,
          )
        : FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.onSurface,
              foregroundColor: AppColors.surfaceContainerLowest,
              shape:
                  const RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
            ),
            child: label,
          );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial, required this.size});

  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryLight, AppColors.primaryDim],
        ),
        border: Border.all(color: AppColors.ghostBorder, width: 2),
      ),
      child: Text(
        initial,
        style: GoogleFonts.spaceGrotesk(
          color: AppColors.onPrimary,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Small tracked-out caps label above a header group ("archival" labels).
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppColors.onSurfaceVariant,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
    );
  }
}

/// The user's four most-reviewed artists as square photos (same corners as
/// the album art on review cards), filling the width.
/// Long-press or hover shows the name.
class _TopArtistsRow extends StatelessWidget {
  const _TopArtistsRow({required this.artists});

  final AsyncValue<List<TopArtistData>> artists;

  static const double _gap = AppSpacing.sm;

  /// [topArtistCount] equal squares filling the full width, [_gap] apart.
  @override
  Widget build(BuildContext context) {
    final list = artists.valueOrNull;
    return LayoutBuilder(builder: (context, constraints) {
      final size =
          (constraints.maxWidth - _gap * (topArtistCount - 1)) / topArtistCount;
      return Row(
        children: [
          for (var i = 0; i < topArtistCount; i++) ...[
            if (i > 0) const SizedBox(width: _gap),
            if (list == null)
              SkeletonLoader(
                width: size,
                height: size,
                borderRadius: AppRadius.smAll,
              )
            else if (i < list.length)
              _ArtistPhoto(artist: list[i], size: size)
            else
              SizedBox.square(dimension: size),
          ],
        ],
      );
    });
  }
}

class _ArtistPhoto extends StatelessWidget {
  const _ArtistPhoto({required this.artist, required this.size});

  final TopArtistData artist;
  final double size;

  @override
  Widget build(BuildContext context) {
    final photo = artist.imageUrl.isNotEmpty
        ? AppCachedImage(
            imageUrl: artist.imageUrl,
            width: size,
            height: size,
            borderRadius: AppRadius.smAll,
          )
        : Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              borderRadius: AppRadius.smAll,
              color: AppColors.surfaceContainerHigh,
            ),
            child: Text(
              artist.name.isNotEmpty ? artist.name[0].toUpperCase() : '?',
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: size * 0.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
    return Tooltip(
      message: artist.name,
      child: Semantics(
        button: true,
        label: '${artist.name} on Spotify',
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: AppRadius.smAll,
            onTap: () => _openOnSpotify(context),
            child: photo,
          ),
        ),
      ),
    );
  }

  Future<void> _openOnSpotify(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await openOnSpotify(artist.spotifyUrl);
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't open Spotify")),
      );
    }
  }
}

// ── Tab bar ───────────────────────────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.tabController);

  final TabController tabController;

  static const double _height = 52;

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    // Fill exactly [_height]: the header must paint as tall as it reports,
    // and an icon-only TabBar on its own is shorter.
    return SizedBox.expand(
      child: ColoredBox(
        color: AppColors.surfaceContainerLowest,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: TabBar(
            controller: tabController,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: const UnderlineTabIndicator(
              borderSide: BorderSide(color: AppColors.onSurface, width: 2.5),
            ),
            dividerColor: Colors.transparent,
            dividerHeight: 0,
            labelColor: AppColors.onSurface,
            unselectedLabelColor: AppColors.onSurfaceVariant,
            splashFactory: NoSplash.splashFactory,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            tabs: const [
              Tab(
                icon: Tooltip(
                  message: 'Your reviews',
                  child: Icon(Icons.view_agenda_outlined, size: 26),
                ),
              ),
              Tab(
                icon: Tooltip(
                  message: 'Bookmarks',
                  child: Icon(Icons.bookmark_border, size: 26),
                ),
              ),
              Tab(
                icon: Tooltip(
                  message: 'Activity',
                  child: Icon(Icons.access_time, size: 26),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) =>
      oldDelegate.tabController != tabController;
}

// ── Reviews ───────────────────────────────────────────────────────────────────

/// The profile owner's reviews as full cards, newest first. Reposts are left
/// out — they show under Activity.
class _ReviewsList extends StatelessWidget {
  const _ReviewsList({
    required this.reviews,
    required this.isOwn,
    required this.onRetry,
  });

  final AsyncValue<List<ReviewWithDocId>> reviews;
  final bool isOwn;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return reviews.when(
      data: (all) {
        final reviews = all.where((r) => !r.review.isRepost).toList()
          ..sort(_newestFirst);
        if (reviews.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: AppEmptyState(
              icon: Icons.rate_review_outlined,
              title: 'No reviews yet',
              action: isOwn
                  ? AppStateAction(
                      label: 'Add your first review',
                      icon: Icons.add,
                      onPressed: () => context
                          .findAncestorStateOfType<MainNavState>()
                          ?.navigateToTab(MainNavState.addTab),
                    )
                  : null,
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          sliver: SliverList.builder(
            itemCount: reviews.length,
            // Your own cards swipe (or long-press) open edit / delete, as
            // on Home; the reviews stream drops a deleted card by itself.
            itemBuilder: (context, i) => Padding(
              padding: AppSpacing.cardListItem,
              child: OwnReviewOptions(
                review: reviews[i],
                child: ReviewCardWithGenres(
                  review: reviews[i].review,
                  reviewId: reviews[i].fullReviewId,
                  showLikeButton: true,
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const _SliverLoading(),
      error: (error, _) => SliverFillRemaining(
        hasScrollBody: false,
        child: AppErrorState(
          title: 'Error loading reviews',
          error: error,
          onRetry: onRetry,
        ),
      ),
    );
  }

  static int _newestFirst(ReviewWithDocId a, ReviewWithDocId b) {
    final aDate = a.review.date;
    final bDate = b.review.date;
    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    return bDate.compareTo(aDate);
  }
}

// ── Bookmarks ─────────────────────────────────────────────────────────────────

/// Reviews the user saved with the bookmark button, most recently saved first.
class _Bookmarks extends ConsumerWidget {
  const _Bookmarks();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(bookmarkedReviewsProvider).when(
          // Keep showing the list while it refreshes after a bookmark change.
          skipLoadingOnRefresh: true,
          skipLoadingOnReload: true,
          data: (reviews) {
            if (reviews.isEmpty) {
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: AppEmptyState(
                  icon: Icons.bookmark_border,
                  title: 'No bookmarks yet',
                  message: 'Tap the bookmark on any review to save it here.',
                ),
              );
            }
            return SliverPadding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              sliver: SliverList.builder(
                itemCount: reviews.length,
                itemBuilder: (context, i) => Padding(
                  padding: AppSpacing.cardListItem,
                  child: ReviewCardWithGenres(
                    key: ValueKey(reviews[i].fullReviewId),
                    review: reviews[i].review,
                    reviewId: reviews[i].fullReviewId,
                    showLikeButton: true,
                  ),
                ),
              ),
            );
          },
          loading: () => const _SliverLoading(),
          error: (error, _) => SliverFillRemaining(
            hasScrollBody: false,
            child: AppErrorState(
              title: 'Error loading your bookmarks',
              error: error,
              onRetry: () => ref.invalidate(bookmarkedReviewsProvider),
            ),
          ),
        );
  }
}

// ── Activity ──────────────────────────────────────────────────────────────────

enum _ActivityFilter {
  all('All'),
  you('You'),
  onYou('On your reviews');

  const _ActivityFilter(this.label);
  final String label;

  bool matches(ActivityItem item) => switch (this) {
        all => true,
        you => !ActivityType.isOnYou(item.type),
        onYou => ActivityType.isOnYou(item.type),
      };
}

class _Activity extends ConsumerStatefulWidget {
  const _Activity();

  @override
  ConsumerState<_Activity> createState() => _ActivityState();
}

class _ActivityState extends ConsumerState<_Activity> {
  _ActivityFilter _filter = _ActivityFilter.all;

  @override
  Widget build(BuildContext context) {
    return ref.watch(profileActivityProvider).when(
          data: (all) {
            final items = all.where(_filter.matches).toList();
            return SliverMainAxisGroup(
              slivers: [
                SliverToBoxAdapter(child: _filterChips()),
                if (items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: AppEmptyState(
                      icon: Icons.access_time,
                      title: 'Nothing here yet',
                      message: switch (_filter) {
                        _ActivityFilter.onYou =>
                          'Likes, comments and reposts on your reviews will show up here.',
                        _ =>
                          'Reviews you write, like, repost or comment on will show up here.',
                      },
                    ),
                  )
                else
                  SliverList.separated(
                    itemCount: items.length,
                    itemBuilder: (context, i) => _ActivityRow(item: items[i]),
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.ghostBorder,
                      indent: AppSpacing.pageGutter,
                      endIndent: AppSpacing.pageGutter,
                    ),
                  ),
              ],
            );
          },
          loading: () => const _SliverLoading(),
          error: (error, _) => SliverFillRemaining(
            hasScrollBody: false,
            child: AppErrorState(
              title: 'Error loading activity',
              error: error,
              onRetry: () => ref.invalidate(userActivityLogProvider),
            ),
          ),
        );
  }

  Widget _filterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.pageGutter, AppSpacing.md,
          AppSpacing.pageGutter, AppSpacing.xs),
      child: Wrap(
        spacing: AppSpacing.sm,
        children: [
          for (final f in _ActivityFilter.values)
            _FilterChip(
              label: f.label,
              selected: f == _filter,
              onTap: () => setState(() => _filter = f),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.onSurface : AppColors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.pillAll,
        side: BorderSide(color: AppColors.ghostBorder),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md + 2, vertical: AppSpacing.sm - 1),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? AppColors.surfaceContainerLowest
                  : AppColors.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityRow extends ConsumerWidget {
  const _ActivityRow({required this.item});

  final ActivityItem item;

  static const double _thumbSize = 52;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const strong = TextStyle(fontWeight: FontWeight.w700);
    final author = (item.reviewAuthorName?.isNotEmpty ?? false)
        ? "${item.reviewAuthorName}'s"
        : 'a';
    final title = item.title ?? 'a track';

    // Older notifications were saved without the person's name.
    var actor = item.actorDisplayName;
    if (needsActorName(actor) && item.actorId != null) {
      actor = ref.watch(actorNameProvider(item.actorId!)).valueOrNull;
    }
    final actorSpan = TextSpan(
        text: needsActorName(actor) ? 'Someone' : actor, style: strong);
    final comment = '“${item.commentText ?? ''}”';

    final List<InlineSpan> sentence = switch (item.type) {
      ActivityType.like => [
          const TextSpan(text: 'You liked '),
          TextSpan(text: author),
          const TextSpan(text: ' review of '),
          TextSpan(text: title, style: strong),
        ],
      ActivityType.repost => [
          const TextSpan(text: 'You reposted '),
          TextSpan(text: author),
          const TextSpan(text: ' review of '),
          TextSpan(text: title, style: strong),
        ],
      ActivityType.comment => [
          const TextSpan(text: 'You commented '),
          TextSpan(text: comment, style: strong),
          TextSpan(text: ' on $author review of '),
          TextSpan(text: title, style: strong),
        ],
      ActivityType.review => [
          const TextSpan(text: 'You reviewed '),
          TextSpan(text: title, style: strong),
          if (item.artist?.isNotEmpty ?? false)
            TextSpan(text: ' by ${item.artist}'),
        ],
      ActivityType.likedYourReview => [
          actorSpan,
          const TextSpan(text: ' liked your review of '),
          TextSpan(text: title, style: strong),
        ],
      ActivityType.commentedOnYourReview => [
          actorSpan,
          const TextSpan(text: ' commented '),
          TextSpan(text: comment, style: strong),
          const TextSpan(text: ' on your review of '),
          TextSpan(text: title, style: strong),
        ],
      ActivityType.repostedYourReview => [
          actorSpan,
          const TextSpan(text: ' reposted your review of '),
          TextSpan(text: title, style: strong),
        ],
      ActivityType.friendAdded => [
          actorSpan,
          const TextSpan(text: ' added you as a friend'),
        ],
      _ => const [TextSpan(text: 'Activity')],
    };

    return InkWell(
      onTap: item.reviewId == null ? null : () => _openReview(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageGutter, vertical: AppSpacing.md),
        child: Row(
          children: [
            _leading(),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(children: sentence),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                  if (_subtitle.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      _subtitle,
                      style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(_typeIcon, size: 18, color: AppColors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  /// Star rating (for reviews) and how long ago.
  String get _subtitle => [
        if (item.score != null) '★ ${_formatScore(item.score!)}',
        if (item.createdAt != null) formatRelativeTime(item.createdAt),
      ].join('  ·  ');

  static String _formatScore(double score) =>
      score == score.roundToDouble() ? '${score.toInt()}' : '$score';

  IconData get _typeIcon => switch (item.type) {
        ActivityType.like ||
        ActivityType.likedYourReview =>
          Icons.favorite_border,
        ActivityType.repost || ActivityType.repostedYourReview => Icons.repeat,
        ActivityType.comment ||
        ActivityType.commentedOnYourReview =>
          Icons.chat_bubble_outline,
        ActivityType.review => Icons.rate_review_outlined,
        ActivityType.friendAdded => Icons.person_add_alt,
        _ => Icons.access_time,
      };

  Widget _leading() {
    final art = item.albumImageUrl;
    if (art != null && art.isNotEmpty) {
      return AppCachedImage(
        imageUrl: art,
        width: _thumbSize,
        height: _thumbSize,
        borderRadius: AppRadius.smAll,
      );
    }
    final isPerson = item.type == ActivityType.friendAdded;
    return Container(
      width: _thumbSize,
      height: _thumbSize,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        shape: isPerson ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isPerson ? null : AppRadius.smAll,
      ),
      child: Icon(isPerson ? Icons.person : Icons.music_note,
          color: AppColors.onSurfaceVariant),
    );
  }

  Future<void> _openReview(BuildContext context) async {
    final path = item.reviewId!;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final data = (await FirebaseFirestore.instance.doc(path).get()).data();
      if (data == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('This review has been deleted')),
        );
        return;
      }
      navigator.push(MaterialPageRoute(
        builder: (_) => ReviewDetailPage(
          review: Review.fromFirestore(data),
          reviewId: path,
        ),
      ));
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't open this review")),
      );
    }
  }
}

class _SliverLoading extends StatelessWidget {
  const _SliverLoading();

  @override
  Widget build(BuildContext context) {
    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
