import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';

import '../../../models/review.dart';
import '../../../models/review_comment.dart';
import '../../../providers/auth_provider.dart'
    show currentUserIdProvider, currentUserProvider, isAnonymousUserProvider;
import '../../../providers/friends_provider.dart';
import '../../../providers/review_comments_provider.dart';
import '../../../providers/review_likes_provider.dart';
import '../../../services/friends_service.dart';
import '../../../services/review_comments_service.dart';
import '../../../services/review_likes_service.dart';
import '../../../utils/cached_image.dart';
import '../../../utils/helpers.dart';
import '../../widgets/auth_gate_modal.dart';

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

  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    final isAnon = ref.read(isAnonymousUserProvider);
    if (isAnon) {
      showAuthGateModal(context);
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null || widget.reviewId == null) return;

    setState(() => _isSubmitting = true);
    try {
      await ReviewCommentsService().addComment(
        reviewId: widget.reviewId!,
        userId: user.uid,
        displayName: user.displayName?.isNotEmpty == true
            ? user.displayName!
            : 'Anonymous',
        text: text,
        reviewOwnerUserId: widget.review.userId,
        reviewTitle: widget.review.title,
        reviewArtist: widget.review.artist,
      );
      _commentController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error posting comment: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
                      _CommentsSection(
                        review: review,
                        reviewId: widget.reviewId,
                      ),
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
                    child: Builder(builder: (context) {
                      final isAnon = ref.watch(isAnonymousUserProvider);
                      return GestureDetector(
                        onTap: isAnon
                            ? () => showAuthGateModal(context)
                            : null,
                        child: AbsorbPointer(
                          absorbing: isAnon,
                          child: TextField(
                            controller: _commentController,
                            maxLines: null,
                            minLines: 1,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14, height: 1.4),
                            decoration: InputDecoration(
                              hintText: isAnon
                                  ? 'Sign in to comment...'
                                  : 'Write a comment...',
                              hintStyle: const TextStyle(
                                  color: Colors.white38, fontSize: 14),
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
                      );
                    }),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _submitComment,
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
class _CommentsSection extends ConsumerWidget {
  final Review review;
  final String? reviewId;
  const _CommentsSection({required this.review, this.reviewId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentsAsync = reviewId != null
        ? ref.watch(reviewCommentsProvider(reviewId!))
        : null;

    final comments = commentsAsync?.value ?? [];

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
        const SizedBox(height: 16),
        // Loading state
        if (commentsAsync != null && commentsAsync.isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white24),
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
            itemBuilder: (context, i) => _CommentTile(
              comment: comments[i],
              reviewId: reviewId!,
            ),
          ),
      ],
    );
  }
}

// ── Single comment tile ───────────────────────────────────────────────────────
class _CommentTile extends ConsumerStatefulWidget {
  final ReviewComment comment;
  final String reviewId;
  const _CommentTile({required this.comment, required this.reviewId});

  @override
  ConsumerState<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends ConsumerState<_CommentTile> {
  bool _isEditing = false;
  bool _isSaving = false;
  late final TextEditingController _editController;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.comment.text);
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  Future<void> _saveEdit(String currentUserId) async {
    final trimmed = _editController.text.trim();
    if (trimmed.isEmpty || trimmed == widget.comment.text) {
      setState(() => _isEditing = false);
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ReviewCommentsService().updateComment(
        reviewId: widget.reviewId,
        commentId: widget.comment.id,
        userId: currentUserId,
        newText: trimmed,
      );
      if (mounted) setState(() => _isEditing = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save edit: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final isAnon = ref.watch(isAnonymousUserProvider);
    final isOwn = widget.comment.userId == currentUserId;

    final likeKey = (
      reviewId: widget.reviewId,
      commentId: widget.comment.id,
      userId: currentUserId ?? '',
    );
    final isLiked = currentUserId != null
        ? ref.watch(commentLikeStatusProvider(likeKey)).value ?? false
        : false;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[850],
            ),
            child: const Icon(Icons.person, size: 18, color: Colors.white38),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + time
                Row(
                  children: [
                    Text(
                      widget.comment.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (widget.comment.createdAt != null)
                      Text(
                        formatRelativeTime(widget.comment.createdAt),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),

                // ── Comment body OR inline edit field ────────────────────
                if (_isEditing) ...[
                  TextField(
                    controller: _editController,
                    autofocus: true,
                    maxLines: null,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, height: 1.45),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF201F1F),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _isSaving
                            ? null
                            : () => _saveEdit(currentUserId!),
                        child: _isSaving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 1.5, color: Colors.white54),
                              )
                            : const Text(
                                'SAVE',
                                style: TextStyle(
                                  color: Color(0xFF3FFF8B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                      ),
                      const SizedBox(width: 20),
                      GestureDetector(
                        onTap: () {
                          _editController.text = widget.comment.text;
                          setState(() => _isEditing = false);
                        },
                        child: const Text(
                          'CANCEL',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Text(
                    widget.comment.text,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Like + Reply + Edit + Delete actions
                  Row(
                    children: [
                      // Like
                      GestureDetector(
                        onTap: () async {
                          if (isAnon) {
                            showAuthGateModal(context);
                            return;
                          }
                          if (currentUserId == null) return;
                          try {
                            await ReviewCommentsService().toggleCommentLike(
                              reviewId: widget.reviewId,
                              commentId: widget.comment.id,
                              userId: currentUserId,
                            );
                          } catch (_) {}
                        },
                        child: Row(
                          children: [
                            Icon(
                              isLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 15,
                              color: isLiked
                                  ? const Color(0xFFEE2309)
                                  : Colors.white38,
                            ),
                            if (widget.comment.likes > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '${widget.comment.likes}',
                                style: TextStyle(
                                  color: isLiked
                                      ? const Color(0xFFEE2309)
                                      : Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Reply
                      GestureDetector(
                        onTap: () {
                          if (isAnon) {
                            showAuthGateModal(context);
                            return;
                          }
                          // TODO: reply threading
                        },
                        child: const Text(
                          'REPLY',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      // Edit + Delete (own comments only)
                      if (isOwn) ...[
                        const SizedBox(width: 20),
                        GestureDetector(
                          onTap: () => setState(() => _isEditing = true),
                          child: const Text(
                            'EDIT',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        GestureDetector(
                          onTap: () async {
                            try {
                              await ReviewCommentsService().deleteComment(
                                reviewId: widget.reviewId,
                                commentId: widget.comment.id,
                                userId: currentUserId!,
                              );
                            } catch (_) {}
                          },
                          child: const Text(
                            'DELETE',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
