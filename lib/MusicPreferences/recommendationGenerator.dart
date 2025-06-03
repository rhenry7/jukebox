import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test_project/api_key.dart';
import 'package:flutter_test_project/MusicPreferences/tokenManager.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

// Album Model
class Album {
  final String name;
  final String artist;
  final String imageUrl;
  final String albumUrl;

  Album({
    required this.name,
    required this.artist,
    required this.imageUrl,
    required this.albumUrl,
  });

  factory Album.fromTrackJson(Map<String, dynamic> track) {
    final album = track['album'];
    return Album(
      name: album['name'],
      artist: track['artists'][0]['name'],
      imageUrl: album['images'][0]['url'],
      albumUrl: album['external_urls']['spotify'],
    );
  }
}

// Function to sort and get top genres
List<String> getTopGenres(Map<String, double> genreWeights, {int count = 2}) {
  final sorted = genreWeights.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(count).map((e) => e.key.toLowerCase()).toList();
}

// API Call to Spotify

// Replace Dio-based version with this
Future<List<Album>> fetchRecommendedAlbums({
  required String accessToken,
  required List<String> seedGenres,
}) async {
  final uri = Uri.https(
    'api.spotify.com',
    '/v1/recommendations',
    {
      'seed_genres': seedGenres.take(2).join(','),
      'limit': '20',
    },
  );

  final response = await http.get(
    uri,
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    },
  );

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final tracks = data['tracks'] as List;
    return tracks.map((track) => Album.fromTrackJson(track)).toList();
  } else {
    throw Exception('Failed to load recommendations: ${response.body}');
  }
}

// Album List Widget
class AlbumList extends StatelessWidget {
  final List<Album> albums;

  const AlbumList({super.key, required this.albums});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: albums.length,
      itemBuilder: (_, index) {
        final album = albums[index];
        return ListTile(
          leading: Image.network(album.imageUrl, width: 50, height: 50),
          title: Text(album.name),
          subtitle: Text(album.artist),
          onTap: () => launchUrl(Uri.parse(album.albumUrl)),
        );
      },
    );
  }
}

// Main Widget
class RecommendedAlbumScreen extends StatefulWidget {
  final Map<String, double> genreWeights;


  const RecommendedAlbumScreen({
    super.key,
    required this.genreWeights,
  
  });

  @override
  State<RecommendedAlbumScreen> createState() => _RecommendedAlbumScreenState();
}

class _RecommendedAlbumScreenState extends State<RecommendedAlbumScreen> {
  late Future<List<Album>> _albumsFuture;
  late SpotifyTokenManager _tokenManager;

  @override
  void initState() {
    super.initState();
    _tokenManager = SpotifyTokenManager(
      clientId: clientId,
      clientSecret: clientSecret,
    );
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    final seedGenres = getTopGenres(widget.genreWeights);
    _albumsFuture = _fetchRecommendationsWithToken(seedGenres);
  }

  Future<List<Album>> _fetchRecommendationsWithToken(
      List<String> seedGenres) async {
    final accessToken = await _tokenManager.getValidAccessToken();
    return fetchRecommendedAlbums(
      accessToken: accessToken,
      seedGenres: seedGenres,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Recommended Albums')),
      body: FutureBuilder<List<Album>>(
        future: _albumsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            return AlbumList(albums: snapshot.data!);
          } else {
            return const Center(child: Text('No recommendations.'));
          }
        },
      ),
    );
  }
}
