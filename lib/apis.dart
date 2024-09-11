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

Future<Pages<Category>> fetchSpotifyCatgories() async {
  final credentials = SpotifyApiCredentials(clientId, clientSecret);
  final getFromSpotify = SpotifyApi(credentials);
  final category = await getFromSpotify.categories.list();
  print(category.first(10).toString());
  return category;
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
  List<String> limitAlbumIds = albumsIds.sublist(0, 15);
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

Future<List<dynamic>> fetchAlbumsFromTag(String tag) async {
  final url = Uri.parse(
      'https://musicbrainz.org/ws/2/release/?query=tag:${tag} AND primarytype:album&fmt=json');

  final response = await http.get(url, headers: {
    'User-Agent': 'jukeboxd/1.0 (ramoneh94@gmail.com)',
  });

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    // Extract the releases (albums) from the response
    return data['releases'];
  } else {
    throw Exception('Failed to load rap albums');
  }
}

// Future<dynamic> fetchFromSearch() async {
//   final credentials = SpotifyApiCredentials(clientId, clientSecret);
//   final getFromSpotify = SpotifyApi(credentials);
//   final search = getFromSpotify.search(Artist());
// }
