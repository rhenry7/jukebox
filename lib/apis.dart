import 'package:flutter_test_project/api_key.dart';
import 'package:flutter_test_project/Types/userComments.dart';
import 'package:spotify/spotify.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

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
          '37i9dQZF1DX1gRalH1mWrP') // replace with list from recommendation;
      .all();
  List<String> albumsIds = [];

  for (var track in tracks) {
    albumsIds.add(track.album!.id ?? "");
  }
  // might not need this part
  final sb = StringBuffer();
  sb.writeAll(albumsIds, ",");
  List<String> limitAlbumIds = albumsIds.sublist(0, 11);
  final albums = await getFromSpotify.albums.list(limitAlbumIds);
  return albums.toList();
}

Future<List<UserComment>> fetchMockUserComments() async {
  final url = Uri.parse(
      "https://66d638b1f5859a704268af2d.mockapi.io/test/v1/usercomments");
  final response = await http.get(url);
  if (response.statusCode == 200) {
    // Parse the JSON data
    final List<dynamic> jsonData = json.decode(response.body);
    // Convert the JSON data into a list of UserComment objects
    final res = jsonData.map((json) => UserComment.fromJson(json)).toList();

    return jsonData.map((json) => UserComment.fromJson(json)).toList();
  } else {
    throw Exception('Failed to load user comments');
  }
}
