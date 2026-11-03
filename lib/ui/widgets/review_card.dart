import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';

import '../../models/review.dart';
import '../../providers/auth_provider.dart' show currentUserIdProvider;
import '../../providers/review_likes_provider.dart';
import '../../providers/friends_provider.dart';
import '../../services/friends_service.dart';
import '../../services/genre_cache_service.dart';
import '../../services/review_likes_service.dart';
import '../../utils/helpers.dart';
import '../../utils/cached_image.dart';
import '../../providers/auth_provider.dart'
    show currentUserProvider, isAnonymousUserProvider;
import '../../providers/repost_provider.dart';
import '../../services/repost_service.dart';
import '../screens/review_detail/review_detail_page.dart';
import '../theme/tokens.dart';
import 'auth_gate_modal.dart';
import 'review_comments.dart';

/// Returns genres for the review, splitting any "/" concatenated strings
/// (e.g. from Discogs/MusicBrainz), deduped by lowercase.
List<String> _allTagsForReview(Review review) {
  final raw = review.genres ?? <String>[];
  final seen = <String>{};
  final result = <String>[];
  for (final entry in raw) {
    // Split on "/" — handles tags stored as "jazz/funk/rap" style strings.
    final parts =
        entry.split('/').map((s) => s.trim()).where((s) => s.isNotEmpty);
    for (final tag in parts) {
      final lower = tag.toLowerCase();
      if (!seen.contains(lower)) {
        seen.add(lower);
        result.add(tag);
      }
    }
  }
  return result;
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
                            itemPadding: const EdgeInsets.only(right: 2.0),
                            ratingWidget: RatingWidget(
                              full: const Icon(Icons.star, color: AppColors.rating),
                              empty: const Icon(Icons.star, color: Colors.grey),
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
            ],
          ),
          // Review text
          if (review.review.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            Text(
              review.review,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15.0,
                height: 1.5,
              ),
              maxLines: null,
              overflow: TextOverflow.visible,
            ),
          ],
          // Genre / tag pills
          ...() {
            final allTags = _allTagsForReview(review);
            if (allTags.isEmpty) return <Widget>[];
            return [
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: allTags.take(10).map((tag) {
                  return Chip(
                    label: Text(
                      tag,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    backgroundColor: Colors.white.withOpacity(0.07),
                    side: BorderSide(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.pillAll,
                    ),
                  );
                }).toList(),
              ),
            ];
          }(),
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
              // Action buttons: like, comment, repost
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
                      Ionicons.chatbubble_outline,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This is your review!'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheetContext) {
        return _UserProfileSheet(
          reviewUserId: review.userId,
          reviewDisplayName: review.displayName,
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
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) return;

    setState(() => _isLoading = true);

    try {
      final service = FriendsService();
      final alreadyFriend = ref.read(isFriendProvider(widget.reviewUserId));

      if (alreadyFriend) {
        await service.removeFriend(
          currentUserId: currentUserId,
          friendId: widget.reviewUserId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Removed ${widget.reviewDisplayName} from friends'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        await service.addFriend(
          currentUserId: currentUserId,
          friendId: widget.reviewUserId,
          friendDisplayName: widget.reviewDisplayName,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added ${widget.reviewDisplayName} as a friend!'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

    return likeCountAsync.when(
      data: (likeCount) {
        final isLiked = isLikedAsync.value ?? false;

        return GestureDetector(
          onTap: userId != null
              ? () async {
                  try {
                    final service = ReviewLikesService();
                    await service.toggleLike(reviewId, userId);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
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
      },
      loading: () => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (error, stack) => const SizedBox.shrink(),
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
                .value ??
            false
        : false;

    final repostCount =
        ref.watch(repostCountProvider(reviewId)).value ?? review.reposts;

    return GestureDetector(
      onTap: () async {
        if (isAnon) {
          showAuthGateModal(context);
          return;
        }
        if (currentUserId == null) return;
        // Prevent reposting your own review
        if (review.userId == currentUserId) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You can\'t repost your own review.'),
              duration: Duration(seconds: 2),
            ),
          );
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e')),
            );
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
                color: isReposted
                    ? const Color(0xFF3FFF8B)
                    : Colors.white70,
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

  /// Splits any "/" concatenated genre strings into individual tags.
  List<String>? _splitGenres(List<String>? raw) {
    if (raw == null) return null;
    final seen = <String>{};
    final result = <String>[];
    for (final entry in raw) {
      for (final tag
          in entry.split('/').map((s) => s.trim()).where((s) => s.isNotEmpty)) {
        final lower = tag.toLowerCase();
        if (seen.add(lower)) result.add(tag);
      }
    }
    return result.isEmpty ? null : result;
  }

  Future<void> _loadGenres() async {
    if (_isLoadingGenres) return;

    setState(() {
      _isLoadingGenres = true;
    });

    try {
      // Use cache service: checks Firestore cache first, then MusicBrainz API
      final genres = await GenreCacheService.getGenresWithCache(
        widget.review.title,
        widget.review.artist,
      );

      if (genres.isNotEmpty && mounted) {
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
    if (widget.review.isRepost &&
        widget.review.repostedByDisplayName != null) {
      return _ReviewCardSurface(
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

    return _ReviewCardSurface(
      imageUrl: widget.review.albumImageUrl,
      child: card,
    );
  }
}

/// The Crate Card surface shared by every review card: tonal fill, 12px
/// corners and a faint ghost border. Screens must not wrap review cards in
/// their own Card — only position them (e.g. with [AppSpacing.cardListItem]).
class _ReviewCardSurface extends StatelessWidget {
  final Widget child;

  /// Album art used as the blurred card background (see [kAlbumArtCardBackground]).
  final String? imageUrl;

  const _ReviewCardSurface({required this.child, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final showArt = kAlbumArtCardBackground && url != null && url.isNotEmpty;
    return Material(
      color: AppColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.cardAll,
        side: BorderSide(color: AppColors.ghostBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: showArt
          ? Stack(
              children: [
                Positioned.fill(child: _AlbumArtBackdrop(imageUrl: url)),
                child,
              ],
            )
          : child,
    );
  }
}

/// Experiment: album art as the card background. Set to false to go back to
/// the flat surface everywhere.
const bool kAlbumArtCardBackground = true;

/// Album art as a card background, in three layers:
///  1. the art with a deep Gaussian blur — carries the album's colours;
///  2. the same art unblurred at ~20% so some texture and style shows through;
///  3. a dark scrim so white text stays readable.
class _AlbumArtBackdrop extends StatelessWidget {
  const _AlbumArtBackdrop({required this.imageUrl});

  final String imageUrl;

  static const double _blurSigma = 48.3;

  /// Opacity of the whole art (blurred + sharp layers).
  static const double _artOpacity = 0.85;
  static const double _sharpOpacity = 0.20;
  static const double _scrimTop = 0.63;
  static const double _scrimMiddle = 0.78;
  static const double _scrimBottom = 0.86;

  Widget _art() => CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        // While loading or on error, the plain card surface shows through.
        placeholder: (_, __) => const SizedBox.shrink(),
        errorWidget: (_, __, ___) => const SizedBox.shrink(),
      );

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: _artOpacity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: _blurSigma,
                    sigmaY: _blurSigma,
                    tileMode: TileMode.clamp,
                  ),
                  // Slight overscale hides the soft edges the blur leaves.
                  child: Transform.scale(scale: 1.25, child: _art()),
                ),
                Opacity(opacity: _sharpOpacity, child: _art()),
              ],
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.surfaceContainerLowest.withValues(alpha: _scrimTop),
                  AppColors.surfaceContainerLowest.withValues(alpha: _scrimMiddle),
                  AppColors.surfaceContainerLowest.withValues(alpha: _scrimBottom),
                ],
              ),
            ),
          ),
        ],
      ),
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
    );
  }
}
