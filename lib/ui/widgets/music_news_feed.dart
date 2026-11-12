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

/// "Best New Music": the newest album reviews from Pitchfork, Stereogum, NME
/// and Billboard, shown on the Search page until the user types.
///
/// Built for browsing: compact rows (cover, album, artist, the critic's
/// take), the sites taking turns in "All", and the source pills pinned while
/// scrolling. Tapping a row opens a sheet with the summary and what to do
/// next: review it in REVERB, play it on Spotify, or read the full review.
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
        final source = ref.watch(musicNewsSourceProvider);
        final shown = filterMusicNews(items, source);
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
                child: _SourcePills(
                  selected: source,
                  available: {for (final i in items) i.source},
                  onSelected: (s) =>
                      ref.read(musicNewsSourceProvider.notifier).state = s,
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
                    item: shown[index],
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

/// All · Pitchfork · Stereogum · NME · Billboard, for sources with reviews.
class _SourcePills extends StatelessWidget {
  const _SourcePills({
    required this.selected,
    required this.available,
    required this.onSelected,
  });

  final String? selected;
  final Set<String> available;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final sources = [
      for (final e in musicNewsSources.entries)
        if (available.contains(e.key)) e,
    ];
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageGutter),
      children: [
        // Centered: the row is taller than a pill, which would stretch.
        Center(
          child: TagPill(
            label: 'All',
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
        ),
        for (final e in sources) ...[
          const SizedBox(width: AppSpacing.sm),
          Center(
            child: TagPill(
              label: e.value,
              selected: selected == e.key,
              onTap: () => onSelected(selected == e.key ? null : e.key),
            ),
          ),
        ],
      ],
    );
  }
}

/// One review as a compact row: cover; album (or the headline when the
/// site's title couldn't be split), artist, the critic's take; site and age;
/// Spotify. Same glass card as the compact review cards.
class MusicNewsRow extends StatefulWidget {
  const MusicNewsRow({super.key, required this.item, required this.onTap});

  final MusicNewsItem item;
  final VoidCallback onTap;

  @override
  State<MusicNewsRow> createState() => _MusicNewsRowState();
}

class _MusicNewsRowState extends State<MusicNewsRow> {
  bool _pressed = false;

  static const double _artSize = 72;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Semantics(
      button: true,
      label: [
        item.heading,
        if (item.byArtist.isNotEmpty) item.byArtist,
        item.sourceName,
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
                        _SourceLine(item: item),
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

/// "NME · ALBUM REVIEW · 10h", tracked out like an archive label.
class _SourceLine extends StatelessWidget {
  const _SourceLine({required this.item});

  final MusicNewsItem item;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.9,
      height: 1.2,
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: item.sourceName.toUpperCase(),
            style: style.copyWith(color: AppColors.onSurface),
          ),
          TextSpan(
            text:
                '  ·  ${item.label.toUpperCase()}  ·  '
                '${formatRelativeTime(item.publishedAt)}',
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

/// The review in a glass sheet: cover, album and artist, the critic's take
/// and summary, then Review it (in REVERB), Spotify and the full review.
Future<void> showMusicNewsSheet(BuildContext context, MusicNewsItem item) {
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
      child: _MusicNewsSheet(item: item),
    ),
  );
}

class _MusicNewsSheet extends ConsumerWidget {
  const _MusicNewsSheet({required this.item});

  final MusicNewsItem item;

  Future<void> _read() async {
    final uri = Uri.tryParse(item.url);
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
    final byline = [
      if (item.author.isNotEmpty) 'By ${item.author}',
      formatRelativeTime(item.publishedAt),
    ].join(' · ');
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
                      _SourceLine(item: item),
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
            if (item.verdict.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                '“${item.verdict}”',
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
            if (item.summary.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                item.summary,
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(
              byline,
              style: const TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (item.lookup != null) ...[
              _NewsSpotifyButton(item: item),
              const SizedBox(height: AppSpacing.sm),
            ],
            Row(
              children: [
                if (item.lookup != null) ...[
                  Expanded(
                    child: _SheetButton(
                      label: 'Review it',
                      icon: Ionicons.add,
                      primary: true,
                      onTap: () => _review(context, ref),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: _SheetButton(
                    label: 'Read on ${item.sourceName}',
                    icon: Ionicons.openOutline,
                    onTap: _read,
                  ),
                ),
              ],
            ),
          ],
        ),
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
