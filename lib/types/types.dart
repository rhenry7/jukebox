class Track {
  final String name;
  final int duration;
  final int listeners;
  final String artistName;
  final String url;
  final String imageUrl;

  Track({
    required this.name,
    required this.duration,
    required this.listeners,
    required this.artistName,
    required this.url,
    required this.imageUrl,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {
        'name': String name,
        'duration': int duration,
        'listeners': int listeners,
        'artistName': String artistName,
        'url': String url,
        'imageUrl': String imageUrl
      } =>
        Track(
            name: name,
            duration: duration,
            listeners: listeners,
            artistName: artistName,
            url: url,
            imageUrl: imageUrl),
      _ => throw const FormatException("dumb"),
    };
  }
}

class Album {
  final String name;
  final int duration;
  final String artist;
  final String url;
  final String imageUrl;

  Album({
    required this.name,
    required this.duration,
    required this.artist,
    required this.url,
    required this.imageUrl,
  });
}
