import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test_project/MusicPreferences/MusicTaste.dart';

class EnhancedUserPreferences {
  final List<String> favoriteGenres; // write helper function to add top three
  final List<String>
      favoriteArtists; // write helper function to collect top artists based on most liked in saved tracks
  final List<String> dislikedGenres; // make helper function
  final Map<String, double> genreWeights; // 0.0 to 1.0 preference strength
  final List<TrackHistory> recentlyPlayed; // delete later
  final List<String> savedTracks; // delete later
  final List<String> dislikedTracks; // delete later

  // New fields for enhanced recommendations
  final Map<String, double>
      audioFeatureProfile; // danceability, energy, valence, etc.
  final Map<String, double>
      moodPreferences; // chill, energetic, focus, party, etc.
  final Map<String, double> tempoPreferences; // slow, medium, fast
  final Map<String, List<String>>
      contextualPreferences; // workout, study, sleep, etc.
  final DateTime lastUpdated;
  final int totalListeningTime; // in minutes
  final Map<String, int> skipCounts; // track skip frequency
  final Map<String, int> repeatCounts; // track repeat frequency

  EnhancedUserPreferences({
    required this.favoriteGenres,
    required this.favoriteArtists,
    this.dislikedGenres = const [],
    this.genreWeights = const {},
    this.recentlyPlayed = const [],
    this.savedTracks = const [],
    this.dislikedTracks = const [],
    this.audioFeatureProfile = const {},
    this.moodPreferences = const {},
    this.tempoPreferences = const {},
    this.contextualPreferences = const {},
    DateTime? lastUpdated,
    this.totalListeningTime = 0,
    this.skipCounts = const {},
    this.repeatCounts = const {},
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  EnhancedUserPreferences copyWith({
    List<String>? favoriteGenres,
    List<String>? favoriteArtists,
    List<String>? dislikedGenres,
    Map<String, double>? genreWeights,
    List<TrackHistory>? recentlyPlayed,
    List<String>? savedTracks,
    List<String>? dislikedTracks,
    Map<String, double>? audioFeatureProfile,
    Map<String, double>? moodPreferences,
    Map<String, double>? tempoPreferences,
    Map<String, List<String>>? contextualPreferences,
    DateTime? lastUpdated,
    int? totalListeningTime,
    Map<String, int>? skipCounts,
    Map<String, int>? repeatCounts,
  }) {
    return EnhancedUserPreferences(
      favoriteGenres: favoriteGenres ?? this.favoriteGenres,
      favoriteArtists: favoriteArtists ?? this.favoriteArtists,
      dislikedGenres: dislikedGenres ?? this.dislikedGenres,
      genreWeights: genreWeights ?? this.genreWeights,
      recentlyPlayed: recentlyPlayed ?? this.recentlyPlayed,
      savedTracks: savedTracks ?? this.savedTracks,
      dislikedTracks: dislikedTracks ?? this.dislikedTracks,
      audioFeatureProfile: audioFeatureProfile ?? this.audioFeatureProfile,
      moodPreferences: moodPreferences ?? this.moodPreferences,
      tempoPreferences: tempoPreferences ?? this.tempoPreferences,
      contextualPreferences:
          contextualPreferences ?? this.contextualPreferences,
      lastUpdated: lastUpdated ?? DateTime.now(),
      totalListeningTime: totalListeningTime ?? this.totalListeningTime,
      skipCounts: skipCounts ?? this.skipCounts,
      repeatCounts: repeatCounts ?? this.repeatCounts,
    );
  }

  @override
  String toString() {
    return 'EnhancedUserPreferences(favoriteGenres: $favoriteGenres, favoriteArtists: $favoriteArtists, dislikedGenres: $dislikedGenres, genreWeights: $genreWeights, recentlyPlayed: $recentlyPlayed, savedTracksOrAlbum: $savedTracks, audioFeatureProfile: $audioFeatureProfile, moodPreferences: $moodPreferences, tempoPreferences: $tempoPreferences, contextualPreferences: $contextualPreferences, lastUpdated: $lastUpdated, totalListeningTime: $totalListeningTime, skipCounts: $skipCounts, repeatCounts: $repeatCounts)';
  }

  Map<String, dynamic> toJson() {
    return {
      'favoriteGenres': favoriteGenres,
      'favoriteArtists': favoriteArtists,
      'dislikedGenres': dislikedGenres,
      'genreWeights': genreWeights,
      'recentlyPlayed': recentlyPlayed.map((track) => track.toJson()).toList(),
      'savedTracksOrAlbum': savedTracks,
      'dislikedTracks': dislikedTracks,
      'audioFeatureProfile': audioFeatureProfile,
      'moodPreferences': moodPreferences,
      'tempoPreferences': tempoPreferences,
      'contextualPreferences': contextualPreferences,
      'lastUpdated': lastUpdated.toIso8601String(),
      'totalListeningTime': totalListeningTime,
      'skipCounts': skipCounts,
      'repeatCounts': repeatCounts,
    };
  }

  static EnhancedUserPreferences fromJson(Map<String, dynamic> json) {
    return EnhancedUserPreferences(
      favoriteGenres: List<String>.from(json['favoriteGenres'] ?? []),
      favoriteArtists: List<String>.from(json['favoriteArtists'] ?? []),
      dislikedGenres: List<String>.from(json['dislikedGenres'] ?? []),
      genreWeights: Map<String, double>.from(json['genreWeights'] ?? {}),
      recentlyPlayed: (json['recentlyPlayed'] as List<dynamic>?)
              ?.map((track) => TrackHistory.fromJson(track))
              .toList() ??
          [],
      savedTracks: List<String>.from(json['savedTracks'] ?? []),
      dislikedTracks: List<String>.from(json['dislikedTracks'] ?? []),
      audioFeatureProfile:
          Map<String, double>.from(json['audioFeatureProfile'] ?? {}),
      moodPreferences: Map<String, double>.from(json['moodPreferences'] ?? {}),
      tempoPreferences:
          Map<String, double>.from(json['tempoPreferences'] ?? {}),
      contextualPreferences:
          Map<String, List<String>>.from(json['contextualPreferences'] ?? {}),
      lastUpdated: json['lastUpdated'] is Timestamp
          ? (json['lastUpdated'] as Timestamp).toDate()
          : DateTime.parse(json['lastUpdated'] as String),
      totalListeningTime: json['totalListeningTime'] ?? 0,
      skipCounts: Map<String, int>.from(json['skipCounts'] ?? {}),
      repeatCounts: Map<String, int>.from(json['repeatCounts'] ?? {}),
    );
  }
}
