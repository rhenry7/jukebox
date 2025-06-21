class SongRecommended {
  final String artist;
  final String song;

  SongRecommended({required this.artist, required this.song, e});

  // Factory method to create a UserComment from JSON
  factory SongRecommended.fromJson(Map<String, dynamic> json) {
    return SongRecommended(
      artist: json['artist'],
      song: json['song'],
    );
  }

  // Method to convert UserComment to JSON
  Map<String, dynamic> toJson() {
    return {
      'artist': artist,
      'song': song,
    };
  }
}
