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
      padding: const EdgeInsets.all(20.0),
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
                      borderRadius: BorderRadius.circular(8),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 100,
                        height: 100,
                        color: Colors.white10,
                        child: const Icon(Icons.music_note,
                            size: 48, color: Colors.white38),
                      ),
                    ),
              const SizedBox(width: 16),
              // Artist, Title, Rating + Timestamp
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.artist,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      review.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
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
                              full: const Icon(Icons.star, color: Colors.amber),
                              empty: const Icon(Icons.star, color: Colors.grey),
                              half: const Icon(Icons.star_half,
                                  color: Colors.amber),
                            ),
                            ignoreGestures: true,
                            onRatingUpdate: (rating) {},
                          ),
                        ),
                        if (review.date != null) const SizedBox(width: 8),
                        if (review.date != null)
                          Text(
                            formatRelativeTime(review.date),
                            style: const TextStyle(
                              color: Colors.white54,
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
            const SizedBox(height: 20),
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
              const SizedBox(height: 16),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  );
                }).toList(),
              ),
            ];
          }(),
          const SizedBox(height: 20),
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
                        const SizedBox(width: 10),
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
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () {}, // comment placeholder
                    child: const Icon(
                      Ionicons.chatbubble_outline,
                      color: Colors.white70,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () {}, // repost placeholder
                    child: const Icon(
                      Ionicons.repeat,
                      color: Colors.white70,
                      size: 26,
                    ),
                  ),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
    // Use genres from state if available, otherwise use review's genres
    final genres = _genres ?? widget.review.genres;

    return ReviewCardWidget(
      review: widget.review.copyWith(genres: genres),
      reviewId: widget.reviewId,
      showLikeButton: widget.showLikeButton,
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
    );
  }
}
