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
    return MusicRecommendation(
      song: json['song']?.toString() ?? '',
      artist: json['artist']?.toString() ?? '',
      album: json['album']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      genres: (json['genres'] as List<dynamic>?)
              ?.map((g) => g.toString())
              .toList() ??
          [],
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
