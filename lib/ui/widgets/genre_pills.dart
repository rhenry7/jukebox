import 'package:flutter/material.dart';

import '../../services/genre_cache_service.dart';
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

/// The genre / tag pills shown on cards. Renders nothing when [tags] is
/// empty, otherwise the gap above plus up to 10 pills, so every card that
/// shows genres looks and spaces them the same way.
class GenrePills extends StatelessWidget {
  const GenrePills({super.key, required this.tags});

  final List<String> tags;

  static const int _maxTags = 10;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: tags.take(_maxTags).map((tag) {
          return Chip(
            label: Text(
              tag,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
            backgroundColor: Colors.white.withValues(alpha: 0.07),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.2),
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
      builder: (context, snapshot) => GenrePills(tags: snapshot.data ?? const []),
    );
  }
}
