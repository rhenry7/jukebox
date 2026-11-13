import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/GIFs/gifs.dart';
import 'package:flutter_test_project/providers/auth_provider.dart';
import 'package:flutter_test_project/providers/music_news_provider.dart';
import 'package:flutter_test_project/providers/search_reviews_provider.dart';
import 'package:flutter_test_project/providers/tag_reviews_provider.dart'
    show normalizeTag;
import 'package:flutter_test_project/providers/unified_search_provider.dart';
import 'package:flutter_test_project/ui/screens/addReview/reviewSheetContentForm.dart';
import 'package:flutter_test_project/ui/screens/tag/tag_reviews_page.dart'
    show openTagPage;
import 'package:flutter_test_project/ui/theme/tokens.dart';
import 'package:flutter_test_project/ui/widgets/app_states.dart';
import 'package:flutter_test_project/ui/widgets/auth_gate_modal.dart';
import 'package:flutter_test_project/ui/widgets/card_surface.dart';
import 'package:flutter_test_project/ui/widgets/genre_pills.dart';
import 'package:flutter_test_project/ui/widgets/music_news_feed.dart';
import 'package:flutter_test_project/ui/widgets/review_card.dart';
import 'package:flutter_test_project/utils/cached_image.dart';
import 'package:ionicons/ionicons.dart';

/// Everything on REVERB matching a search, not just reviews: the best match
/// (an artist or a tag), tags, reviews, songs and albums to review (Spotify)
/// and Best New Music articles. Scope pills narrow it to one kind.
///
/// Each part shows as soon as its data arrives, so a slow Spotify search
/// never holds up the reviews. When REVERB has few reviews, songs to review
/// come first ("Be the first to review"), so a search never dead-ends.
class UnifiedSearchResults extends ConsumerWidget {
  const UnifiedSearchResults({super.key, required this.query});

  final String query;

  /// How many reviews make Reviews the first section (else Music is).
  static const int reviewsFirstAt = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(searchReviewsProvider(query));
    final musicAsync = ref.watch(musicSearchProvider(query));
    final pool = ref.watch(searchPoolProvider).valueOrNull ?? const [];
    final news = ref.watch(musicNewsProvider).valueOrNull ?? const [];

    final reviews = reviewsAsync.valueOrNull ?? const [];
    final music = musicAsync.valueOrNull ?? const <MusicResult>[];
    final tags = matchTags(pool, query);
    final artist = matchArtist(pool, query);
    final articles = matchArticles(groupNewsAlbums(news), query);

    if (reviewsAsync.isLoading && musicAsync.isLoading) {
      return const Center(
        child: SizedBox(height: 200, child: DiscoBallLoading()),
      );
    }

    // The best single match: a tag used on several reviews when the query
    // is that tag ("phonk"), else the artist it names ("billie").
    final topTag =
        tags.isNotEmpty &&
            normalizeTag(tags.first.tag) == normalizeTag(query) &&
            tags.first.count >= 2
        ? tags.first
        : null;
    final topArtist = topTag == null ? artist : null;

    final available = [
      SearchScope.all,
      if (reviews.isNotEmpty) SearchScope.reviews,
      if (music.isNotEmpty) SearchScope.music,
      if (articles.isNotEmpty) SearchScope.articles,
      if (tags.isNotEmpty) SearchScope.tags,
    ];
    final picked = ref.watch(searchScopeProvider);
    final scope = available.contains(picked) ? picked : SearchScope.all;
    void setScope(SearchScope s) =>
        ref.read(searchScopeProvider.notifier).state = s;

    final stillLoading = reviewsAsync.isLoading || musicAsync.isLoading;
    if (available.length == 1 && !stillLoading) {
      return AppEmptyState(
        icon: Ionicons.searchOutline,
        title: 'Nothing found for "$query"',
        message: 'Try an artist, song, album or tag',
      );
    }

    final bottom = AppSpacing.lg + MediaQuery.paddingOf(context).bottom;
    final children = switch (scope) {
      SearchScope.all => _all(
        context,
        ref,
        reviews: reviews,
        music: music,
        musicLoading: musicAsync.isLoading,
        articles: articles,
        tags: tags,
        topTag: topTag,
        topArtist: topArtist,
        setScope: setScope,
      ),
      SearchScope.reviews => [
        for (final r in reviews)
          Padding(
            padding: AppSpacing.cardListItem,
            child: ReviewCardWithGenres(
              review: r.review,
              reviewId: r.fullReviewId,
              showLikeButton: true,
            ),
          ),
      ],
      SearchScope.music => [for (final m in music) _MusicRow(result: m)],
      SearchScope.articles => [
        for (final a in articles)
          Padding(
            padding: AppSpacing.cardListItem,
            child: MusicNewsRow(
              album: a,
              onTap: () => showMusicNewsSheet(context, a),
            ),
          ),
      ],
      SearchScope.tags => [_TagWrap(tags: tags)],
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScopePills(scopes: available, selected: scope, onSelected: setScope),
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.only(top: AppSpacing.xs, bottom: bottom),
            children: children,
          ),
        ),
      ],
    );
  }

  List<Widget> _all(
    BuildContext context,
    WidgetRef ref, {
    required List reviews,
    required List<MusicResult> music,
    required bool musicLoading,
    required List<NewsAlbum> articles,
    required List<TagMatch> tags,
    required TagMatch? topTag,
    required ArtistMatch? topArtist,
    required ValueChanged<SearchScope> setScope,
  }) {
    final reviewsSection = reviews.isEmpty
        ? const <Widget>[]
        : [
            _SectionHeader(
              title: 'Reviews',
              count: reviews.length,
              onSeeAll: () => setScope(SearchScope.reviews),
            ),
            SizedBox(
              height: CompactReviewCard.height,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.cardGap,
                ),
                itemCount: reviews.length.clamp(0, 6),
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.cardGap),
                itemBuilder: (_, i) => CompactReviewCard(
                  review: reviews[i].review,
                  reviewId: reviews[i].fullReviewId,
                ),
              ),
            ),
          ];
    final musicSection = [
      if (music.isNotEmpty || musicLoading)
        _SectionHeader(
          // No reviews yet: invite the first one.
          title: reviews.isEmpty
              ? 'Be the first to review'
              : 'Songs & albums to review',
          count: music.length,
          onSeeAll: music.isEmpty ? null : () => setScope(SearchScope.music),
        ),
      if (music.isEmpty && musicLoading)
        const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.pageGutter,
            vertical: AppSpacing.sm,
          ),
          child: AppLoadingText('Finding songs'),
        ),
      for (final m in music.take(4)) _MusicRow(result: m),
    ];
    final reviewsFirst = reviews.length >= reviewsFirstAt;
    return [
      if (topTag != null)
        _TopTagCard(match: topTag)
      else if (topArtist != null)
        _TopArtistCard(
          match: topArtist,
          onSeeReviews: () => setScope(SearchScope.reviews),
        ),
      if (tags.isNotEmpty) ...[
        _SectionHeader(
          title: 'Tags',
          onSeeAll: tags.length > 6 ? () => setScope(SearchScope.tags) : null,
        ),
        _TagWrap(tags: tags.take(6).toList()),
      ],
      if (reviewsFirst) ...[
        ...reviewsSection,
        ...musicSection,
      ] else ...[
        ...musicSection,
        ...reviewsSection,
      ],
      if (articles.isNotEmpty) ...[
        _SectionHeader(
          title: 'Articles',
          count: articles.length,
          onSeeAll: () => setScope(SearchScope.articles),
        ),
        for (final a in articles.take(2))
          Padding(
            padding: AppSpacing.cardListItem,
            child: MusicNewsRow(
              album: a,
              onTap: () => showMusicNewsSheet(context, a),
            ),
          ),
      ],
    ];
  }
}

/// All · Reviews · Music · Articles · Tags, for the kinds with results.
class _ScopePills extends StatelessWidget {
  const _ScopePills({
    required this.scopes,
    required this.selected,
    required this.onSelected,
  });

  final List<SearchScope> scopes;
  final SearchScope selected;
  final ValueChanged<SearchScope> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageGutter),
        itemCount: scopes.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) => Center(
          child: TagPill(
            label: scopes[i].label,
            selected: scopes[i] == selected,
            onTap: () => onSelected(scopes[i]),
          ),
        ),
      ),
    );
  }
}

/// "REVIEWS · 12            See all ›", tracked out like the app's labels.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.count, this.onSeeAll});

  final String title;
  final int? count;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final c = count;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageGutter,
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              [title.toUpperCase(), if (c != null && c > 0) '$c'].join('  ·  '),
              style: const TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.onSurface,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text(
                'See all ›',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

/// Opens the Add page on [result], already picked (with its Spotify link).
/// Signed-out and preview users get the sign-up prompt instead.
void _reviewMusic(BuildContext context, WidgetRef ref, MusicResult result) {
  if (!_canReview(context, ref)) return;
  final image = result.imageUrl ?? '';
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => _AddPage(
        form: image.isEmpty
            // No art to show the picked song with: search for it instead.
            ? MyReviewSheetContentForm(
                title: '',
                artist: '',
                albumImageUrl: '',
                initialQuery: '${result.title} ${result.artist}',
                initialFilter: result.isAlbum ? 'album' : 'song',
              )
            : MyReviewSheetContentForm(
                title: result.title,
                artist: result.artist,
                albumImageUrl: image,
                spotifyUrl: result.spotifyUrl,
              ),
      ),
    ),
  );
}

bool _canReview(BuildContext context, WidgetRef ref) {
  if (ref.read(currentUserIdProvider) == null ||
      ref.read(isAnonymousUserProvider)) {
    showAuthGateModal(context);
    return false;
  }
  return true;
}

class _AddPage extends StatelessWidget {
  const _AddPage({required this.form});

  final Widget form;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(child: form),
  );
}

/// A song or album to review: art, title, "Song · Artist", and a green
/// "+ Review" pill. Tapping anywhere starts the review.
class _MusicRow extends ConsumerWidget {
  const _MusicRow({required this.result});

  final MusicResult result;

  static const double _artSize = 56;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = result.imageUrl;
    return Padding(
      padding: AppSpacing.cardListItem,
      child: Semantics(
        button: true,
        label: 'Review ${result.title} by ${result.artist}',
        child: CardSurface(
          imageUrl: image,
          child: InkWell(
            onTap: () => _reviewMusic(context, ref, result),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: AppRadius.smAll,
                    child: image != null && image.isNotEmpty
                        ? AppCachedImage(
                            imageUrl: image,
                            width: _artSize,
                            height: _artSize,
                          )
                        : Container(
                            width: _artSize,
                            height: _artSize,
                            color: AppColors.surfaceContainerHighest,
                            child: const Icon(
                              Icons.music_note,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          '${result.isAlbum ? 'Album' : 'Song'} · '
                          '${result.artist}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const _ReviewPill(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The small green "+ Review" label on music rows (the row is the button).
class _ReviewPill extends StatelessWidget {
  const _ReviewPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: const BoxDecoration(
        color: AppColors.secondary,
        borderRadius: AppRadius.pillAll,
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Ionicons.add, size: 14, color: Colors.black),
          SizedBox(width: AppSpacing.xxs),
          Text(
            'Review',
            style: TextStyle(
              color: Colors.black,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tags as pills; each opens its tag page.
class _TagWrap extends StatelessWidget {
  const _TagWrap({required this.tags});

  final List<TagMatch> tags;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageGutter,
        vertical: AppSpacing.xs,
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final t in tags)
            TagPill(label: t.tag, onTap: () => openTagPage(context, t.tag)),
        ],
      ),
    );
  }
}

/// The best match, on a large glass card: kicker, name, a line of facts,
/// and up to two actions.
class _TopCard extends StatelessWidget {
  const _TopCard({
    required this.kicker,
    required this.name,
    required this.facts,
    required this.art,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.imageUrl,
  });

  final String kicker;
  final String name;
  final String facts;
  final Widget art;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.cardListItem,
      child: CardSurface(
        imageUrl: imageUrl,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  art,
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kicker,
                          style: const TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.onSurface,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          facts,
                          style: const TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              // The buttons share the width, so long labels never overflow.
              Row(
                children: [
                  Expanded(
                    child: _CardButton(
                      label: primaryLabel,
                      primary: true,
                      onTap: onPrimary,
                    ),
                  ),
                  if (secondaryLabel != null && onSecondary != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _CardButton(
                        label: secondaryLabel!,
                        onTap: onSecondary!,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardButton extends StatelessWidget {
  const _CardButton({
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? AppColors.secondary : Colors.transparent,
      shape: StadiumBorder(
        side: primary
            ? BorderSide.none
            : const BorderSide(color: AppColors.ghostBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm + 2,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: primary ? Colors.black : AppColors.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _TopArtistCard extends ConsumerWidget {
  const _TopArtistCard({required this.match, required this.onSeeReviews});

  final ArtistMatch match;
  final VoidCallback onSeeReviews;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = match.imageUrl;
    final rating = match.averageScore > 0
        ? '★ ${match.averageScore.toStringAsFixed(1)} · '
        : '';
    return _TopCard(
      kicker: 'ARTIST',
      name: match.name,
      facts:
          '$rating${match.reviewCount} review${match.reviewCount == 1 ? '' : 's'} on REVERB',
      imageUrl: image,
      art: ClipOval(
        child: image != null
            ? AppCachedImage(imageUrl: image, width: 72, height: 72)
            : Container(
                width: 72,
                height: 72,
                color: AppColors.surfaceContainerHighest,
                child: const Icon(
                  Ionicons.personOutline,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
      ),
      primaryLabel: 'Review a song',
      onPrimary: () {
        if (!_canReview(context, ref)) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _AddPage(
              form: MyReviewSheetContentForm(
                title: '',
                artist: '',
                albumImageUrl: '',
                initialQuery: match.name,
                initialFilter: 'song',
              ),
            ),
          ),
        );
      },
      secondaryLabel: 'See reviews',
      onSecondary: onSeeReviews,
    );
  }
}

class _TopTagCard extends StatelessWidget {
  const _TopTagCard({required this.match});

  final TagMatch match;

  @override
  Widget build(BuildContext context) {
    return _TopCard(
      kicker: 'TAG',
      name: '#${match.tag}',
      facts:
          '${match.count} review${match.count == 1 ? '' : 's'} on REVERB, '
          'plus similar tags',
      art: Container(
        width: 72,
        height: 72,
        decoration: const BoxDecoration(
          color: AppColors.pill,
          borderRadius: AppRadius.mdAll,
        ),
        alignment: Alignment.center,
        child: const Text(
          '#',
          style: TextStyle(
            color: AppColors.onSurface,
            fontSize: 32,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      primaryLabel: 'Open tag page',
      onPrimary: () => openTagPage(context, match.tag),
    );
  }
}
