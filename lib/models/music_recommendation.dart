class MusicRecommendation {
  final String song;
  final String artist;
  final String album;
  final String imageUrl;
  final List<String> genres;

  const MusicRecommendation({
    required this.song,
    required this.artist,
    required this.album,
    required this.imageUrl,
    required this.genres,
  });

  factory MusicRecommendation.fromJson(Map<String, dynamic> json) {
    // Safely parse genres list
    List<String> genresList = [];
    if (json['genres'] != null) {
      if (json['genres'] is List) {
        final dynamicList = json['genres'] as List;
        for (var item in dynamicList) {
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

    return MusicRecommendation(
      song: json['song']?.toString() ?? '',
      artist: json['artist']?.toString() ?? '',
      album: json['album']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      genres: genresList,
    );
  }

  Map<String, dynamic> toJson() => {
        'song': song,
        'artist': artist,
        'album': album,
        'imageUrl': imageUrl,
        'genres': genres,
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
