import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test_project/GIFs/gifs.dart';
import 'package:flutter_test_project/services/get_album_service.dart';
import 'package:flutter_test_project/ui/screens/addReview/reviewSheetContentForm.dart';
import 'package:gap/gap.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../Api/apis.dart';

class AlbumGrid extends StatefulWidget {
  const AlbumGrid({super.key});
  @override
  _AlbumGrid createState() => _AlbumGrid();
}

Future<List<MusicBrainzAlbum>> processAlbums() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? albumJsonList = prefs.getStringList('cachedAlbums');

    if (albumJsonList != null && albumJsonList.isNotEmpty) {
      print('Loading cached albums');
      return albumJsonList
          .map((jsonStr) {
            try {
              return MusicBrainzAlbum.fromJson(jsonDecode(jsonStr));
            } catch (e) {
              print('Error parsing cached album: $e');
              return null;
            }
          })
          .whereType<MusicBrainzAlbum>()
          .toList();
    } else {
      print('Fetching fresh album data');
      final spotifyAlbums = await fetchPopularAlbums();
      final enrichedAlbums =
          await MusicBrainzService().enrichAlbumsWithMusicBrainz(spotifyAlbums);
      // Cache the results
      final List<String> albumJsonList =
          enrichedAlbums.map((album) => jsonEncode(album.toJson())).toList();
      await prefs.setStringList('cachedAlbums', albumJsonList);

      return enrichedAlbums;
    }
  } catch (e) {
    print('Error in processAlbums: $e');
    rethrow;
  }
}

class _AlbumGrid extends State<AlbumGrid> {
  late Future<List<MusicBrainzAlbum>> albums;
  @override
  void initState() {
    super.initState();
    print('initState called'); // Add this line
    albums = processAlbums();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<MusicBrainzAlbum>>(
        future: albums,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // Number of columns in the grid
                crossAxisSpacing: 1,
                mainAxisSpacing: 1,
                childAspectRatio: 3 / 4.2, // Width / Height ratio
              ),
              itemCount: snapshot.data!.length, // Number of cards to display
              itemBuilder: (context, index) {
                final album = snapshot.data![index];
                final genres = album.genres?.join(', ').toString();
                final foundImage = album.imageURL;
                final artists = album.artist;
                return Card(
                  color: Colors.grey[900],
                  child: InkWell(
                    onTap: () {
                      showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (BuildContext context) {
                            initialChildSize:
                            0.9; // Takes up 90% of the screen

                            return MyReviewSheetContentForm(
                              title: album.title ?? 'no album found',
                              albumImageUrl: foundImage ?? '',
                              artist: artists ?? 'unknown',
                            );
                          });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Card(
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    10), // Rounded corners
                              ),
                              child: Card(
                                elevation: 1, // Shadow elevation for the card
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      10), // Rounded corners
                                ),
                                child: ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                        10), // Ensure image fits within rounded corners
                                    child: foundImage != null
                                        ? Image.network(
                                            foundImage,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return const Center(
                                                  child: Icon(Icons.error));
                                            },
                                          )
                                        : null),
                              ),
                            ),
                            const Gap(10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                      top: 8.0, left: 10.0, right: 10.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        album.title,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        album.artist,
                                        style:
                                            TextStyle(color: Colors.grey[500], fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      // Genre Tags (pills)
                                      if (album.genres != null && album.genres!.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 6.0,
                                          runSpacing: 6.0,
                                          children: album.genres!.take(3).map((genre) {
                                            return Chip(
                                              label: Text(
                                                genre,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              backgroundColor: Colors.white.withOpacity(0.1),
                                              side: BorderSide(
                                                color: Colors.white.withOpacity(0.2),
                                                width: 1,
                                              ),
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              visualDensity: VisualDensity.compact,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(25),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          } else if (snapshot.hasError) {
            print(snapshot);
            return Text('Error: ${snapshot.error}');
          }
          return const DiscoBallLoading();
        },
      ),
    );
  }
}
