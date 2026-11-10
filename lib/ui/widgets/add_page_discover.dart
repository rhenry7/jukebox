import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/add_page_discover_provider.dart';
import '../../providers/friends_provider.dart' show isFriendProvider;
import '../../utils/cached_image.dart';
import '../screens/Profile/profilePage.dart';
import '../theme/tokens.dart';
import 'friend_toggle.dart';
import 'skeleton_loader.dart';
import 'spotify_play_button.dart';

/// What the Add page shows before anything is searched: songs the community
/// rates highly (tap one to review it) and reviewers to follow. Built from
/// the Popular reviews already loaded, so it costs no extra reads.
class AddPageDiscover extends ConsumerStatefulWidget {
  const AddPageDiscover({super.key, required this.onPickTrack});

  /// Starts a review of the picked song.
  final void Function(DiscoverTrack track) onPickTrack;

  @override
  ConsumerState<AddPageDiscover> createState() => _AddPageDiscoverState();
}

class _AddPageDiscoverState extends ConsumerState<AddPageDiscover> {
  static const int _pageSize = 5;
  static const int _maxShown = 15;
  int _shown = _pageSize;

  @override
  Widget build(BuildContext context) {
    final tracks = ref.watch(addPageTopRatedProvider);
    final reviewers = ref.watch(addPageSuggestedReviewersProvider);
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.dockClearance),
      children: [
        const _SectionTitle('Highly rated'),
        if (tracks == null)
          for (var i = 0; i < 3; i++) const _TrackRowSkeleton()
        else if (tracks.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text(
              'Nothing rated highly yet.',
              style: TextStyle(color: AppColors.onSurfaceVariant),
            ),
          )
        else ...[
          for (final t in tracks.take(_shown))
            _TrackRow(track: t, onTap: () => widget.onPickTrack(t)),
          if (_shown < tracks.length && _shown < _maxShown)
            _ShowMore(onTap: () => setState(() => _shown += _pageSize)),
        ],
        if (reviewers == null || reviewers.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          const _SectionTitle('Suggested reviewers'),
          SizedBox(
            height: _ReviewerCard.height,
            child: reviewers == null
                ? const SkeletonLoader(
                    width: double.infinity,
                    height: _ReviewerCard.height,
                    borderRadius: AppRadius.cardAll,
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: reviewers.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (context, i) => _ReviewerCard(
                      key: ValueKey(reviewers[i].userId),
                      reviewer: reviewers[i],
                    ),
                  ),
          ),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Text(
      text,
      style: const TextStyle(
        color: AppColors.onSurfaceVariant,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

/// One highly rated song: art, title, artist, average stars, Spotify.
class _TrackRow extends StatelessWidget {
  const _TrackRow({required this.track, required this.onTap});

  final DiscoverTrack track;
  final VoidCallback onTap;

  static const double _art = 56;

  @override
  Widget build(BuildContext context) {
    final count = track.reviewCount;
    return Semantics(
      button: true,
      label: 'Review ${track.title} by ${track.artist}',
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: AppRadius.smAll,
                child: AppCachedImage(
                  imageUrl: track.imageUrl,
                  width: _art,
                  height: _art,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        RatingBar(
                          initialRating: track.averageScore,
                          minRating: 0,
                          maxRating: 5,
                          allowHalfRating: true,
                          itemSize: 13,
                          itemPadding: const EdgeInsets.only(right: 1),
                          ignoreGestures: true,
                          onRatingUpdate: (_) {},
                          ratingWidget: RatingWidget(
                            full: const Icon(
                              Icons.star,
                              color: AppColors.rating,
                            ),
                            half: const Icon(
                              Icons.star_half,
                              color: AppColors.rating,
                            ),
                            empty: const Icon(Icons.star, color: Colors.grey),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '$count ${count == 1 ? 'review' : 'reviews'}',
                          style: const TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SpotifyPlayButton(
                title: track.title,
                artist: track.artist,
                url: track.spotifyUrl,
                compact: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackRowSkeleton extends StatelessWidget {
  const _TrackRowSkeleton();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: SkeletonLoader(
      width: double.infinity,
      height: 56,
      borderRadius: AppRadius.smAll,
    ),
  );
}

class _ShowMore extends StatelessWidget {
  const _ShowMore({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      onPressed: onTap,
      iconAlignment: IconAlignment.end,
      icon: const Icon(Icons.expand_more, color: AppColors.onSurface),
      label: const Text(
        'Show more',
        style: TextStyle(
          color: AppColors.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: TextButton.styleFrom(padding: EdgeInsets.zero),
    ),
  );
}

/// A reviewer to follow: avatar, name, why, Follow, and ✕ to hide.
class _ReviewerCard extends ConsumerWidget {
  const _ReviewerCard({super.key, required this.reviewer});

  final SuggestedReviewer reviewer;

  static const double width = 160;
  static const double height = 228;
  static const double _avatar = 76;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final following = ref.watch(isFriendProvider(reviewer.userId));
    final why = reviewer.sharedArtist != null
        ? 'Also into ${reviewer.sharedArtist}'
        : '${reviewer.reviewCount} ${reviewer.reviewCount == 1 ? 'review' : 'reviews'}';
    return SizedBox(
      width: width,
      child: Material(
        color: AppColors.surfaceContainerHigh,
        borderRadius: AppRadius.cardAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProfilePage(
                userId: reviewer.userId,
                displayName: reviewer.displayName,
              ),
            ),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: Column(
                  children: [
                    _Avatar(
                      name: reviewer.displayName,
                      imageUrl: reviewer.imageUrl,
                      size: _avatar,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      reviewer.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      why,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 36,
                      child: FilledButton(
                        onPressed: () {
                          final kept = ref.read(
                            followedFromSuggestionsProvider,
                          );
                          ref
                              .read(followedFromSuggestionsProvider.notifier)
                              .state = {
                            ...kept,
                            reviewer.userId,
                          };
                          toggleFriend(
                            context,
                            ref,
                            friendId: reviewer.userId,
                            friendName: reviewer.displayName,
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: following
                              ? AppColors.pill
                              : Colors.white,
                          foregroundColor: following
                              ? AppColors.onSurface
                              : Colors.black,
                          shape: const StadiumBorder(),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: Text(following ? 'Following' : 'Follow'),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  tooltip: 'Hide',
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: AppColors.onSurfaceVariant,
                  ),
                  onPressed: () {
                    final hidden = ref.read(dismissedSuggestionsProvider);
                    ref.read(dismissedSuggestionsProvider.notifier).state = {
                      ...hidden,
                      reviewer.userId,
                    };
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.name,
    required this.imageUrl,
    required this.size,
  });

  final String name;
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: url != null && url.isNotEmpty
            ? AppCachedImage(imageUrl: url, width: size, height: size)
            : ColoredBox(
                color: AppColors.surfaceContainerHighest,
                child: Center(
                  child: Text(
                    name.isEmpty ? '?' : name[0].toUpperCase(),
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: size * 0.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
