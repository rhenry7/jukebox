
import 'package:flutter/material.dart';

import '../screens/tag/tag_reviews_page.dart';
import '../theme/tokens.dart';
import 'glass.dart';

/// Splits "/"-joined genre strings (e.g. "jazz/funk/rap" from Discogs or
/// MusicBrainz) into single tags, deduped case-insensitively.
List<String> splitGenreTags(List<String>? raw) {
  final seen = <String>{};
  final result = <String>[];
  for (final entry in raw ?? const <String>[]) {
    final parts = entry
        .split('/')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);
    for (final tag in parts) {
      if (seen.add(tag.toLowerCase())) result.add(tag);
    }
  }
  return result;
}

/// [tags] from many reviews, most used first (ties keep first-seen order).
/// Tags are compared ignoring case; the first spelling seen is kept.
List<String> rankTags(Iterable<List<String>?> tagLists) {
  final counts = <String, int>{};
  final spelling = <String, String>{};
  for (final tags in tagLists) {
    for (final tag in splitGenreTags(tags)) {
      final key = tag.toLowerCase();
      spelling.putIfAbsent(key, () => tag);
      counts[key] = (counts[key] ?? 0) + 1;
    }
  }
  final keys = counts.keys.toList();
  final order = {for (var i = 0; i < keys.length; i++) keys[i]: i};
  keys.sort((a, b) {
    final byCount = counts[b]!.compareTo(counts[a]!);
    return byCount != 0 ? byCount : order[a]!.compareTo(order[b]!);
  });
  return [for (final k in keys) spelling[k]!];
}

/// The genre / tag pills shown on cards. Renders nothing when [tags] is
/// empty, otherwise the gap above plus up to [maxTags] pills, so every card
/// that shows genres looks and spaces them the same way. With
/// [showOverflowCount], a last "N+" pill says how many were left out.
/// Tapping a tag opens its page ([TagReviewsPage]) unless [tappable] is off.
/// With [singleLine], only the pills that fit on the first line show (whole,
/// never cut off), for fixed-height cards; give it a bounded height.
class GenrePills extends StatelessWidget {
  const GenrePills({
    super.key,
    required this.tags,
    this.maxTags = 10,
    this.showOverflowCount = false,
    this.topPadding = AppSpacing.lg,
    this.tappable = true,
    this.singleLine = false,
  });

  final List<String> tags;
  final int maxTags;
  final bool showOverflowCount;
  final double topPadding;
  final bool tappable;
  final bool singleLine;

  /// Pushes any second line far enough down to be clipped away entirely.
  static const double _hiddenRunSpacing = 1000;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    final hidden = tags.length - maxTags;
    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: singleLine ? _hiddenRunSpacing : AppSpacing.sm,
        clipBehavior: singleLine ? Clip.hardEdge : Clip.none,
        children: [
          for (final tag in tags.take(maxTags))
            _pill(
              tag,
              onTap: tappable ? () => openTagPage(context, tag) : null,
            ),
          if (showOverflowCount && hidden > 0) _pill('$hidden+'),
        ],
      ),
    );
  }

  static Widget _pill(String tag, {VoidCallback? onTap}) =>
      GlassPill(label: tag, onTap: onTap);
}

/// A frosted-glass pill: whatever is behind it (a card's album art, the page)
/// blurred, under a light tint and a faint light edge. Used for tags
/// everywhere ([GenrePills], the Home tag row). [selected] makes it solid
/// white with dark text, for a picked filter.
///
/// The blur is BackdropFilter.grouped, so all pills on screen share one
/// capture of the background (the BackdropGroup in main.dart) instead of one
/// each, which keeps dozens of pills affordable on phones.
class GlassPill extends StatelessWidget {
  const GlassPill({
    super.key,
    required this.label,
    this.onTap,
    this.selected = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool selected;

  static final _selectedFill = Colors.white.withValues(alpha: 0.92);

  @override
  Widget build(BuildContext context) {
    // A plain pill rather than Material's Chip: Chip paints its own opaque
    // background from the theme, which hid the glass.
    Widget chip = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 1,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.black : Colors.white,
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
    if (onTap != null) {
      // Its own tap target, so tapping a tag on a card opens the tag rather
      // than the review.
      chip = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: chip,
        ),
      );
    }

    return Semantics(
      button: onTap != null,
      selected: selected,
      child: selected
          // A picked filter is solid white, not glass.
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: _selectedFill,
                borderRadius: AppRadius.pillAll,
              ),
              child: chip,
            )
          : GlassSurface(
              level: GlassLevel.pill,
              borderRadius: AppRadius.pillAll,
              grouped: true,
              child: chip,
            ),
    );
  }
}
