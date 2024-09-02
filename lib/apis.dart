import 'package:flutter_test_project/api_key.dart';
import 'package:spotify/spotify.dart';

Future<List<Track>> fetchSpotifyTracks() async {
  final credentials = SpotifyApiCredentials(clientId, clientSecret);
  final getFromSpotify = SpotifyApi(credentials);
  final tracks = await getFromSpotify.playlists
      .getTracksByPlaylistId('37i9dQZEVXbLRQDuF5jeBp')
      .all();
  return tracks.toList();
}

Future<List<Album>> fetchSpotifyAlbums() async {
  final credentials = SpotifyApiCredentials(clientId, clientSecret);
  final getFromSpotify = SpotifyApi(credentials);
  final tracks = await getFromSpotify.playlists
      .getTracksByPlaylistId(
          '37i9dQZEVXbLRQDuF5jeBp') // replace with list from recommendation;
      .all();
  List<String> albumsIds = [];

  for (var track in tracks) {
    albumsIds.add(track.album!.id ?? "");
  }
  // might not need this part
  final sb = StringBuffer();
  sb.writeAll(albumsIds, ",");
  print(albumsIds);
  List<String> limitAlbumIds = albumsIds.sublist(0, 11);
  final albums = await getFromSpotify.albums.list(limitAlbumIds);
  print(albums.toList());
  return albums.toList();
}
