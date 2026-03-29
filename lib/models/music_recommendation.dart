class MusicRecommendation {
  final String song;
  final String artist;
  final String album;
  final String imageUrl;
  final List<String> genres;
  /// Discogs styles (more specific than genres, e.g. "Post-Bop", "Boom Bap").
  /// Falls back to genres when empty.
  final List<String> styles;
  /// Short explanation of why this track was recommended.
  final String reason;

  const MusicRecommendation({
    required this.song,
    required this.artist,
    required this.album,
    required this.imageUrl,
    required this.genres,
    this.styles = const [],
    this.reason = '',
  });

  /// What to show in the UI — styles when available, genres as fallback.
  List<String> get displayTags => styles.isNotEmpty ? styles : genres;

  factory MusicRecommendation.fromJson(Map<String, dynamic> json) {
    // Safely parse genres list
    List<String> genresList = [];
    if (json['genres'] != null) {
      if (json['genres'] is List) {
        final dynamicList = json['genres'] as List;
        for (final item in dynamicList) {
          final genreStr = item.toString();
          if (genreStr.isNotEmpty) {
            genresList.add(genreStr);
          }
        }
      } else if (json['genres'] is String) {
        // Handle case where genres might be a single string
        genresList = [json['genres'] as String];
      }
    }

    List<String> stylesList = [];
    if (json['styles'] is List) {
      stylesList = (json['styles'] as List)
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return MusicRecommendation(
      song: json['song']?.toString() ?? '',
      artist: json['artist']?.toString() ?? '',
      album: json['album']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      genres: genresList,
      styles: stylesList,
      reason: json['reason']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'song': song,
        'artist': artist,
        'album': album,
        'imageUrl': imageUrl,
        'genres': genres,
        'styles': styles,
        'reason': reason,
      };

  bool get isValid => song.isNotEmpty && artist.isNotEmpty;

  @override
  String toString() => '$song - $artist';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MusicRecommendation &&
          song == other.song &&
          artist == other.artist;

  @override
  int get hashCode => song.hashCode ^ artist.hashCode;
}
