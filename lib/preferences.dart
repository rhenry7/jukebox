// User preference model
import 'package:spotify/spotify.dart';

class UserPreferences {
  final List<String> favoriteGenres;
  final List<String> favoriteArtists;
  final List<String> dislikedGenres;
  final Map<String, double> genreWeights; // 0.0 to 1.0 preference strength
  final List<String> recentlyPlayed;
  final List<String> savedTracks;

  UserPreferences({
    required this.favoriteGenres,
    required this.favoriteArtists,
    this.dislikedGenres = const [],
    this.genreWeights = const {},
    this.recentlyPlayed = const [],
    this.savedTracks = const [],
  });
}

// Playlist recommendation model
class PlaylistRecommendation {
  final String name;
  final String description;
  final List<String> searchQueries;
  final List<String> genres;
  final double relevanceScore;

  PlaylistRecommendation({
    required this.name,
    required this.description,
    required this.searchQueries,
    required this.genres,
    required this.relevanceScore,
  });
}

class PersonalizedPlaylistService {
  final String clientId;
  final String clientSecret;

  PersonalizedPlaylistService(this.clientId, this.clientSecret);

  // Main function to fetch personalized playlists
  Future<List<Playlist>> fetchPersonalizedPlaylists(
      UserPreferences preferences) async {
    try {
      final credentials = SpotifyApiCredentials(clientId, clientSecret);
      final spotify = SpotifyApi(credentials);

      // Generate playlist recommendations based on user preferences
      List<PlaylistRecommendation> recommendations =
          _generatePlaylistRecommendations(preferences);

      // Sort by relevance score
      recommendations
          .sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

      List<Playlist> personalizedPlaylists = [];

      // Search for playlists based on recommendations
      for (var recommendation in recommendations.take(15)) {
        try {
          for (String query in recommendation.searchQueries) {
            final searchResults = await spotify.search.get(query, types: [
              SearchType.playlist
            ]).first(3); // Get 3 playlists per query

            if (searchResults.isNotEmpty) {
              for (var page in searchResults) {
                if (page.items != null) {
                  for (var playlistSimple in page.items!) {
                    if (playlistSimple is PlaylistSimple) {
                      // Convert to full Playlist if needed
                      final playlist =
                          await spotify.playlists.get(playlistSimple.id!);
                      if (playlist != null &&
                          playlist.tracks?.total != null &&
                          playlist.tracks!.total! > 10) {
                        // Filter out small playlists
                        personalizedPlaylists.add(playlist);
                      }
                    }
                  }
                }
              }
            }

            await Future.delayed(const Duration(milliseconds: 150));
          }
        } catch (e) {
          print(
              'Error searching for recommendation "${recommendation.name}": $e');
          continue;
        }
      }

      // Remove duplicates and apply final filtering
      Map<String, Playlist> uniquePlaylists = {};
      for (var playlist in personalizedPlaylists) {
        if (playlist.id != null && _isPlaylistRelevant(playlist, preferences)) {
          uniquePlaylists[playlist.id!] = playlist;
        }
      }

      List<Playlist> finalPlaylists = uniquePlaylists.values.toList();

      // Sort by follower count and relevance
      finalPlaylists.sort((a, b) {
        int followersA = a.followers?.total ?? 0;
        int followersB = b.followers?.total ?? 0;
        return followersB.compareTo(followersA);
      });

      return finalPlaylists.take(25).toList();
    } catch (e) {
      print('Error fetching personalized playlists: $e');
      return [];
    }
  }

  // Generate playlist recommendations based on user preferences
  List<PlaylistRecommendation> _generatePlaylistRecommendations(
      UserPreferences preferences) {
    List<PlaylistRecommendation> recommendations = [];

    // Single genre playlists
    for (String genre in preferences.favoriteGenres) {
      double weight = preferences.genreWeights[genre] ?? 0.7;

      recommendations.addAll([
        PlaylistRecommendation(
          name: "Best of $genre",
          description: "Top $genre tracks",
          searchQueries: ["$genre hits", "best $genre", "$genre classics"],
          genres: [genre],
          relevanceScore: weight * 0.9,
        ),
        PlaylistRecommendation(
          name: "Modern $genre",
          description: "Contemporary $genre music",
          searchQueries: ["$genre 2024", "$genre new", "modern $genre"],
          genres: [genre],
          relevanceScore: weight * 0.8,
        ),
      ]);
    }

    // Genre combinations
    if (preferences.favoriteGenres.length >= 2) {
      for (int i = 0; i < preferences.favoriteGenres.length; i++) {
        for (int j = i + 1; j < preferences.favoriteGenres.length; j++) {
          String genre1 = preferences.favoriteGenres[i];
          String genre2 = preferences.favoriteGenres[j];
          double weight1 = preferences.genreWeights[genre1] ?? 0.7;
          double weight2 = preferences.genreWeights[genre2] ?? 0.7;

          recommendations.add(PlaylistRecommendation(
            name: "$genre1 meets $genre2",
            description: "Fusion of $genre1 and $genre2",
            searchQueries: [
              "$genre1 $genre2",
              "$genre1 $genre2 fusion",
              "$genre1 $genre2 mix"
            ],
            genres: [genre1, genre2],
            relevanceScore: (weight1 + weight2) / 2 * 0.85,
          ));
        }
      }
    }

    // Decade-based recommendations
    List<String> decades = ['80s', '90s', '2000s', '2010s'];
    for (String genre in preferences.favoriteGenres) {
      for (String decade in decades) {
        double weight = preferences.genreWeights[genre] ?? 0.7;
        recommendations.add(PlaylistRecommendation(
          name: "$decade $genre",
          description: "$genre music from the $decade",
          searchQueries: ["$decade $genre", "$genre $decade hits"],
          genres: [genre],
          relevanceScore: weight * 0.75,
        ));
      }
    }

    // Mood-based playlists
    List<String> moods = ['chill', 'workout', 'focus', 'party', 'relaxing'];
    for (String genre in preferences.favoriteGenres) {
      for (String mood in moods) {
        double weight = preferences.genreWeights[genre] ?? 0.7;
        recommendations.add(PlaylistRecommendation(
          name: "$mood $genre",
          description: "$genre music for ${mood}ing",
          searchQueries: ["$mood $genre", "$genre $mood"],
          genres: [genre],
          relevanceScore: weight * 0.7,
        ));
      }
    }

    // Artist-based recommendations
    for (String artist in preferences.favoriteArtists.take(5)) {
      recommendations.addAll([
        PlaylistRecommendation(
          name: "Artists like $artist",
          description: "Similar artists to $artist",
          searchQueries: ["$artist similar", "like $artist", "$artist radio"],
          genres: [],
          relevanceScore: 0.8,
        ),
        PlaylistRecommendation(
          name: "$artist essentials",
          description: "Essential $artist tracks",
          searchQueries: ["$artist best", "$artist hits", "$artist essential"],
          genres: [],
          relevanceScore: 0.85,
        ),
      ]);
    }

    return recommendations;
  }

  // Check if playlist is relevant to user preferences
  bool _isPlaylistRelevant(Playlist playlist, UserPreferences preferences) {
    String playlistName = playlist.name?.toLowerCase() ?? '';
    String playlistDescription = playlist.description?.toLowerCase() ?? '';
    String combinedText = '$playlistName $playlistDescription';

    // Check if playlist contains disliked genres
    for (String dislikedGenre in preferences.dislikedGenres) {
      if (combinedText.contains(dislikedGenre.toLowerCase())) {
        return false;
      }
    }

    // Check if playlist contains preferred genres or artists
    bool hasPreferredContent = false;

    for (String genre in preferences.favoriteGenres) {
      if (combinedText.contains(genre.toLowerCase())) {
        hasPreferredContent = true;
        break;
      }
    }

    if (!hasPreferredContent) {
      for (String artist in preferences.favoriteArtists) {
        if (combinedText.contains(artist.toLowerCase())) {
          hasPreferredContent = true;
          break;
        }
      }
    }

    return hasPreferredContent;
  }

  // Function to update user preferences based on interaction history
  Future<UserPreferences> updatePreferencesFromHistory(
    UserPreferences currentPreferences,
    List<String> likedPlaylistIds,
    List<String> dislikedPlaylistIds,
  ) async {
    try {
      final credentials = SpotifyApiCredentials(clientId, clientSecret);
      final spotify = SpotifyApi(credentials);

      Map<String, double> updatedWeights =
          Map.from(currentPreferences.genreWeights);
      List<String> newFavoriteGenres =
          List.from(currentPreferences.favoriteGenres);
      List<String> newDislikedGenres =
          List.from(currentPreferences.dislikedGenres);

      // Analyze liked playlists to boost genre preferences
      for (String playlistId in likedPlaylistIds) {
        try {
          final playlist = await spotify.playlists.get(playlistId);
          if (playlist != null) {
            String playlistText =
                '${playlist.name} ${playlist.description}'.toLowerCase();

            // Simple genre detection (you might want to use Spotify's audio features API for better analysis)
            for (String genre in _getAllGenres()) {
              if (playlistText.contains(genre.toLowerCase())) {
                updatedWeights[genre] = (updatedWeights[genre] ?? 0.5) + 0.1;
                if (updatedWeights[genre]! > 1.0) updatedWeights[genre] = 1.0;

                if (!newFavoriteGenres.contains(genre) &&
                    updatedWeights[genre]! > 0.7) {
                  newFavoriteGenres.add(genre);
                }
              }
            }
          }
        } catch (e) {
          print('Error analyzing liked playlist $playlistId: $e');
        }
      }

      return UserPreferences(
        favoriteGenres: newFavoriteGenres,
        favoriteArtists: currentPreferences.favoriteArtists,
        dislikedGenres: newDislikedGenres,
        genreWeights: updatedWeights,
        recentlyPlayed: currentPreferences.recentlyPlayed,
        savedTracks: currentPreferences.savedTracks,
      );
    } catch (e) {
      print('Error updating preferences: $e');
      return currentPreferences;
    }
  }

  // Helper function to get all possible genres
  List<String> _getAllGenres() {
    return [
      'rock',
      'pop',
      'hip-hop',
      'rap',
      'jazz',
      'classical',
      'electronic',
      'edm',
      'country',
      'folk',
      'blues',
      'reggae',
      'punk',
      'metal',
      'alternative',
      'indie',
      'r&b',
      'soul',
      'funk',
      'disco',
      'house',
      'techno',
      'trance',
      'dubstep',
      'ambient',
      'experimental',
      'world',
      'latin',
      'acoustic',
      'singer-songwriter',
      'new-age',
      'gospel',
      'ska',
      'grunge',
      'hardcore'
    ];
  }
}
