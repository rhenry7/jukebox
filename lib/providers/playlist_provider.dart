import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/models/enhanced_user_preferences.dart';
import 'package:flutter_test_project/providers/preferences_provider.dart';
import 'package:flutter_test_project/services/playlist_generation_service.dart';

/// Provider for generating playlists based on user preferences
final playlistProvider = FutureProvider.family<List<PlaylistTrack>, PlaylistRequest>((ref, request) async {
  final preferencesAsync = ref.watch(userPreferencesProvider);
  
  return preferencesAsync.when(
    data: (preferences) async {
      // If playlistType is specified, use generatePlaylistByType
      if (request.playlistType != null) {
        return await PlaylistGenerationService.generatePlaylistByType(
          preferences: preferences,
          playlistType: request.playlistType!,
          trackCount: request.trackCount,
        );
      }
      // Otherwise use regular generatePlaylist
      return await PlaylistGenerationService.generatePlaylist(
        preferences: preferences,
        context: request.context,
        trackCount: request.trackCount,
      );
    },
    loading: () => [],
    error: (error, stack) => throw error,
  );
});

/// Request model for playlist generation
class PlaylistRequest {
  final String? context; // 'workout', 'study', 'party', etc.
  final int trackCount;
  final String? playlistType; // 'genre', 'artist-network', 'mood', etc.

  PlaylistRequest({
    this.context,
    this.trackCount = 20,
    this.playlistType,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaylistRequest &&
          runtimeType == other.runtimeType &&
          context == other.context &&
          trackCount == other.trackCount &&
          playlistType == other.playlistType;

  @override
  int get hashCode => context.hashCode ^ trackCount.hashCode ^ playlistType.hashCode;
}

/// Provider for playlist by type
final playlistByTypeProvider = FutureProvider.family<List<PlaylistTrack>, Map<String, dynamic>>((ref, params) async {
  final preferencesAsync = ref.watch(userPreferencesProvider);
  
  return preferencesAsync.when(
    data: (preferences) async {
      return await PlaylistGenerationService.generatePlaylistByType(
        preferences: preferences,
        playlistType: params['type'] as String? ?? 'genre',
        trackCount: params['count'] as int? ?? 20,
      );
    },
    loading: () => [],
    error: (error, stack) => throw error,
  );
});
