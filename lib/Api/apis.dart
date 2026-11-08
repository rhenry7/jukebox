import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/services/get_album_service.dart';
import 'package:flutter_test_project/utils/spotify_retry.dart';
import 'package:http/http.dart' as http;
import 'package:spotify/spotify.dart';
import 'package:flutter_test_project/services/spotify_client.dart';

Future<List<Track>> fetchSpotifyTracks() async {
  final getFromSpotify = sharedSpotifyApi();
  final tracks = await getFromSpotify.playlists
      .getTracksByPlaylistId('3cEYpjA9oz9GiPac4AsH4n')
      .all();
  return tracks.toList();
}

Future<Pages<Category>> fetchSpotifyCatgories() async {
  final getFromSpotify = sharedSpotifyApi();
  final category = getFromSpotify.categories.list();
  debugPrint('Categories: ${category.toString()}');
  debugPrint(category.first(10).toString());
  return category;
}

// Function 1: Trending tracks across genres
Future<List<Track>> fetchTrendingTracks() async {
  try {
    final spotify = sharedSpotifyApi();

    // Search for popular tracks from recent years
    final List<String> trendingQueries = [
      'year:2024',
      'year:2023-2024 genre:pop',
      'year:2024 genre:hip-hop',
      'year:2023-2024 genre:indie',
      'year:2024 genre:electronic',
    ];

    final List<Track> allTracks = [];

    for (final String query in trendingQueries) {
      try {
        final searchResults = await withSpotifyRetry(
          () => spotify.search.get(query, types: [
            SearchType.track
          ]).first(4),
        );

        if (searchResults.isNotEmpty) {
          for (final page in searchResults) {
            if (page.items != null) {
              for (final trackSimple in page.items!) {
                if (trackSimple is Track) {
                  allTracks.add(trackSimple);
                }
              }
            }
          }
        }

        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        debugPrint('Error with trending query "$query": $e');
        continue;
      }
    }

    // Remove duplicates and shuffle
    final Map<String, Track> uniqueTracks = {};
    for (final track in allTracks) {
      if (track.id != null) {
        uniqueTracks[track.id!] = track;
      }
    }

    final List<Track> finalTracks = uniqueTracks.values.toList();
    finalTracks.shuffle();
    return finalTracks.take(20).toList();
  } catch (e) {
    debugPrint('Error fetching trending tracks: $e');
    return [];
  }
}

// Function 3: Deep cuts and hidden gem tracks
Future<List<Track>> fetchHiddenGemTracks() async {
  try {
    final spotify = sharedSpotifyApi();

    // Search for tracks from niche genres
    final List<String> hiddenGemQueries = [
      'genre:shoegaze',
      'genre:post-rock',
      'genre:dream-pop',
      'genre:ambient',
      'genre:experimental',
      'genre:lo-fi',
    ];

    final List<Track> gemTracks = [];

    for (final String query in hiddenGemQueries) {
      try {
        final searchResults = await withSpotifyRetry(
          () => spotify.search.get(query, types: [SearchType.track]).first(3),
        );

        if (searchResults.isNotEmpty) {
          for (final page in searchResults) {
            if (page.items != null) {
              for (final trackSimple in page.items!) {
                if (trackSimple is Track) {
                  gemTracks.add(trackSimple);
                }
              }
            }
          }
        }

        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        debugPrint('Error with hidden gems query "$query": $e');
        continue;
      }
    }

    gemTracks.shuffle();
    return gemTracks.take(15).toList();
  } catch (e) {
    debugPrint('Error fetching hidden gem tracks: $e');
    return [];
  }
}

// Function 4: New release tracks
Future<List<Track>> fetchNewReleaseTracks() async {
  try {
    final spotify = sharedSpotifyApi();

    final currentYear = DateTime.now().year;

    // Focus on very recent releases
    final List<String> newReleaseQueries = [
      'year:$currentYear',
      'year:$currentYear genre:alternative',
      'year:$currentYear genre:indie',
      'year:$currentYear genre:pop',
    ];

    final List<Track> newTracks = [];

    for (final String query in newReleaseQueries) {
      try {
        final searchResults = await withSpotifyRetry(
          () => spotify.search.get(query, types: [SearchType.track]).first(5),
        );

        if (searchResults.isNotEmpty) {
          for (final page in searchResults) {
            if (page.items != null) {
              for (final trackSimple in page.items!) {
                if (trackSimple is Track) {
                  newTracks.add(trackSimple);
                }
              }
            }
          }
        }

        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        debugPrint('Error with new release query "$query": $e');
        continue;
      }
    }

    // Remove duplicates
    final Map<String, Track> uniqueTracks = {};
    for (final track in newTracks) {
      if (track.id != null) {
        uniqueTracks[track.id!] = track;
      }
    }

    final List<Track> finalTracks = uniqueTracks.values.toList();
    finalTracks.shuffle();
    return finalTracks.take(20).toList();
  } catch (e) {
    debugPrint('Error fetching new release tracks: $e');
    return [];
  }
}

Future<List<Album>> fetchSpotifyAlbums() async {
  final getFromSpotify = sharedSpotifyApi();
  final tracks = await getFromSpotify.playlists
      .getTracksByPlaylistId(
          '37i9dQZF1DX1gRalH1mWrP') // replace with list from recommendation;
      .all();
  final List<String> albumsIds = [];

  for (final track in tracks) {
    albumsIds.add(track.album!.id ?? '');
  }
  // might not need this part
  final sb = StringBuffer();
  sb.writeAll(albumsIds, ',');
  final List<String> limitAlbumIds = albumsIds.sublist(0, 15);
  final albums = await getFromSpotify.albums.list(limitAlbumIds);
  return albums.toList();
}

Future<List<Album>> fetchExploreAlbums() async {
  try {
    final spotify = sharedSpotifyApi();

    // Mix of different genres and time periods for exploration
    final List<String> exploreQueries = [
      'genre:indie year:2020-2024',
      'genre:jazz year:1960-1980',
      'genre:electronic year:2022-2024',
      'genre:rock year:1990-2010',
      'genre:hip-hop year:2018-2024',
    ];

    final List<Album> allAlbums = [];

    for (final String query in exploreQueries) {
      try {
        final searchResults = await withSpotifyRetry(
          () => spotify.search.get(query,
              types: [SearchType.album]).first(4),
        );

        if (searchResults.isNotEmpty) {
          for (final page in searchResults) {
            if (page.items != null) {
              for (final albumSimple in page.items!) {
                if (albumSimple is AlbumSimple && albumSimple.id != null) {
                  final fullAlbum = await spotify.albums.get(albumSimple.id!);
                  allAlbums.add(fullAlbum);
                }
              }
            }
          }
        }

        // Small delay to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        debugPrint('Error with query "$query": $e');
        continue;
      }
    }

    // Shuffle for variety and limit results
    allAlbums.shuffle();
    return allAlbums.take(20).toList();
  } catch (e) {
    debugPrint('Error fetching explore albums: $e');
    return [];
  }
}

Future<List<MusicBrainzAlbum>> fetchAlbums({String query = 'year:2025'}) async {
  try {
    return MusicBrainzService.searchAlbums(year: 1995);
  } catch (e) {
    debugPrint('Error fetching albums: $e');
    return throw Error();
  }
}

Future<List<Album>> fetchPopularAlbums({String query = 'year:2019'}) async {
  try {
    final spotify = sharedSpotifyApi();
    final searchResults = await withSpotifyRetry(
      () => spotify.search.get(query, types: [SearchType.album]).first(20),
    );

    final List<Album> albums = [];
    if (searchResults.isNotEmpty) {
      for (final page in searchResults) {
        if (page.items != null) {
          for (final albumSimple in page.items!) {
            if (albumSimple is AlbumSimple && albumSimple.id != null) {
              // Get full album details
              final fullAlbum = await spotify.albums.get(albumSimple.id!);
              albums.add(fullAlbum);
            }
          }
        }
      }
    }

    return albums;
  } catch (e) {
    debugPrint('Error fetching albums: $e');
    return [];
  }
}

// Function 2: New releases and fresh discoveries
Future<List<Album>> fetchNewDiscoveries(
    {String genre1 = 'alternative', String genre2 = 'indie'}) async {
  try {
    final spotify = sharedSpotifyApi();

    // Focus on recent releases across different categories
    final currentYear = DateTime.now().year;
    final lastYear = currentYear - 1;

    final List<String> newReleaseQueries = [
      // 'year:$currentYear', // This year's releases
      // 'year:$lastYear tag:new', // Last year with "new" tag
      'year:$currentYear genre:$genre1',
      //'year:$currentYear genre:$genre2',
    ];

    final List<Album> newAlbums = [];

    for (final String query in newReleaseQueries) {
      try {
        final searchResults = await withSpotifyRetry(
          () => spotify.search.get(query,
              types: [SearchType.album]).first(5),
        );

        if (searchResults.isNotEmpty) {
          for (final page in searchResults) {
            if (page.items != null) {
              for (final albumSimple in page.items!) {
                if (albumSimple is AlbumSimple && albumSimple.id != null) {
                  final fullAlbum = await spotify.albums.get(albumSimple.id!);
                  newAlbums.add(fullAlbum);
                }
              }
            }
          }
        }

        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        debugPrint('Error with new releases query "$query": $e');
        continue;
      }
    }

    // Remove duplicates by ID
    final Map<String, Album> uniqueAlbums = {};
    for (final album in newAlbums) {
      if (album.id != null) {
        uniqueAlbums[album.id!] = album;
      }
    }

    final List<Album> sortedAlbums = uniqueAlbums.values.toList();
    sortedAlbums.shuffle(); // Shuffle for variety

    return sortedAlbums.take(20).toList();
  } catch (e) {
    debugPrint('Error fetching new discoveries: $e');
    return [];
  }
}

Future<List<Review>> fetchMockUserComments() async {
  final url = Uri.parse(
      'https://66d638b1f5859a704268af2d.mockapi.io/test/v1/usercomments');
  final response = await http.get(url).timeout(const Duration(seconds: 15));
  if (response.statusCode == 200) {
    // Parse the JSON data
    final List<dynamic> jsonData = json.decode(response.body);
    // Convert the JSON data into a list of Review objects
    return jsonData.map((json) => Review.fromJson(json)).toList();
  } else {
    throw Exception('Failed to load user comments');
  }
}

Future<List<dynamic>> fetchAlbumsFromTag(String tag) async {
  final url = Uri.parse(
      'https://musicbrainz.org/ws/2/release/?query=tag:$tag AND primarytype:album&fmt=json');

  final response = await http.get(url, headers: {
    'User-Agent': 'jukeboxd/1.0 (ramoneh94@gmail.com)',
  }).timeout(const Duration(seconds: 15));

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    // Extract the releases (albums) from the response
    return data['releases'];
  } else {
    throw Exception('Failed to load rap albums');
  }
}

Future<List<dynamic>> fetchListTracks(String tag, {int limit = 1}) async {
  final url = Uri.parse(
      'https://musicbrainz.org/ws/2/recording/?query=tag:rap&fmt=json&limit=1');

  final response = await http.get(url, headers: {
    'User-Agent': 'jukeboxd/1.0 (ramoneh94@gmail.com)',
  }).timeout(const Duration(seconds: 15));

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    // Extract the recordings (tracks) from the response
    return data['recordings'];
  } else {
    throw Exception('Failed to load rap tracks');
  }
}

Future<List<dynamic>> fetchTrackByName(String trackName) async {
  final url = Uri.parse(
      'https://musicbrainz.org/ws/2/recording/?query=recording:"$trackName"&fmt=json');

  final response = await http.get(url, headers: {
    'User-Agent': 'jukeboxd/1.0 (ramoneh94@gmail.com)',
  }).timeout(const Duration(seconds: 15));

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    // Extract the recordings (tracks) from the response
    return data['recordings'];
  } else {
    throw Exception('Failed to load track');
  }
}
