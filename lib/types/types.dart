class Tracks {
  final List<Track> trackList;

  Tracks({required this.trackList});

  factory Tracks.fromJson(Map<String, dynamic> json) {
    var trackJsonList = json['tracks']['track'] as List<dynamic>? ?? [];
    List<Track> trackList =
        trackJsonList.map((i) => Track.fromJson(i)).toList();
    return Tracks(trackList: trackList);
  }
}

class Track {
  final String name;
  final int duration;
  final int listeners;
  final String mbid;
  final String url;
  final Streamable streamable;
  final Artist artist;
  final List<ImageData> images;
  final String rank;

  Track({
    required this.name,
    required this.duration,
    required this.listeners,
    required this.mbid,
    required this.url,
    required this.streamable,
    required this.artist,
    required this.images,
    required this.rank,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    var imageList = json['image'] as List;
    List<ImageData> images =
        imageList.map((i) => ImageData.fromJson(i)).toList();

    return Track(
      name: json['name'],
      duration: int.parse(json['duration'].toString()),
      listeners: int.parse(json['listeners'].toString()),
      mbid: json['mbid'] ?? '',
      url: json['url'],
      streamable: Streamable.fromJson(json['streamable']),
      artist: Artist.fromJson(json['artist']),
      images: images,
      rank: json['@attr']?['rank'] ?? '',
    );
  }
}

class Streamable {
  final String text;
  final String fulltrack;

  Streamable({required this.text, required this.fulltrack});

  factory Streamable.fromJson(Map<String, dynamic> json) {
    return Streamable(
      text: json['#text'] ?? '',
      fulltrack: json['fulltrack'] ?? '',
    );
  }
}

class Artist {
  final String name;
  final String mbid;
  final String url;

  Artist({required this.name, required this.mbid, required this.url});

  factory Artist.fromJson(Map<String, dynamic> json) {
    return Artist(
      name: json['name'],
      mbid: json['mbid'] ?? '',
      url: json['url'],
    );
  }
}

class ImageData {
  final String text;
  final String size;

  ImageData({required this.text, required this.size});

  factory ImageData.fromJson(Map<String, dynamic> json) {
    return ImageData(
      text: json['#text'] ?? '',
      size: json['size'] ?? '',
    );
  }
}
