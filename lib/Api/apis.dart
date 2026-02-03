import 'dart:async';
import 'dart:convert';

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
// Now supports: user preferences, featured playlists, and randomization
Future<List<Track>> fetchExploreTracks({
  List<String>? userGenres,
  Map<String, double>? genreWeights,
}) async {
  try {
    final credentials = SpotifyApiCredentials(clientId, clientSecret);
    final spotify = SpotifyApi(credentials);
    final random = DateTime.now().millisecondsSinceEpoch; // Seed for randomization

    final List<Track> exploreTracks = [];

    // Step 1: Fetch from Spotify's featured/trending playlists (OPTIMIZED: Skip if errors occur)
    // Note: Some playlist IDs may not be available in all regions, so we skip gracefully
    // We catch all errors silently to avoid console spam from expected 404s
    try {
      // Try a few different popular playlist IDs (in case one doesn't exist)
      final featuredPlaylistIds = [
        '37i9dQZEVXbMDoHDwVN2tF', // Global Top 50
        '37i9dQZF1DXcBWIGoYBM5M', // Today's Top Hits
      ];
      
      bool foundTracks = false;
      for (final playlistId in featuredPlaylistIds) {
        try {
          // Fetch with timeout to avoid hanging
          final tracksIterable = await spotify.playlists
              .getTracksByPlaylistId(playlistId)
              .all()
              .timeout(const Duration(seconds: 5));
          
          // Take first 10 tracks from featured playlist
          int count = 0;
          for (final track in tracksIterable) {
            if (count >= 10) break; // Increased from 5 to 10
            exploreTracks.add(track);
                      count++;
          }
          
          if (count > 0) {
            foundTracks = true;
            print('   ✅ Found $count tracks from featured playlist');
            break; // Success, no need to try other playlists
          }
        } catch (e) {
          // Silently skip 404/Resource not found errors - playlist may not exist in this region
          // The Spotify library throws these errors, but we catch them here to prevent console spam
          final errorStr = e.toString().toLowerCase();
          if (errorStr.contains('404') || 
              errorStr.contains('resource not found') ||
              errorStr.contains('not found') ||
              errorStr.contains('error code: 404')) {
            // Silently continue - don't log expected errors
            continue;
          }
          // For other errors (timeout, network, etc.), also silently continue
          // to avoid console spam - the genre queries below will still work
          continue;
        }
      }
    } catch (e) {
      // Outer catch - silently skip if entire section fails
      // Continue without featured playlist tracks - genre queries will still work
    }

    // Step 2: Generate dynamic queries based on user preferences (if available)
    final List<String> exploreQueries = [];
    
    if (userGenres != null && userGenres.isNotEmpty) {
      print('🎵 [EXPLORE] Using user preferences: ${userGenres.take(5).join(", ")}');
      
      // Use user's favorite genres (prioritize by weight if available)
      // OPTIMIZED: Reduced from 6 to 4 genres for faster loading
      final genresToUse = genreWeights != null && genreWeights.isNotEmpty
          ? (userGenres.toList()
              ..sort((a, b) {
                final weightA = genreWeights[a] ?? 0.5;
                final weightB = genreWeights[b] ?? 0.5;
                return weightB.compareTo(weightA);
              }))
              .take(4) // Use top 4 genres (reduced from 6)
          : userGenres.take(4);
      
      // Generate random time periods for each genre
      final timePeriods = _generateRandomTimePeriods(genresToUse.length, random);
      
      for (var i = 0; i < genresToUse.length; i++) {
        final genre = genresToUse.elementAt(i);
        final timePeriod = timePeriods[i];
        exploreQueries.add('genre:$genre year:$timePeriod');
      }
    } else {
      // Fallback: Use randomized default genres if no user preferences
      print('🎵 [EXPLORE] No user preferences, using randomized defaults...');
      final defaultGenres = [
        'indie', 'jazz', 'rock', 'electronic', 'folk', 'r&b',
        'hip hop', 'pop', 'country', 'blues', 'reggae', 'metal'
      ];
      defaultGenres.shuffle();
      
      // OPTIMIZED: Reduced from 6 to 4 queries for faster loading
      final timePeriods = _generateRandomTimePeriods(4, random);
      for (var i = 0; i < 4; i++) {
        final genre = defaultGenres[i];
        final timePeriod = timePeriods[i];
        exploreQueries.add('genre:$genre year:$timePeriod');
      }
    }

    // Step 3: Fetch tracks from genre-based queries (OPTIMIZED: Parallel execution)
    print('🎵 [EXPLORE] Fetching tracks from ${exploreQueries.length} genre queries (parallel)...');
    
    // Execute queries in parallel for faster loading
    final queryFutures = exploreQueries.map((query) async {
      try {
        final searchFuture = spotify.search.get(query,
            types: [SearchType.track]).first(10); // Increased from 3 to 10 for more results
        
        final searchResults = await searchFuture.timeout(
          const Duration(seconds: 5),
        );

        final tracks = <Track>[];
        if (searchResults.isNotEmpty) {
          for (final page in searchResults) {
            if (page.items != null) {
              for (final trackSimple in page.items!) {
                if (trackSimple is Track) {
                  tracks.add(trackSimple);
                }
              }
            }
          }
        }
        return tracks;
      } on TimeoutException {
        print('⚠️  Query "$query" timed out');
        return <Track>[];
      } catch (e) {
        print('⚠️  Error with explore query "$query": $e');
        return <Track>[];
      }
    }).toList();
    
    // Wait for all queries to complete in parallel
    final results = await Future.wait(queryFutures);
    for (final tracks in results) {
      exploreTracks.addAll(tracks);
    }

    // Remove duplicates (by track ID)
    final uniqueTracks = <String, Track>{};
    for (final track in exploreTracks) {
      if (track.id != null) {
        uniqueTracks.putIfAbsent(track.id!, () => track);
      }
    }

    // Shuffle and return top 30 (increased from 20 for more results)
    final finalTracks = uniqueTracks.values.toList()..shuffle();
    print('✅ [EXPLORE] Returning ${finalTracks.take(30).length} unique tracks');
    return finalTracks.take(30).toList();
  } catch (e) {
    print('❌ Error fetching explore tracks: $e');
    return [];
  }
}

/// Generate random time periods for genre queries
List<String> _generateRandomTimePeriods(int count, int seed) {
  final random = (seed % 1000) / 1000.0; // Normalize seed
  final periods = <String>[];
  final currentYear = DateTime.now().year;
  
  // Define time period ranges as List<int> [startYear, endYear]
  final periodRanges = [
    [currentYear - 4, currentYear], // Recent (last 4 years)
    [currentYear - 10, currentYear - 4], // Mid-recent (5-10 years ago)
    [currentYear - 20, currentYear - 10], // Classic (10-20 years ago)
    [currentYear - 30, currentYear - 20], // Vintage (20-30 years ago)
    [1960, 1990], // Retro (1960-1990)
    [1990, 2010], // 90s-2000s
  ];
  
  // Shuffle periods based on seed
  final shuffledPeriods = List<List<int>>.from(periodRanges);
  for (var i = 0; i < shuffledPeriods.length; i++) {
    final j = ((random * 1000 + i) % shuffledPeriods.length).toInt();
    final temp = shuffledPeriods[i];
    shuffledPeriods[i] = shuffledPeriods[j];
    shuffledPeriods[j] = temp;
  }
  
  // Generate count number of periods
  for (var i = 0; i < count; i++) {
    final period = shuffledPeriods[i % shuffledPeriods.length];
    periods.add('${period[0]}-${period[1]}');
  }
  
  return periods;
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
        final searchResults = await spotify.search.get(query, types: [
          SearchType.track
        ]).first(4); // Get 4 tracks from each search

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
        print('Error with trending query "$query": $e');
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
        final searchResults =
            await spotify.search.get(query, types: [SearchType.track]).first(3);

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
    final List<String> newReleaseQueries = [
      'year:$currentYear',
      'year:$currentYear genre:alternative',
      'year:$currentYear genre:indie',
      'year:$currentYear genre:pop',
    ];

    final List<Track> newTracks = [];

    for (final String query in newReleaseQueries) {
      try {
        final searchResults =
            await spotify.search.get(query, types: [SearchType.track]).first(5);

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
        print('Error with new release query "$query": $e');
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
    final credentials = SpotifyApiCredentials(clientId, clientSecret);
    final spotify = SpotifyApi(credentials);

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
        final searchResults = await spotify.search.get(query,
            types: [SearchType.album]).first(4); // Get 4 from each genre

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
    return throw Error();
  }
}

Future<List<Album>> fetchPopularAlbums({String query = 'year:2019'}) async {
  try {
    final credentials = SpotifyApiCredentials(clientId, clientSecret);
    final spotify = SpotifyApi(credentials);
    final searchResults =
        await spotify.search.get(query, types: [SearchType.album]).first(20);

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

    final List<String> newReleaseQueries = [
      // 'year:$currentYear', // This year's releases
      // 'year:$lastYear tag:new', // Last year with "new" tag
      'year:$currentYear genre:$genre1',
      //'year:$currentYear genre:$genre2',
    ];

    final List<Album> newAlbums = [];

    for (final String query in newReleaseQueries) {
      try {
        final searchResults = await spotify.search.get(query,
            types: [SearchType.album]).first(5); // Get 5 from each search

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
        print('Error with new releases query "$query": $e');
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
    print('Error fetching new discoveries: $e');
    return [];
  }
}



Future<List<Review>> fetchMockUserComments() async {
  final url = Uri.parse(
      'https://66d638b1f5859a704268af2d.mockapi.io/test/v1/usercomments');
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
