import 'package:flutter/material.dart';

import '../../services/genre_cache_service.dart';
import '../screens/tag/tag_reviews_page.dart';
import '../theme/tokens.dart';

/// Splits "/"-joined genre strings (e.g. "jazz/funk/rap" from Discogs or
/// MusicBrainz) into single tags, deduped case-insensitively.
List<String> splitGenreTags(List<String>? raw) {
  final seen = <String>{};
  final result = <String>[];
  for (final entry in raw ?? const <String>[]) {
    final parts =
        entry.split('/').map((s) => s.trim()).where((s) => s.isNotEmpty);
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
class GenrePills extends StatelessWidget {
  const GenrePills({
    super.key,
    required this.tags,
    this.maxTags = 10,
    this.showOverflowCount = false,
    this.topPadding = AppSpacing.lg,
    this.tappable = true,
  });

  final List<String> tags;
  final int maxTags;
  final bool showOverflowCount;
  final double topPadding;
  final bool tappable;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    final hidden = tags.length - maxTags;
    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final tag in tags.take(maxTags))
            _pill(tag,
                onTap: tappable ? () => openTagPage(context, tag) : null),
          if (showOverflowCount && hidden > 0) _pill('$hidden+'),
        ],
      ),
    );
  }

  static Widget _pill(String tag, {VoidCallback? onTap}) {
    final label = Text(
      tag,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
    );
    final background = Colors.white.withValues(alpha: 0.07);
    final side = BorderSide(color: Colors.white.withValues(alpha: 0.2));
    const padding = EdgeInsets.symmetric(
        horizontal: AppSpacing.sm, vertical: AppSpacing.xxs);
    const shape = RoundedRectangleBorder(borderRadius: AppRadius.pillAll);

    if (onTap == null) {
      return Chip(
        label: label,
        backgroundColor: background,
        side: side,
        padding: padding,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        shape: shape,
      );
    }
    // Its own tap target, so tapping a tag on a card opens the tag rather
    // than the review.
    return ActionChip(
      label: label,
      onPressed: onTap,
      backgroundColor: background,
      side: side,
      padding: padding,
      pressElevation: 0,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      shape: shape,
    );
  }
}

/// [GenrePills] for a track that has no stored genres yet: looks them up
/// through [GenreCacheService] (Firestore cache first, then MusicBrainz) and
/// shows nothing until they arrive.
class TrackGenrePills extends StatefulWidget {
  const TrackGenrePills({super.key, required this.title, required this.artist});

  final String title;
  final String artist;

  @override
  State<TrackGenrePills> createState() => _TrackGenrePillsState();
}

class _TrackGenrePillsState extends State<TrackGenrePills> {
  late Future<List<String>> _genres;

  @override
  void initState() {
    super.initState();
    _genres = _load();
  }

  @override
  void didUpdateWidget(TrackGenrePills oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title || oldWidget.artist != widget.artist) {
      _genres = _load();
    }
  }

  Future<List<String>> _load() async {
    try {
      return splitGenreTags(
        await GenreCacheService.getGenresWithCache(widget.title, widget.artist),
      );
    } catch (e) {
      debugPrint('Error loading genres for ${widget.title}: $e');
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _genres,
      builder: (context, snapshot) =>
          GenrePills(tags: snapshot.data ?? const []),
    );
  }
}
