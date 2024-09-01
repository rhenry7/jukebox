class Track {
  final String name;
  final String duration;
  final String listeners;
  final String mbid;
  final String url;
  final Streamable streamable;
  final Artist artist;
  final List<Image> images;
  final int rank;

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
    List<Image> images = imageList.map((i) => Image.fromJson(i)).toList();

    return Track(
      name: json['name'],
      duration: json['duration'],
      listeners: json['listeners'],
      mbid: json['mbid'],
      url: json['url'],
      streamable: Streamable.fromJson(json['streamable']),
      artist: Artist.fromJson(json['artist']),
      images: images,
      rank: int.parse(json['@attr']['rank']),
    );
  }
}

class Artist {
  final String name;
  final String mbid;
  final String url;

  Artist({
    required this.name,
    required this.mbid,
    required this.url,
  });

  factory Artist.fromJson(Map<String, dynamic> json) {
    return Artist(
      name: json['name'],
      mbid: json['mbid'],
      url: json['url'],
    );
  }
}

class Streamable {
  final String text;
  final String fulltrack;

  Streamable({
    required this.text,
    required this.fulltrack,
  });

  factory Streamable.fromJson(Map<String, dynamic> json) {
    return Streamable(
      text: json['#text'],
      fulltrack: json['fulltrack'],
    );
  }
}

class Image {
  final String text;
  final String size;

  Image({
    required this.text,
    required this.size,
  });

  factory Image.fromJson(Map<String, dynamic> json) {
    return Image(
      text: json['#text'],
      size: json['size'],
    );
  }
}
