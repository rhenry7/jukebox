import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';

import '../../../models/review.dart';
import '../../../providers/auth_provider.dart' show currentUserIdProvider;
import '../../../providers/friends_provider.dart';
import '../../../providers/review_comments_provider.dart';
import '../../../providers/review_likes_provider.dart';
import '../../../services/friends_service.dart';
import '../../../services/review_likes_service.dart';
import '../../../utils/helpers.dart';
import '../Profile/helpers/profileHelpers.dart' show openSignIn;
import '../../widgets/review_comments.dart';
import '../../widgets/similar_reviews_row.dart';
import '../../widgets/spotify_play_button.dart';

// ─── Design system tokens ────────────────────────────────────────────────────
const _bg = Color(0xFF0E0E0E);
const _surfaceHigh = Color(0xFF201F1F);
const _primary = Color(0xFFEE2309);

const _heroHeight = 300.0;

/// How far below the hero the frosted art carries on, behind the title and
/// reviewer, before it has faded into the page.
const _glassFadeHeight = 340.0;

class ReviewDetailPage extends ConsumerStatefulWidget {
  final Review review;
  final String? reviewId;

  const ReviewDetailPage({
    super.key,
    required this.review,
    this.reviewId,
  });

  @override
  ConsumerState<ReviewDetailPage> createState() => _ReviewDetailPageState();
}

class _ReviewDetailPageState extends ConsumerState<ReviewDetailPage> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    final albumArt = review.albumImageUrl;
    final hasArt = albumArt != null && albumArt.isNotEmpty;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // ── Hero: album art ──────────────────────────────────────────
              SliverAppBar(
                backgroundColor: _bg,
                expandedHeight: _heroHeight,
                pinned: false,
                stretch: true,
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  // Pinned, not parallax: the hero has to stay lined up with
                  // the frosted art continuing in the body below it.
                  collapseMode: CollapseMode.pin,
                  stretchModes: const [StretchMode.zoomBackground],
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (hasArt) ...[
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: _heroHeight + _glassFadeHeight,
                          child: _FrostedAlbumArt(imageUrl: albumArt),
                        ),
                        // The sharp art melts into the frosted art below it.
                        ShaderMask(
                          blendMode: BlendMode.dstIn,
                          shaderCallback: (bounds) => const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0.45, 1],
                            colors: [Colors.white, Colors.transparent],
                          ).createShader(bounds),
                          // Flutter's own image, not AppCachedImage: on web
                          // that's an HTML <img>, which a mask can't fade.
                          child: Image.network(
                            albumArt,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ] else
                        const ColoredBox(
                          color: _surfaceHigh,
                          child: Icon(Icons.music_note,
                              size: 80, color: Colors.white24),
                        ),
                      // Genre pills overlaid at bottom-left
                      if (review.genres != null && review.genres!.isNotEmpty)
                        Positioned(
                          left: 20,
                          bottom: 20,
                          child: Row(
                            children: review.genres!.take(2).map((g) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: Colors.white12, width: 1),
                                  ),
                                  child: Text(
                                    g.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ── Body content ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    // The rest of the hero's frosted art, offset to line up.
                    if (hasArt)
                      Positioned(
                        top: -_heroHeight,
                        left: 0,
                        right: 0,
                        height: _heroHeight + _glassFadeHeight,
                        child: _FrostedAlbumArt(imageUrl: albumArt),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title + artist
                          Text(
                            review.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            review.artist,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ── Reviewer row ─────────────────────────────────────
                          _ReviewerRow(review: review),

                          const SizedBox(height: 20),

                          // ── Rating ───────────────────────────────────────────
                          Row(
                            children: [
                              RatingBar(
                                minRating: 0,
                                maxRating: 5,
                                allowHalfRating: true,
                                initialRating: review.score,
                                itemSize: 22,
                                itemPadding: const EdgeInsets.only(right: 3),
                                ratingWidget: RatingWidget(
                                  full: const Icon(Icons.star,
                                      color: Colors.amber),
                                  empty: const Icon(Icons.star,
                                      color: Colors.white24),
                                  half: const Icon(Icons.star_half,
                                      color: Colors.amber),
                                ),
                                ignoreGestures: true,
                                onRatingUpdate: (_) {},
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${review.score.toStringAsFixed(1)} / 5.0',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // ── Play on Spotify ──────────────────────────────────
                          SpotifyPlayButton(
                            title: review.title,
                            artist: review.artist,
                            url: review.spotifyUrl,
                          ),

                          const SizedBox(height: 24),

                          // ── Review body ───────────────────────────────────────
                          if (review.review.isNotEmpty)
                            Text(
                              review.review,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                height: 1.65,
                              ),
                            ),

                          const SizedBox(height: 28),

                          // ── Stats / action bar ────────────────────────────────
                          _StatsBar(
                            review: review,
                            reviewId: widget.reviewId,
                          ),

                          const SizedBox(height: 28),

                          // ── Similar reviews ───────────────────────────────────
                          SimilarReviewsRow(
                            review: review,
                            reviewId: widget.reviewId,
                            gutter: 20,
                          ),

                          const SizedBox(height: 32),

                          // ── Comments section ──────────────────────────────────
                          _CommentsSection(
                            review: review,
                            reviewId: widget.reviewId,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Back button overlaid on hero ──────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.5),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 16, color: Colors.white),
              ),
            ),
          ),

          // ── Sticky comment input ──────────────────────────────────────────
          Positioned(
            bottom: bottomPad,
            left: 0,
            right: 0,
            child: CommentComposer(review: review, reviewId: widget.reviewId),
          ),
        ],
      ),
    );
  }
}

/// The album art through frosted glass, running from the top of the page down
/// behind the title and fading out into the page background. Painted in two
/// pieces (hero and body) that line up, so it scrolls as one pane.
///
/// Blurred the same way as the review cards ([CardSurface]): decoding the art
/// tiny and stretching it, because a live blur is what runs iOS out of GPU
/// memory.
class _FrostedAlbumArt extends StatelessWidget {
  const _FrostedAlbumArt({required this.imageUrl});

  final String imageUrl;

  static const int _blurSourceWidth = 6;

  /// Where the hero ends, as a fraction of this pane's height.
  static const double _heroEnd = _heroHeight / (_heroHeight + _glassFadeHeight);

  /// How much page colour tints the art where the title sits. Dark enough
  /// for white text on the palest album covers.
  static const double _tintAtTitle = 0.64;
  static const double _sheenAtTitle = 0.07;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image(
            image: ResizeImage(
              NetworkImage(imageUrl),
              width: _blurSourceWidth,
              policy: ResizeImagePolicy.fit,
            ),
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, _heroEnd, 1],
                colors: [
                  _bg.withValues(alpha: 0),
                  _bg.withValues(alpha: _tintAtTitle),
                  _bg,
                ],
              ),
            ),
          ),
          // The glass: a faint milky sheen, strongest behind the title.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, _heroEnd, 1],
                colors: [
                  Colors.white.withValues(alpha: 0),
                  Colors.white.withValues(alpha: _sheenAtTitle),
                  Colors.white.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reviewer row with Follow / Add Friend button ─────────────────────────────
class _ReviewerRow extends ConsumerStatefulWidget {
  final Review review;
  const _ReviewerRow({required this.review});

  @override
  ConsumerState<_ReviewerRow> createState() => _ReviewerRowState();
}

class _ReviewerRowState extends ConsumerState<_ReviewerRow> {
  bool _isLoading = false;

  Future<void> _toggleFriend() async {
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) return;
    setState(() => _isLoading = true);
    try {
      final service = FriendsService();
      final isFriend = ref.read(isFriendProvider(widget.review.userId));
      if (isFriend) {
        await service.removeFriend(
            currentUserId: currentUserId, friendId: widget.review.userId);
      } else {
        await service.addFriend(
          currentUserId: currentUserId,
          friendId: widget.review.userId,
          friendDisplayName: widget.review.displayName,
        );
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final isOwnReview = widget.review.userId == currentUserId;
    final isFriend = !isOwnReview &&
        widget.review.userId.isNotEmpty &&
        ref.watch(isFriendProvider(widget.review.userId));

    return Row(
      children: [
        // Avatar
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey[850],
          ),
          child: const Icon(Icons.person, size: 24, color: Colors.white54),
        ),
        const SizedBox(width: 12),
        // Name + subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.review.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (widget.review.date != null)
                Text(
                  formatRelativeTime(widget.review.date),
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        // Follow / Friend button (hidden for own review)
        if (!isOwnReview)
          GestureDetector(
            onTap: _isLoading ? null : _toggleFriend,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(
                    color: isFriend ? Colors.white24 : Colors.white38,
                    width: 1),
                color: isFriend ? Colors.white10 : Colors.transparent,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: Colors.white),
                    )
                  : Text(
                      isFriend ? 'Following' : 'Follow',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ),
      ],
    );
  }
}

// ── Stats / action bar ────────────────────────────────────────────────────────
class _StatsBar extends ConsumerWidget {
  final Review review;
  final String? reviewId;
  const _StatsBar({required this.review, this.reviewId});

  String _fmt(int n) {
    if (n >= 1000) {
      final k = (n / 1000).toStringAsFixed(1);
      return k.endsWith('.0') ? '${k.substring(0, k.length - 2)}k' : '${k}k';
    }
    return n.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);

    // Use live like count if reviewId is available, otherwise fall back to model
    final likeCountAsync =
        reviewId != null ? ref.watch(reviewLikeCountProvider(reviewId!)) : null;
    final isLikedAsync = reviewId != null && userId != null
        ? ref.watch(reviewUserLikeStatusProvider(reviewId!))
        : null;

    final likeCount = likeCountAsync?.valueOrNull ?? review.likes;
    final isLiked = isLikedAsync?.valueOrNull ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.07)),
          bottom: BorderSide(color: Colors.white.withOpacity(0.07)),
        ),
      ),
      child: Row(
        children: [
          // Like
          GestureDetector(
            onTap: reviewId != null && userId != null
                ? () async {
                    try {
                      await ReviewLikesService().toggleLike(reviewId!, userId);
                    } catch (_) {}
                  }
                : null,
            child: Row(
              children: [
                Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? _primary : Colors.white60,
                  size: 22,
                ),
                const SizedBox(width: 6),
                Text(
                  _fmt(likeCount),
                  style: TextStyle(
                    color: isLiked ? _primary : Colors.white60,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 28),
          // Comments count
          Row(
            children: [
              const Icon(Ionicons.chatbubble_outline,
                  color: Colors.white60, size: 20),
              const SizedBox(width: 6),
              Text(
                _fmt(review.replies),
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(width: 28),
          // Reposts
          Row(
            children: [
              const Icon(Ionicons.repeat, color: Colors.white60, size: 22),
              const SizedBox(width: 6),
              Text(
                _fmt(review.reposts),
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Share
          const Icon(Ionicons.share_outline, color: Colors.white60, size: 22),
        ],
      ),
    );
  }
}

// ── Comments section ─────────────────────────────────────────────────────────
class _CommentsSection extends ConsumerWidget {
  final Review review;
  final String? reviewId;
  const _CommentsSection({required this.review, this.reviewId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(currentUserIdProvider) != null;
    final commentsAsync =
        reviewId != null ? ref.watch(reviewCommentsProvider(reviewId!)) : null;

    final comments = commentsAsync?.valueOrNull ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Comments (${comments.length})',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (comments.isNotEmpty)
              const Row(
                children: [
                  Icon(Ionicons.swap_vertical_outline,
                      color: Colors.white54, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Newest',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 16),
        // Comments are for signed-in users only.
        if (!signedIn)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(
                children: [
                  const Text(
                    'Sign in to read the comments.',
                    style: TextStyle(color: Colors.white60, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => openSignIn(context),
                    child: const Text('Sign in'),
                  ),
                ],
              ),
            ),
          )
        // Loading state
        else if (commentsAsync != null && commentsAsync.isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white24),
            ),
          )
        else if (commentsAsync != null && commentsAsync.hasError)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                "Couldn't load the comments. Reopen the review to try again.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 14),
              ),
            ),
          )
        // Empty state
        else if (comments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No comments yet. Be the first.',
                style: TextStyle(color: Colors.white38, fontSize: 14),
              ),
            ),
          )
        // Comment list
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: comments.length,
            separatorBuilder: (_, __) => Divider(
              color: Colors.white.withOpacity(0.06),
              height: 1,
            ),
            itemBuilder: (context, i) => CommentTile(
              comment: comments[i],
              reviewId: reviewId!,
            ),
          ),
      ],
    );
  }
}
