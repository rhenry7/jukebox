import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test_project/Api/api_key.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/services/get_album_service.dart';
import 'package:http/http.dart' as http;
import 'package:spotify/spotify.dart';

Future<List<Track>> fetchSpotifyTracks() async {
  final credentials = SpotifyApiCredentials(clientId, clientSecret);
  final getFromSpotify = SpotifyApi(credentials);
  final tracks = await getFromSpotify.playlists
      .getTracksByPlaylistId('3cEYpjA9oz9GiPac4AsH4n')
      .all();
  return tracks.toList();
}

// Function 2: Explore tracks from different genres and eras
Future<List<Track>> fetchExploreTracks() async {
  try {
    final credentials = SpotifyApiCredentials(clientId, clientSecret);
    final spotify = SpotifyApi(credentials);

    // Mix of genres and time periods for exploration
    List<String> exploreQueries = [
      'genre:indie year:2020-2024',
      'genre:jazz year:1960-1980',
      'genre:rock year:1990-2010',
      'genre:electronic year:2018-2024',
      'genre:folk year:2015-2024',
      'genre:r&b year:2000-2024',
    ];

    List<Track> exploreTracks = [];

    for (String query in exploreQueries) {
      try {
        final searchResults = await spotify.search.get(query,
            types: [SearchType.track]).first(3); // Get 3 tracks from each genre

        if (searchResults.isNotEmpty) {
          for (var page in searchResults) {
            if (page.items != null) {
              for (var trackSimple in page.items!) {
                if (trackSimple is Track) {
                  exploreTracks.add(trackSimple);
                }
              }
            }
          }
        }

        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        print('Error with explore query "$query": $e');
        continue;
      }
    }

    exploreTracks.shuffle();
    return exploreTracks.take(20).toList();
  } catch (e) {
    print('Error fetching explore tracks: $e');
    return [];
  }
}

Future<Pages<Category>> fetchSpotifyCatgories() async {
  final credentials = SpotifyApiCredentials(clientId, clientSecret);
  final getFromSpotify = SpotifyApi(credentials);
  final category = getFromSpotify.categories.list();
  print(category);
  print(category.first(10).toString());
  return category;
}

// Function 1: Trending tracks across genres
Future<List<Track>> fetchTrendingTracks() async {
  try {
    final credentials = SpotifyApiCredentials(clientId, clientSecret);
    final spotify = SpotifyApi(credentials);

    // Search for popular tracks from recent years
    List<String> trendingQueries = [
      'year:2024',
      'year:2023-2024 genre:pop',
      'year:2024 genre:hip-hop',
      'year:2023-2024 genre:indie',
      'year:2024 genre:electronic',
    ];

    List<Track> allTracks = [];

    for (String query in trendingQueries) {
      try {
        final searchResults = await spotify.search.get(query, types: [
          SearchType.track
        ]).first(4); // Get 4 tracks from each search

        if (searchResults.isNotEmpty) {
          for (var page in searchResults) {
            if (page.items != null) {
              for (var trackSimple in page.items!) {
                if (trackSimple is Track) {
                  allTracks.add(trackSimple);
                }
              }
            }
          }
        }

        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        print('Error with trending query "$query": $e');
        continue;
      }
    }

    // Remove duplicates and shuffle
    Map<String, Track> uniqueTracks = {};
    for (var track in allTracks) {
      if (track.id != null) {
        uniqueTracks[track.id!] = track;
      }
    }

    List<Track> finalTracks = uniqueTracks.values.toList();
    finalTracks.shuffle();
    return finalTracks.take(20).toList();
  } catch (e) {
    print('Error fetching trending tracks: $e');
    return [];
  }
}

// Function 3: Deep cuts and hidden gem tracks
Future<List<Track>> fetchHiddenGemTracks() async {
  try {
    final credentials = SpotifyApiCredentials(clientId, clientSecret);
    final spotify = SpotifyApi(credentials);

    // Search for tracks from niche genres
    List<String> hiddenGemQueries = [
      'genre:shoegaze',
      'genre:post-rock',
      'genre:dream-pop',
      'genre:ambient',
      'genre:experimental',
      'genre:lo-fi',
    ];

    List<Track> gemTracks = [];

    for (String query in hiddenGemQueries) {
      try {
        final searchResults =
            await spotify.search.get(query, types: [SearchType.track]).first(3);

        if (searchResults.isNotEmpty) {
          for (var page in searchResults) {
            if (page.items != null) {
              for (var trackSimple in page.items!) {
                if (trackSimple is Track) {
                  gemTracks.add(trackSimple);
                }
              }
            }
          }
        }

        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        print('Error with hidden gems query "$query": $e');
        continue;
      }
    }

    gemTracks.shuffle();
    return gemTracks.take(15).toList();
  } catch (e) {
    print('Error fetching hidden gem tracks: $e');
    return [];
  }
}

// Function 4: New release tracks
Future<List<Track>> fetchNewReleaseTracks() async {
  try {
    final credentials = SpotifyApiCredentials(clientId, clientSecret);
    final spotify = SpotifyApi(credentials);

    final currentYear = DateTime.now().year;

    // Focus on very recent releases
    List<String> newReleaseQueries = [
      'year:$currentYear',
      'year:$currentYear genre:alternative',
      'year:$currentYear genre:indie',
      'year:$currentYear genre:pop',
    ];

    List<Track> newTracks = [];

    for (String query in newReleaseQueries) {
      try {
        final searchResults =
            await spotify.search.get(query, types: [SearchType.track]).first(5);

        if (searchResults.isNotEmpty) {
          for (var page in searchResults) {
            if (page.items != null) {
              for (var trackSimple in page.items!) {
                if (trackSimple is Track) {
                  newTracks.add(trackSimple);
                }
              }
            }
          }
        }

        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        print('Error with new release query "$query": $e');
        continue;
      }
    }

    // Remove duplicates
    Map<String, Track> uniqueTracks = {};
    for (var track in newTracks) {
      if (track.id != null) {
        uniqueTracks[track.id!] = track;
      }
    }

    List<Track> finalTracks = uniqueTracks.values.toList();
    finalTracks.shuffle();
    return finalTracks.take(20).toList();
  } catch (e) {
    print('Error fetching new release tracks: $e');
    return [];
  }
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

Future<List<Album>> fetchExploreAlbums() async {
  try {
    final credentials = SpotifyApiCredentials(clientId, clientSecret);
    final spotify = SpotifyApi(credentials);

    // Mix of different genres and time periods for exploration
    List<String> exploreQueries = [
      'genre:indie year:2020-2024',
      'genre:jazz year:1960-1980',
      'genre:electronic year:2022-2024',
      'genre:rock year:1990-2010',
      'genre:hip-hop year:2018-2024',
    ];

    List<Album> allAlbums = [];

    for (String query in exploreQueries) {
      try {
        final searchResults = await spotify.search.get(query,
            types: [SearchType.album]).first(4); // Get 4 from each genre

        if (searchResults.isNotEmpty) {
          for (var page in searchResults) {
            if (page.items != null) {
              for (var albumSimple in page.items!) {
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
        print('Error with query "$query": $e');
        continue;
      }
    }

    // Shuffle for variety and limit results
    allAlbums.shuffle();
    return allAlbums.take(20).toList();
  } catch (e) {
    print('Error fetching explore albums: $e');
    return [];
  }
}

Future<List<MusicBrainzAlbum>> fetchAlbums({String query = 'year:2025'}) async {
  try {
    return MusicBrainzService.searchAlbums(year: 1995);
  } catch (e) {
    print('Error fetching albums: $e');
    return throw new Error();
  }
}

Future<List<Album>> fetchPopularAlbums({String query = 'year:2018'}) async {
  try {
    final credentials = SpotifyApiCredentials(clientId, clientSecret);
    final spotify = SpotifyApi(credentials);
    final searchResults =
        await spotify.search.get(query, types: [SearchType.album]).first(20);

    List<Album> albums = [];
    if (searchResults.isNotEmpty) {
      for (var page in searchResults) {
        if (page.items != null) {
          for (var albumSimple in page.items!) {
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
    print('Error fetching albums: $e');
    return [];
  }
}

// Function 2: New releases and fresh discoveries
Future<List<Album>> fetchNewDiscoveries(
    {String genre1 = 'alternative', String genre2 = 'indie'}) async {
  try {
    final credentials = SpotifyApiCredentials(clientId, clientSecret);
    final spotify = SpotifyApi(credentials);

    // Focus on recent releases across different categories
    final currentYear = DateTime.now().year;
    final lastYear = currentYear - 1;

    List<String> newReleaseQueries = [
      // 'year:$currentYear', // This year's releases
      // 'year:$lastYear tag:new', // Last year with "new" tag
      'year:$currentYear genre:$genre1',
      //'year:$currentYear genre:$genre2',
    ];

    List<Album> newAlbums = [];

    for (String query in newReleaseQueries) {
      try {
        final searchResults = await spotify.search.get(query,
            types: [SearchType.album]).first(5); // Get 5 from each search

        if (searchResults.isNotEmpty) {
          for (var page in searchResults) {
            if (page.items != null) {
              for (var albumSimple in page.items!) {
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
        print('Error with new releases query "$query": $e');
        continue;
      }
    }

    // Remove duplicates by ID
    Map<String, Album> uniqueAlbums = {};
    for (var album in newAlbums) {
      if (album.id != null) {
        uniqueAlbums[album.id!] = album;
      }
    }

    List<Album> sortedAlbums = uniqueAlbums.values.toList();
    sortedAlbums.shuffle(); // Shuffle for variety

    return sortedAlbums.take(20).toList();
  } catch (e) {
    print('Error fetching new discoveries: $e');
    return [];
  }
}

class UserReviewInfo {
  final String displayName;
  final String joinDate;
  final int reviewsCount;

  UserReviewInfo({
    required this.displayName,
    required this.joinDate,
    required this.reviewsCount,
  });

  factory UserReviewInfo.fromMap(Map<String, dynamic> map) {
    return UserReviewInfo(
      displayName: map['displayName'] ?? '',
      joinDate: map['joinDate'] ?? '',
      reviewsCount: map['reviewsCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'joinDate': joinDate,
      'reviewsCount': reviewsCount,
    };
  }
}

class User {
  final String id;
  final String displayName;
  final String email;
  final String avatarUrl;
  // final String joinDate;
  // final int reviewsCount;

  User({
    required this.id,
    required this.displayName,
    required this.email,
    required this.avatarUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      displayName: json['displayName'] ?? '',
      email: json['email'] ?? '',
      avatarUrl: json['avatarUrl'] ?? '',
      // joinDate: json['joinDate'] ?? '',
      // reviewsCount: json['reviewsCount'] ?? 0,
    );
  }
}

Future<UserReviewInfo> fetchUserInfo(String userId) async {
  try {
    final List<Review> reviews = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('reviews')
        .orderBy('date', descending: true)
        .get()
        .then((snapshot) => snapshot.docs
            .map((doc) => Review.fromFirestore(doc.data()))
            .toList());

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();

    if (reviews.isNotEmpty) {
      return UserReviewInfo(
        displayName: userDoc.data()?['displayName'] ?? '',
        joinDate: userDoc.data()?['joinDate'] ?? '',
        reviewsCount: reviews.length,
        // use avatar imaage URL
      );
    } else {
      return UserReviewInfo(
        displayName: 'Undefined',
        joinDate: 'Undefined',
        reviewsCount: 0,
      );
    }
  } catch (e) {
    print('Error fetching user info: $e');
    return UserReviewInfo(
      displayName: 'Undefined',
      joinDate: 'Undefined',
      reviewsCount: 0,
    );
  }
}

Future<List<User>> fetchUsers() async {
  try {
    final snapshot = await FirebaseFirestore.instance.collection('users').get();

    return snapshot.docs.map((doc) => User.fromJson(doc.data())).toList();
  } catch (e) {
    print('Error fetching users: $e');
    return [];
  }
}

Future<List<Review>> fetchMockUserComments() async {
  final url = Uri.parse(
      "https://66d638b1f5859a704268af2d.mockapi.io/test/v1/usercomments");
  final response = await http.get(url);
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
  });

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
    'User-Agent': 'YourAppName/1.0 (your-email@example.com)',
  });

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
    'User-Agent': 'YourAppName/1.0 (your-email@example.com)',
  });

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    // Extract the recordings (tracks) from the response
    return data['recordings'];
  } else {
    throw Exception('Failed to load track');
  }
}
