class SongRecommended {
  final String artist;
  final String song;

  SongRecommended({required this.artist, required this.song});

  factory SongRecommended.fromJson(Map<String, dynamic> json) {
    return SongRecommended(
      artist: json['artist']?.toString() ?? '',
      song: json['song']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'artist': artist,
      'song': song,
    };
  }
}
