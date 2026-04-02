import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';

import '../../../models/review.dart';
import '../../../providers/auth_provider.dart' show currentUserIdProvider;
import '../../../providers/friends_provider.dart';
import '../../../providers/review_likes_provider.dart';
import '../../../services/friends_service.dart';
import '../../../services/review_likes_service.dart';
import '../../../utils/cached_image.dart';
import '../../../utils/helpers.dart';

// ─── Design system tokens ────────────────────────────────────────────────────
const _bg = Color(0xFF0E0E0E);
const _surface = Color(0xFF131313);
const _surfaceHigh = Color(0xFF201F1F);
const _primary = Color(0xFFEE2309);
const _secondary = Color(0xFF3FFF8B);

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
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

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
                expandedHeight: 300,
                pinned: false,
                stretch: true,
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground],
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Album art
                      review.albumImageUrl != null
                          ? AppCachedImage(
                              imageUrl: review.albumImageUrl!,
                              width: double.infinity,
                              height: 300,
                              borderRadius: BorderRadius.zero,
                            )
                          : Container(
                              color: _surfaceHigh,
                              child: const Icon(Icons.music_note,
                                  size: 80, color: Colors.white24),
                            ),
                      // Bottom fade into background
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0.4, 1.0],
                              colors: [
                                Colors.transparent,
                                _bg,
                              ],
                            ),
                          ),
                        ),
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
                child: Padding(
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
                              full: const Icon(Icons.star, color: Colors.amber),
                              empty:
                                  const Icon(Icons.star, color: Colors.white24),
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

                      const SizedBox(height: 32),

                      // ── Comments section ──────────────────────────────────
                      _CommentsSection(review: review),
                    ],
                  ),
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
            child: Container(
              decoration: BoxDecoration(
                color: _surface,
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.06)),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        hintStyle:
                            const TextStyle(color: Colors.white38, fontSize: 14),
                        filled: true,
                        fillColor: _surfaceHigh,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      // TODO: submit comment
                      _commentController.clear();
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _primary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Ionicons.arrow_up,
                          color: Colors.white, size: 20),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
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
    final likeCountAsync = reviewId != null
        ? ref.watch(reviewLikeCountProvider(reviewId!))
        : null;
    final isLikedAsync = reviewId != null && userId != null
        ? ref.watch(reviewUserLikeStatusProvider(reviewId!))
        : null;

    final likeCount =
        likeCountAsync?.value ?? review.likes;
    final isLiked = isLikedAsync?.value ?? false;

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
class _CommentsSection extends StatelessWidget {
  final Review review;
  const _CommentsSection({required this.review});

  @override
  Widget build(BuildContext context) {
    // Comments require a Firestore subcollection (future implementation).
    // Displaying header + empty state for now.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Comments (${review.replies})',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                const Icon(Ionicons.swap_vertical_outline,
                    color: Colors.white54, size: 16),
                const SizedBox(width: 4),
                const Text(
                  'Newest',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (review.replies == 0)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No comments yet. Be the first.',
                style: TextStyle(color: Colors.white38, fontSize: 14),
              ),
            ),
          ),
      ],
    );
  }
}
