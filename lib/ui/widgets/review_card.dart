import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';

import '../../models/review.dart';
import '../../providers/auth_provider.dart' show currentUserIdProvider;
import '../../providers/review_likes_provider.dart';
import '../../providers/friends_provider.dart';
import '../../services/genre_cache_service.dart';
import '../../services/review_likes_service.dart';
import '../../utils/helpers.dart';
import '../../utils/cached_image.dart';
import '../../providers/auth_provider.dart'
    show currentUserProvider, isAnonymousUserProvider;
import '../../providers/bookmarks_provider.dart';
import '../../providers/repost_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../providers/reviews_provider.dart' show reviewsByUserProvider;
import '../../providers/similar_reviews_provider.dart';
import '../../services/bookmark_service.dart';
import '../../services/repost_service.dart';
import '../screens/Profile/profilePage.dart';
import '../screens/review_detail/review_detail_page.dart';
import '../theme/tokens.dart';
import 'auth_gate_modal.dart';
import 'card_surface.dart';
import 'friend_toggle.dart';
import 'genre_pills.dart';
import 'review_comments.dart';
import 'spotify_play_button.dart';
import 'app_toast.dart';
import 'glass.dart';

/// Starts loading what the review page shows beyond the review itself (the
/// "More like this" row), ahead of the tap that opens it. The data is kept
/// for a few minutes, so a touch that doesn't become a tap costs one query.
void prefetchReviewPage(
    ProviderContainer container, Review review, String? reviewId) {
  container
      .read(similarReviewsProvider(similarReviewsKeyFor(review, reviewId)));
}

/// Cards show only the start of the review; the full text is on the detail
/// page. Cuts at a word boundary near [maxChars] and adds an ellipsis.
@visibleForTesting
String reviewPreview(String text, {int maxChars = 200}) {
  final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (flat.length <= maxChars) return flat;
  var cut = flat.substring(0, maxChars);
  final lastSpace = cut.lastIndexOf(' ');
  // Avoid splitting a word, unless that would drop most of the preview.
  if (lastSpace > maxChars * 0.7) cut = cut.substring(0, lastSpace);
  return '${cut.replaceAll(RegExp(r'[\s.,;:!?\-–—]+$'), '')}…';
}

/// Core review card UI. Used across Popular, Friends, For You, Profile, Search,
/// and Album Detail screens. Always edit here — never duplicate this widget.
class ReviewCardWidget extends ConsumerWidget {
  final Review review;
  final String?
      reviewId; // Full review ID for likes: users/{userId}/reviews/{docId}
  final bool showLikeButton; // Only show like button in community tab

  const ReviewCardWidget({
    super.key,
    required this.review,
    this.reviewId,
    this.showLikeButton = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tappable area: album art, review text, tags → navigates to detail
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            // Start loading the review page's data on touch, so it's
            // usually ready when the page opens.
            onTapDown: (_) => prefetchReviewPage(
                ProviderScope.containerOf(context, listen: false),
                review,
                reviewId),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ReviewDetailPage(
                  review: review,
                  reviewId: reviewId,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Album art + Artist / Title / Rating
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Album Cover
                    review.albumImageUrl != null
                        ? AppCachedImage(
                            imageUrl: review.albumImageUrl!,
                            width: 100,
                            height: 100,
                            borderRadius: AppRadius.smAll,
                          )
                        : ClipRRect(
                            borderRadius: AppRadius.smAll,
                            child: Container(
                              width: 100,
                              height: 100,
                              color: Colors.white10,
                              child: const Icon(Icons.music_note,
                                  size: 48, color: Colors.white38),
                            ),
                          ),
                    const SizedBox(width: AppSpacing.lg),
                    // Artist, Title, Rating + Timestamp
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            review.artist,
                            style: const TextStyle(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            review.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(
                                child: RatingBar(
                                  minRating: 0,
                                  maxRating: 5,
                                  allowHalfRating: true,
                                  initialRating: review.score,
                                  itemSize: 20,
                                  itemPadding:
                                      const EdgeInsets.only(right: 2.0),
                                  ratingWidget: RatingWidget(
                                    full: const Icon(Icons.star,
                                        color: AppColors.rating),
                                    empty: const Icon(Icons.star,
                                        color: Colors.grey),
                                    half: const Icon(Icons.star_half,
                                        color: AppColors.rating),
                                  ),
                                  ignoreGestures: true,
                                  onRatingUpdate: (rating) {},
                                ),
                              ),
                              if (review.date != null)
                                const SizedBox(width: AppSpacing.sm),
                              if (review.date != null)
                                Text(
                                  formatRelativeTime(review.date),
                                  style: const TextStyle(
                                    color: AppColors.onSurfaceVariant,
                                    fontSize: 13,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    SpotifyPlayButton(
                      title: review.title,
                      artist: review.artist,
                      url: review.spotifyUrl,
                      compact: true,
                    ),
                  ],
                ),
                // Review text
                if (review.review.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    reviewPreview(review.review),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15.0,
                      height: 1.5,
                    ),
                  ),
                ],
                GenrePills(tags: splitGenreTags(review.genres)),
              ],
            ),
          ),
          // Bottom row: user info + action buttons (independently tappable)
          const SizedBox(height: AppSpacing.xl),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // User avatar + display name (tappable)
              if (review.displayName.isNotEmpty)
                GestureDetector(
                  onTap: () => _showUserProfileSheet(context, ref, review),
                  child: Builder(builder: (context) {
                    final currentUserId = ref.watch(currentUserIdProvider);
                    final isOwnReview = review.userId == currentUserId;
                    final isFriend = !isOwnReview &&
                        review.userId.isNotEmpty &&
                        ref.watch(isFriendProvider(review.userId));
                    final showPlusBadge = !isOwnReview && !isFriend;

                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.grey[800],
                                ),
                                child: const Icon(Icons.person,
                                    size: 22, color: Colors.white60),
                              ),
                              if (showPlusBadge)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 15,
                                    height: 15,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.greenAccent[700],
                                      border: Border.all(
                                          color: Colors.black, width: 1.5),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      '+',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        height: 1.0,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          review.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              const Spacer(),
              // Action buttons: like, comment, repost, bookmark
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showLikeButton && reviewId != null)
                    _LikeButton(reviewId: reviewId!)
                  else
                    const _StaticLikeCount(),
                  const SizedBox(width: AppSpacing.lg),
                  GestureDetector(
                    onTap: reviewId == null
                        ? null
                        : () => showReviewCommentsSheet(
                              context,
                              review: review,
                              reviewId: reviewId!,
                            ),
                    child: const Icon(
                      Ionicons.chatbubbleOutline,
                      color: Colors.white70,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  if (reviewId != null)
                    _RepostButton(
                      reviewId: reviewId!,
                      review: review,
                    )
                  else
                    const Icon(Ionicons.repeat,
                        color: Colors.white70, size: 22),
                  if (reviewId != null) ...[
                    const SizedBox(width: AppSpacing.lg),
                    _BookmarkButton(reviewId: reviewId!),
                  ],
                ],
              ),
            ],
          )
        ],
      ),
    );
  }

  /// Shows a bottom sheet with the reviewer's info and an add/remove friend button.
  void _showUserProfileSheet(
      BuildContext context, WidgetRef ref, Review review) {
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) return;

    // Don't show for the user's own reviews
    if (review.userId == currentUserId) {
      showAppToast(context, 'This is your review!', duration: const Duration(seconds: 1));
      return;
    }

    // "View profile" is the likely next tap; start loading that page.
    ref.read(reviewsByUserProvider(review.userId));
    ref.read(userProfileInfoProvider(review.userId));

    const radius = BorderRadius.vertical(top: Radius.circular(AppRadius.xl));
    showModalBottomSheet(
      context: context,
      // Frosted glass: the sheet is see-through and blurs the feed behind
      // it, so the dimming behind it is lighter than usual.
      backgroundColor: Colors.transparent,
      elevation: 0,
      barrierColor: Colors.black26,
      shape: const RoundedRectangleBorder(borderRadius: radius),
      builder: (sheetContext) {
        return GlassSurface(
          borderRadius: radius,
          child: _UserProfileSheet(
            reviewUserId: review.userId,
            reviewDisplayName: review.displayName,
),
        );
      },
    );
  }
}

/// Bottom sheet content showing reviewer info with add/remove friend toggle.
class _UserProfileSheet extends ConsumerStatefulWidget {
  final String reviewUserId;
  final String reviewDisplayName;

  const _UserProfileSheet({
    required this.reviewUserId,
    required this.reviewDisplayName,
  });

  @override
  ConsumerState<_UserProfileSheet> createState() => _UserProfileSheetState();
}

class _UserProfileSheetState extends ConsumerState<_UserProfileSheet> {
  bool _isLoading = false;

  Future<void> _toggleFriend() async {
    setState(() => _isLoading = true);
    await toggleFriend(context, ref,
        friendId: widget.reviewUserId, friendName: widget.reviewDisplayName);
    if (mounted) setState(() => _isLoading = false);
  }

  /// Closes the sheet and opens the reviewer's full profile.
  void _viewProfile() {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(MaterialPageRoute(
      builder: (_) => ProfilePage(
        userId: widget.reviewUserId,
        displayName: widget.reviewDisplayName,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isFriend = ref.watch(isFriendProvider(widget.reviewUserId));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Avatar placeholder
          CircleAvatar(
            radius: 36,
            backgroundColor: Colors.grey[800],
            child: Text(
              widget.reviewDisplayName.isNotEmpty
                  ? widget.reviewDisplayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          // Display name
          Text(
            widget.reviewDisplayName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          // Friend status badge
          if (isFriend)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.green[400], size: 16),
                const SizedBox(width: 4),
                Text('Friend',
                    style: TextStyle(color: Colors.green[400], fontSize: 13)),
              ],
            ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _viewProfile,
              icon: const Icon(Icons.person_outline),
              label: const Text('View profile',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Add / Remove friend button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _toggleFriend,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(
                      isFriend ? Icons.person_remove : Icons.person_add,
                      color: Colors.white,
                    ),
              label: Text(
                isFriend ? 'Remove Friend' : 'Add Friend',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isFriend ? Colors.red[700] : Colors.green[700],
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// Static heart icon shown when no reviewId is available (no like interaction)
class _StaticLikeCount extends StatelessWidget {
  const _StaticLikeCount();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.favorite_border,
      color: Colors.white70,
      size: 22,
    );
  }
}

// Like button widget for review cards
class _LikeButton extends ConsumerWidget {
  final String reviewId;

  const _LikeButton({required this.reviewId});

  String _formatLikeCount(int count) {
    if (count >= 1000) {
      final k = (count / 1000).toStringAsFixed(1);
      return k.endsWith('.0') ? '${k.substring(0, k.length - 2)}k' : '${k}k';
    }
    return count.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    final likeCountAsync = ref.watch(reviewLikeCountProvider(reviewId));
    final isLikedAsync = userId != null
        ? ref.watch(reviewUserLikeStatusProvider(reviewId))
        : const AsyncValue.data(false);

    // The heart shows straight away; the count fills in when it arrives
    // (and stays hidden if it can't be read). A spinner here sat on cards
    // while dozens of counts loaded at once.
    final likeCount = likeCountAsync.valueOrNull ?? 0;
    final isLiked = isLikedAsync.valueOrNull ?? false;

    return GestureDetector(
      onTap: userId != null
          ? () async {
              try {
                final service = ReviewLikesService();
                await service.toggleLike(reviewId, userId);
              } catch (e) {
                if (context.mounted) {
                  debugPrint('Like failed: $e');
                  showAppToast(context, "Couldn't update the like. Try again.", tone: ToastTone.error);
                }
              }
            }
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLiked ? Icons.favorite : Icons.favorite_border,
            color: isLiked ? Colors.red : Colors.white70,
            size: 22,
          ),
          if (likeCount > 0) ...[
            const SizedBox(width: 4),
            Text(
              _formatLikeCount(likeCount),
              style: TextStyle(
                color: isLiked ? Colors.red : Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Repost header shown above a reposted card ────────────────────────────────
class _RepostHeader extends StatelessWidget {
  final String displayName;
  const _RepostHeader({required this.displayName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.cardPadding, AppSpacing.md, AppSpacing.cardPadding, 0),
      child: Row(
        children: [
          const Icon(Ionicons.repeat, size: 14, color: Colors.white38),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '$displayName reposted',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Repost toggle button ──────────────────────────────────────────────────────
class _RepostButton extends ConsumerWidget {
  final String reviewId;
  final Review review;
  const _RepostButton({required this.reviewId, required this.review});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final isAnon = ref.watch(isAnonymousUserProvider);

    final isReposted = currentUserId != null
        ? ref
                .watch(repostStatusProvider(
                    (reviewId: reviewId, userId: currentUserId)))
                .valueOrNull ??
            false
        : false;

    final repostCount =
        ref.watch(repostCountProvider(reviewId)).valueOrNull ?? review.reposts;

    return GestureDetector(
      onTap: () async {
        if (isAnon) {
          showAuthGateModal(context);
          return;
        }
        if (currentUserId == null) return;
        // Prevent reposting your own review
        if (review.userId == currentUserId) {
          showAppToast(context, 'You can\'t repost your own review.', duration: const Duration(seconds: 2));
          return;
        }
        try {
          await RepostService().toggleRepost(
            originalReviewId: reviewId,
            reposterUserId: currentUserId,
            reposterDisplayName:
                ref.read(currentUserProvider)?.displayName ?? 'Someone',
            originalReview: review,
            originalUserId: review.userId,
          );
        } catch (e) {
          if (context.mounted) {
            debugPrint('Repost failed: $e');
              showAppToast(context, "Couldn't repost. Try again.", tone: ToastTone.error);
          }
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Ionicons.repeat,
            size: 22,
            color: isReposted
                ? const Color(0xFF3FFF8B) // secondary green when active
                : Colors.white70,
          ),
          if (repostCount > 0) ...[
            const SizedBox(width: 4),
            Text(
              '$repostCount',
              style: TextStyle(
                color: isReposted ? const Color(0xFF3FFF8B) : Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Bookmark toggle button ────────────────────────────────────────────────────
/// Saves the review to Profile → Bookmarks, or removes it.
class _BookmarkButton extends ConsumerWidget {
  final String reviewId;
  const _BookmarkButton({required this.reviewId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSaved = ref.watch(bookmarkedPathsProvider).contains(reviewId);

    return GestureDetector(
      onTap: () async {
        if (ref.read(isAnonymousUserProvider)) {
          showAuthGateModal(context);
          return;
        }
        final userId = ref.read(currentUserIdProvider);
        if (userId == null) return;
        try {
          await BookmarkService().toggle(
            userId: userId,
            reviewPath: reviewId,
            isBookmarked: isSaved,
          );
        } catch (e) {
          if (context.mounted) {
            debugPrint('Bookmark failed: $e');
            showAppToast(context, "Couldn't update the bookmark. Try again.", tone: ToastTone.error);
          }
        }
      },
      child: Semantics(
        button: true,
        label: isSaved ? 'Remove bookmark' : 'Bookmark',
        child: Icon(
          isSaved ? Ionicons.bookmark : Ionicons.bookmarkOutline,
          size: 22,
          color: isSaved ? AppColors.secondary : Colors.white70,
        ),
      ),
    );
  }
}

/// Wrapper around [ReviewCardWidget] that handles async genre loading via
/// [GenreCacheService]. All screens should use this rather than
/// [ReviewCardWidget] directly.
class ReviewCardWithGenres extends StatefulWidget {
  final Review review;
  final String? reviewId; // Full review ID for likes
  final bool showLikeButton;

  const ReviewCardWithGenres({
    super.key,
    required this.review,
    this.reviewId,
    this.showLikeButton = false,
  });

  @override
  State<ReviewCardWithGenres> createState() => _ReviewCardWithGenresState();
}

class _ReviewCardWithGenresState extends State<ReviewCardWithGenres> {
  List<String>? _genres;
  bool _isLoadingGenres = false;

  @override
  void initState() {
    super.initState();
    _genres = _splitGenres(widget.review.genres);
    // If no genres after splitting, fetch them
    if (_genres == null || _genres!.isEmpty) {
      _loadGenres();
    }
  }

  @override
  void didUpdateWidget(ReviewCardWithGenres oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A list can hand this card a different review (a refresh or reshuffle,
    // a delete above it): show that review's tags, not the previous one's.
    final before = oldWidget.review;
    final now = widget.review;
    if (before.title != now.title ||
        before.artist != now.artist ||
        !listEquals(before.genres, now.genres)) {
      _isLoadingGenres = false;
      _genres = _splitGenres(now.genres);
      if (_genres == null) _loadGenres();
    }
  }

  List<String>? _splitGenres(List<String>? raw) {
    final tags = splitGenreTags(raw);
    return tags.isEmpty ? null : tags;
  }

  Future<void> _loadGenres() async {
    if (_isLoadingGenres) return;

    setState(() {
      _isLoadingGenres = true;
    });

    try {
      // Use cache service: checks Firestore cache first, then MusicBrainz API
      final title = widget.review.title;
      final artist = widget.review.artist;
      final genres = await GenreCacheService.getGenresWithCache(title, artist);
      // The card may show a different review by now (see didUpdateWidget).
      if (!mounted ||
          widget.review.title != title ||
          widget.review.artist != artist) {
        return;
      }

      if (genres.isNotEmpty) {
        setState(() {
          _genres = genres;
          _isLoadingGenres = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('Error loading genres: $e');
    }

    // If MusicBrainz fails, genres remain null/empty
    if (mounted) {
      setState(() {
        _isLoadingGenres = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final genres = _genres ?? widget.review.genres;
    final card = ReviewCardWidget(
      review: widget.review.copyWith(genres: genres),
      reviewId: widget.reviewId,
      showLikeButton: widget.showLikeButton,
    );

    // Show "X reposted" header when this card is a repost
    if (widget.review.isRepost && widget.review.repostedByDisplayName != null) {
      return CardSurface(
        imageUrl: widget.review.albumImageUrl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RepostHeader(displayName: widget.review.repostedByDisplayName!),
            card,
          ],
        ),
      );
    }

    return CardSurface(
      imageUrl: widget.review.albumImageUrl,
      child: card,
    );
  }
}

// Extension to add copyWith to Review
extension ReviewCopyWith on Review {
  Review copyWith({
    String? displayName,
    String? userId,
    String? artist,
    String? review,
    double? score,
    DateTime? date,
    String? albumImageUrl,
    String? userImageUrl,
    int? likes,
    int? replies,
    int? reposts,
    String? title,
    List<String>? genres,
    bool? isRepost,
    String? repostedByDisplayName,
    String? repostedByUserId,
    String? originalReviewId,
    String? spotifyUrl,
  }) {
    return Review(
      displayName: displayName ?? this.displayName,
      userId: userId ?? this.userId,
      artist: artist ?? this.artist,
      review: review ?? this.review,
      score: score ?? this.score,
      date: date ?? this.date,
      albumImageUrl: albumImageUrl ?? this.albumImageUrl,
      userImageUrl: userImageUrl ?? this.userImageUrl,
      likes: likes ?? this.likes,
      replies: replies ?? this.replies,
      reposts: reposts ?? this.reposts,
      title: title ?? this.title,
      genres: genres ?? this.genres,
      isRepost: isRepost ?? this.isRepost,
      repostedByDisplayName:
          repostedByDisplayName ?? this.repostedByDisplayName,
      repostedByUserId: repostedByUserId ?? this.repostedByUserId,
      originalReviewId: originalReviewId ?? this.originalReviewId,
      spotifyUrl: spotifyUrl ?? this.spotifyUrl,
    );
  }
}

/// A small horizontal review card for carousels (the review page's "More like
/// this" row): album art beside the stars, song or album, artist, and the
/// reviewer and date, with the Spotify button at the bottom right; under them
/// up to five of the review's tags. Tapping it opens the review.
class CompactReviewCard extends StatelessWidget {
  const CompactReviewCard({
    super.key,
    required this.review,
    required this.reviewId,
  });

  final Review review;
  final String? reviewId;

  static const double width = 300;
  static const double height = 140;
  static const double _artSize = 72;
  static const int _maxTags = 5;

  @override
  Widget build(BuildContext context) {
    final date = review.date;
    return SizedBox(
      width: width,
      height: height,
      child: Semantics(
        button: true,
        label: '${review.title} by ${review.artist}, '
            'reviewed by ${review.displayName}',
        child: CardSurface(
          imageUrl: review.albumImageUrl,
          child: InkWell(
            onTapDown: (_) => prefetchReviewPage(
                ProviderScope.containerOf(context, listen: false),
                review,
                reviewId),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    ReviewDetailPage(review: review, reviewId: reviewId),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: SizedBox.square(
                          dimension: _artSize,
                          child: review.albumImageUrl?.isNotEmpty == true
                              ? AppCachedImage(
                                  imageUrl: review.albumImageUrl!,
                                  width: _artSize,
                                  height: _artSize,
                                )
                              : const ColoredBox(
                                  color: AppColors.surfaceContainerHigh,
                                  child: Icon(Icons.music_note,
                                      color: Colors.white24),
                                ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RatingBar(
                              minRating: 0,
                              maxRating: 5,
                              allowHalfRating: true,
                              initialRating: review.score,
                              itemSize: 14,
                              itemPadding: const EdgeInsets.only(right: 1),
                              ratingWidget: RatingWidget(
                                full: const Icon(Icons.star,
                                    color: AppColors.rating),
                                empty:
                                    const Icon(Icons.star, color: Colors.grey),
                                half: const Icon(Icons.star_half,
                                    color: AppColors.rating),
                              ),
                              ignoreGestures: true,
                              onRatingUpdate: (_) {},
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              review.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.onSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              review.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text.rich(
                              TextSpan(children: [
                                TextSpan(
                                  text: review.displayName,
                                  style: const TextStyle(
                                    color: AppColors.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (date != null)
                                  TextSpan(
                                    text: ' · ${formatRelativeTime(date)}',
                                    style: const TextStyle(
                                        color: AppColors.onSurfaceVariant),
                                  ),
                              ]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      SpotifyPlayButton(
                        title: review.title,
                        artist: review.artist,
                        url: review.spotifyUrl,
                        compact: true,
                      ),
                    ],
                  ),
                  Expanded(
                    child: GenrePills(
                      tags: splitGenreTags(review.genres),
                      maxTags: _maxTags,
                      topPadding: AppSpacing.sm,
                      singleLine: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
