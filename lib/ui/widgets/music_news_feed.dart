import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/GIFs/gifs.dart';
import 'package:flutter_test_project/providers/auth_provider.dart';
import 'package:flutter_test_project/providers/music_news_provider.dart';
import 'package:flutter_test_project/services/spotify_link_service.dart';
import 'package:flutter_test_project/ui/screens/addReview/reviewSheetContentForm.dart';
import 'package:flutter_test_project/ui/theme/tokens.dart';
import 'package:flutter_test_project/ui/widgets/auth_gate_modal.dart';
import 'package:flutter_test_project/ui/widgets/card_surface.dart';
import 'package:flutter_test_project/ui/widgets/genre_pills.dart';
import 'package:flutter_test_project/ui/widgets/glass.dart';
import 'package:flutter_test_project/ui/widgets/spotify_play_button.dart';
import 'package:flutter_test_project/utils/cached_image.dart';
import 'package:flutter_test_project/utils/helpers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ionicons/ionicons.dart';
import 'package:url_launcher/url_launcher.dart';

/// "Best New Music": the newest album reviews from Pitchfork, Stereogum, NME,
/// Billboard, The Guardian and The Quietus, shown on the Search page until
/// the user types.
///
/// Built for browsing: one compact row per album (several sites' reviews of
/// the same album merge, "critics agree"), the sites taking turns in "All",
/// and a pinned filter row by why to look (For you, Critics agree, This week)
/// and by genre, with the sites themselves in a picker at its end. Tapping a
/// row opens a sheet with each site's take and what to do next: review it in
/// REVERB, play it on Spotify, or read the full review.
class MusicNewsFeed extends ConsumerWidget {
  const MusicNewsFeed({super.key, this.emptyPrompt});

  /// Shown instead when there's no news to show (before the first fetch, or
  /// if it fails to load), so the page still says what Search does.
  final Widget? emptyPrompt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsAsync = ref.watch(musicNewsProvider);
    return newsAsync.when(
      loading: () =>
          const Center(child: SizedBox(height: 200, child: DiscoBallLoading())),
      // The news is extra: if it can't load, Search just shows its prompt
      // (never a raw error).
      error: (e, _) {
        debugPrint('Music news unavailable: $e');
        return emptyPrompt ?? const SizedBox.shrink();
      },
      data: (items) {
        if (items.isEmpty) return emptyPrompt ?? const SizedBox.shrink();
        final hidden = ref.watch(musicNewsHiddenSourcesProvider);
        final albums = groupNewsAlbums([
          for (final i in items)
            if (!hidden.contains(i.source)) i,
        ]);
        // "For you" needs the user's reviews; until they load (or for
        // someone signed out) it just isn't offered.
        final taste =
            ref.watch(newsTasteProvider).valueOrNull ?? NewsTaste.empty;
        final filters = newsFilters(albums, taste);
        final picked = ref.watch(musicNewsFilterProvider);
        final filter = filters.contains(picked) ? picked : NewsFilter.all;
        final shown = applyNewsFilter(albums, filter, taste);
        final bottomInset = MediaQuery.paddingOf(context).bottom;
        return CustomScrollView(
          // Dragging the list puts the keyboard away.
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            const SliverToBoxAdapter(child: _Header()),
            // The pills stay under the search bar while the list scrolls.
            SliverPersistentHeader(
              pinned: true,
              delegate: _PinnedPills(
                child: _FilterRow(
                  filters: filters,
                  selected: filter,
                  onSelected: (f) =>
                      ref.read(musicNewsFilterProvider.notifier).state = f,
                  sources: {for (final i in items) i.source},
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.only(
                top: AppSpacing.xs,
                bottom: AppSpacing.lg + bottomInset,
              ),
              sliver: SliverList.builder(
                itemCount: shown.length,
                itemBuilder: (context, index) => Padding(
                  padding: AppSpacing.cardListItem,
                  child: MusicNewsRow(
                    album: shown[index],
                    onTap: () => showMusicNewsSheet(context, shown[index]),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageGutter,
        AppSpacing.sm,
        AppSpacing.pageGutter,
        AppSpacing.xs,
      ),
      child: Text(
        'Best New Music',
        style: GoogleFonts.spaceGrotesk(
          color: AppColors.onSurface,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}

class _PinnedPills extends SliverPersistentHeaderDelegate {
  const _PinnedPills({required this.child});

  final Widget child;

  static const double _height = 52;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      ColoredBox(color: Colors.black, child: child);

  @override
  bool shouldRebuild(_PinnedPills oldDelegate) => oldDelegate.child != child;
}

/// All · For you · Critics agree · This week · genres…, then the site
/// picker. One pill at a time; tapping the picked one goes back to All.
class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.filters,
    required this.selected,
    required this.onSelected,
    required this.sources,
  });

  final List<NewsFilter> filters;
  final NewsFilter selected;
  final ValueChanged<NewsFilter> onSelected;

  /// The sites with reviews, for the picker.
  final Set<String> sources;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: AppSpacing.pageGutter),
            itemCount: filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
            // Centered: the row is taller than a pill, which would stretch.
            itemBuilder: (_, i) => Center(
              child: TagPill(
                label: filters[i].label,
                selected: filters[i] == selected,
                onTap: () => onSelected(
                  filters[i] == selected ? NewsFilter.all : filters[i],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.pageGutter),
          child: _SitesButton(sources: sources),
        ),
      ],
    );
  }
}

/// The grey tile at the end of the row (like Home's sort button) that opens
/// the site picker; a dot shows when a site is switched off.
class _SitesButton extends ConsumerWidget {
  const _SitesButton({required this.sources});

  final Set<String> sources;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(musicNewsHiddenSourcesProvider).isNotEmpty;
    return Tooltip(
      message: 'Choose sites',
      child: Material(
        color: AppColors.pill,
        borderRadius: AppRadius.cardAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: AppRadius.cardAll,
          onTap: () => _open(context),
          child: SizedBox(
            width: 44,
            height: 36,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.tune, size: 18, color: Colors.white),
                if (active)
                  const Positioned(
                    top: 5,
                    right: 8,
                    child: CircleAvatar(
                      radius: 3,
                      backgroundColor: AppColors.primary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A glass menu right under the button, aligned to its right edge.
  void _open(BuildContext context) {
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final button = context.findRenderObject()! as RenderBox;
    final rect =
        button.localToGlobal(Offset.zero, ancestor: overlay) & button.size;
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close site picker',
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (_, __, ___) => Stack(
        children: [
          Positioned(
            top: rect.bottom + AppSpacing.sm,
            right: overlay.size.width - rect.right,
            child: _SitesMenu(sources: sources),
          ),
        ],
      ),
      transitionBuilder: (_, animation, __, child) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          alignment: Alignment.topRight,
          scale: Tween(begin: 0.95, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Every site with a check; tapping one switches it on or off (at least one
/// stays on). Stays open so several can be changed at once.
class _SitesMenu extends ConsumerWidget {
  const _SitesMenu({required this.sources});

  final Set<String> sources;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(musicNewsHiddenSourcesProvider);
    final sites = [
      for (final e in musicNewsSources.entries)
        if (sources.contains(e.key)) e,
    ];
    final shownCount = sites.where((e) => !hidden.contains(e.key)).length;
    return SizedBox(
      width: 230,
      child: GlassSurface(
        borderRadius: AppRadius.cardAll,
        shadow: true,
        child: Material(
          type: MaterialType.transparency,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.xs,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: Text(
                    'SITES',
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                for (final e in sites)
                  InkWell(
                    onTap: () {
                      final on = !hidden.contains(e.key);
                      // Keep at least one site on.
                      if (on && shownCount <= 1) return;
                      ref
                          .read(musicNewsHiddenSourcesProvider.notifier)
                          .state = on
                          ? {...hidden, e.key}
                          : ({...hidden}..remove(e.key));
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              e.value,
                              style: const TextStyle(
                                color: AppColors.onSurface,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Icon(
                            hidden.contains(e.key)
                                ? Icons.check_box_outline_blank
                                : Icons.check_box,
                            size: 20,
                            color: hidden.contains(e.key)
                                ? AppColors.onSurfaceVariant
                                : AppColors.onSurface,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One album as a compact row: cover; album, artist, the critic's take; the
/// sites that reviewed it and when; Spotify. Same glass card as the compact
/// review cards.
class MusicNewsRow extends StatefulWidget {
  const MusicNewsRow({super.key, required this.album, required this.onTap});

  final NewsAlbum album;
  final VoidCallback onTap;

  @override
  State<MusicNewsRow> createState() => _MusicNewsRowState();
}

class _MusicNewsRowState extends State<MusicNewsRow> {
  bool _pressed = false;

  static const double _artSize = 72;

  @override
  Widget build(BuildContext context) {
    final item = widget.album.primary;
    return Semantics(
      button: true,
      label: [
        item.heading,
        if (item.byArtist.isNotEmpty) item.byArtist,
        ...widget.album.sourceNames,
      ].join(', '),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        // A slight press-in instead of a ripple (design system).
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1,
          duration: const Duration(milliseconds: 120),
          child: CardSurface(
            imageUrl: item.imageUrl,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  _NewsArt(item: item, size: _artSize),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // The same four lines on every row, so the eye
                        // finds album, artist, take and source in the same
                        // places while scanning.
                        Text(
                          item.heading,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                        Text(
                          item.byArtist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        // Empty still takes its line, keeping rows even.
                        Text(
                          item.hook,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.onSurface,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        _SourceLine(album: widget.album),
                      ],
                    ),
                  ),
                  if (item.lookup != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    _NewsSpotifyButton(item: item, compact: true),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "NME · ALBUM REVIEW · 10h", tracked out like an archive label; for an
/// album several sites reviewed, "NME + THE GUARDIAN · 10h" in green.
class _SourceLine extends StatelessWidget {
  const _SourceLine({required this.album});

  final NewsAlbum album;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.9,
      height: 1.2,
    );
    final item = album.primary;
    final age = formatRelativeTime(album.latest);
    return Text.rich(
      TextSpan(
        children: album.criticsAgree
            ? [
                TextSpan(
                  text: album.sourceNames.join(' + ').toUpperCase(),
                  style: style.copyWith(color: AppColors.secondary),
                ),
                TextSpan(
                  text: '  ·  $age',
                  style: style.copyWith(color: AppColors.onSurfaceVariant),
                ),
              ]
            : [
                TextSpan(
                  text: item.sourceName.toUpperCase(),
                  style: style.copyWith(color: AppColors.onSurface),
                ),
                TextSpan(
                  text: '  ·  ${item.label.toUpperCase()}  ·  $age',
                  style: style.copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _NewsArt extends StatelessWidget {
  const _NewsArt({required this.item, required this.size});

  final MusicNewsItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    final image = item.imageUrl;
    return ClipRRect(
      borderRadius: AppRadius.smAll,
      child: image != null
          ? AppCachedImage(imageUrl: image, width: size, height: size)
          : Container(
              width: size,
              height: size,
              color: AppColors.surfaceContainerHighest,
              child: const Icon(
                Ionicons.newspaperOutline,
                color: AppColors.onSurfaceVariant,
              ),
            ),
    );
  }
}

/// Spotify for the record ([MusicNewsItem.lookup]): a search link, so a
/// list of rows doesn't look each one up on Spotify. Only built when the
/// item has a lookup.
class _NewsSpotifyButton extends StatelessWidget {
  const _NewsSpotifyButton({required this.item, this.compact = false});

  final MusicNewsItem item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final lookup = item.lookup!;
    return SpotifyPlayButton(
      title: lookup.title,
      artist: lookup.artist,
      url: SpotifyLinkService.searchUrl(lookup.title, lookup.artist).toString(),
      compact: compact,
    );
  }
}

/// The album in a glass sheet: cover, album and artist, each site's take
/// and summary (with its own Read link), then Spotify and Review it.
Future<void> showMusicNewsSheet(BuildContext context, NewsAlbum album) {
  const radius = BorderRadius.vertical(top: Radius.circular(AppRadius.xl));
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: Colors.black26,
    shape: const RoundedRectangleBorder(borderRadius: radius),
    builder: (_) => GlassSurface(
      borderRadius: radius,
      child: _MusicNewsSheet(album: album),
    ),
  );
}

class _MusicNewsSheet extends ConsumerWidget {
  const _MusicNewsSheet({required this.album});

  final NewsAlbum album;

  MusicNewsItem get item => album.primary;

  static Future<void> _read(MusicNewsItem review) async {
    final uri = Uri.tryParse(review.url);
    if (uri == null || uri.scheme != 'https') return;
    // In an in-app browser where the platform has one, so closing it comes
    // back here.
    await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
  }

  void _review(BuildContext context, WidgetRef ref) {
    if (ref.read(currentUserIdProvider) == null ||
        ref.read(isAnonymousUserProvider)) {
      showAuthGateModal(context);
      return;
    }
    final navigator = Navigator.of(context);
    navigator.pop();
    // The Add page, already searching albums for it: the user picks the
    // album on Spotify, so the review gets its real art and link.
    navigator.push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: MyReviewSheetContentForm(
              title: '',
              artist: '',
              albumImageUrl: '',
              initialQuery: '${item.lookup!.title} ${item.lookup!.artist}'
                  .trim(),
              initialFilter: 'album',
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  borderRadius: AppRadius.pillAll,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NewsArt(item: item, size: 104),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SourceLine(album: album),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        item.heading,
                        style: const TextStyle(
                          color: AppColors.onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      if (item.byArtist.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          item.byArtist,
                          style: const TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            // Each site's take: one for most albums, several when critics
            // agree.
            for (final review in album.reviews)
              _SiteTake(
                review: review,
                showSource: album.criticsAgree,
                onRead: () => _read(review),
              ),
            const SizedBox(height: AppSpacing.xl),
            if (item.lookup != null) ...[
              _NewsSpotifyButton(item: item),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (item.lookup != null)
              _SheetButton(
                label: 'Review it',
                icon: Ionicons.add,
                primary: true,
                onTap: () => _review(context, ref),
              ),
          ],
        ),
      ),
    );
  }
}

/// One site's review in the sheet: (when several sites reviewed it) which
/// site, then the critic's quote, the summary, byline and a Read link.
class _SiteTake extends StatelessWidget {
  const _SiteTake({
    required this.review,
    required this.showSource,
    required this.onRead,
  });

  final MusicNewsItem review;
  final bool showSource;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) {
    final byline = [
      if (review.author.isNotEmpty) 'By ${review.author}',
      formatRelativeTime(review.publishedAt),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showSource) ...[
            Text(
              '${review.sourceName}  ·  ${review.label}'.toUpperCase(),
              style: const TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (review.verdict.isNotEmpty) ...[
            Text(
              '“${review.verdict}”',
              style: const TextStyle(
                color: AppColors.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (review.summary.isNotEmpty) ...[
            Text(
              review.summary,
              style: const TextStyle(
                color: AppColors.onSurface,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  byline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onRead,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.onSurface,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Ionicons.openOutline, size: 16),
                label: Text(
                  'Read on ${review.sourceName}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A pill button for the sheet: the primary one solid green (the design
/// system's secondary, for positive actions) with black text, the other a
/// ghost pill (faint edge).
class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    // Black on the bright green, white on the ghost pill.
    final foreground = primary ? Colors.black : AppColors.onSurface;
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
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
