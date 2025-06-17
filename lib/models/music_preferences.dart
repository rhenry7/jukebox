class MusicPreferences {
  final List<String> favoriteGenres;
  final Map<String, double> genreWeights;

  MusicPreferences({
    required this.favoriteGenres,
    required this.genreWeights,
  });

  factory MusicPreferences.fromJson(Map<String, dynamic> json) {
    return MusicPreferences(
      favoriteGenres: List<String>.from(json['favoriteGenres'] ?? []),
      genreWeights: Map<String, double>.from(json['genreWeights'] ?? {}),
    );
  }
}
