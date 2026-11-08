import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/tag_suggestion_service.dart';
import '../ui/widgets/genre_pills.dart' show rankTags;
import 'cache_first.dart';
import 'community_reviews_provider.dart';
import 'reviews_provider.dart' show ReviewWithDocId, firestoreProvider;

/// How long the review form waits for MusicBrainz before saying no
/// suggested tags were found.
const Duration suggestionTimeout = Duration(seconds: 30);

/// A song picked in the review form.
typedef SuggestionTrack = ({String title, String artist});

/// Tags to suggest in the review form for a song: other reviewers' tags for
/// it first (from the Popular reviews already loaded), then MusicBrainz's
/// ([TagSuggestionService]). Kept for a few minutes, so reopening the form
/// for the same song is instant.
final tagSuggestionsProvider = FutureProvider.autoDispose
    .family<List<String>, SuggestionTrack>((ref, track) async {
      ref.keepAliveFor();
      final pool = ref.exists(communityReviewsProvider)
          ? ref.read(communityReviewsProvider).valueOrNull ??
                const <ReviewWithDocId>[]
          : const <ReviewWithDocId>[];
      // Give up on MusicBrainz after [suggestionTimeout], so the form can
      // say none were found. The lookup carries on in the background and
      // still caches what it finds for next time.
      final musicBrainz = await TagSuggestionService.forTrack(
        track.title,
        track.artist,
        db: ref.read(firestoreProvider),
      ).timeout(suggestionTimeout, onTimeout: () => const <String>[]);
      return mergeSuggestions([
        communityTagsFor(track, [for (final r in pool) r]),
        musicBrainz,
      ], limit: TagSuggestionService.keep);
    });

/// The tags other reviewers gave [track], most used first.
List<String> communityTagsFor(
  SuggestionTrack track,
  List<ReviewWithDocId> reviews,
) {
  String norm(String s) => s.trim().toLowerCase();
  String firstArtist(String s) => norm(s.split(',').first);
  final title = norm(track.title), artist = firstArtist(track.artist);
  return rankTags([
    for (final r in reviews)
      if (norm(r.review.title) == title &&
          firstArtist(r.review.artist) == artist)
        r.review.genres,
  ]);
}
