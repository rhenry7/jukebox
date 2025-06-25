import 'package:flutter/material.dart';
import 'package:flutter_test_project/GIFs/gifs.dart';
import 'package:flutter_test_project/services/get_album_service.dart';
import 'package:flutter_test_project/ui/screens/addReview/reviewSheetContentForm.dart';

import '../../../Api/apis.dart';

class AlbumGrid extends StatefulWidget {
  const AlbumGrid({super.key});

  @override
  _AlbumGrid createState() => _AlbumGrid();
}

class _AlbumGrid extends State<AlbumGrid> {
  late Future<List<MusicBrainzAlbum>> imageUrls;
  Future<List<MusicBrainzAlbum>> processAlbums() async {
    final spotifyAlbums = await fetchPopularAlbums();
    final enrichedAlbums =
        await MusicBrainzService().enrichAlbumsWithMusicBrainz(spotifyAlbums);
    return enrichedAlbums;
  }

  @override
  void initState() {
    super.initState();
    imageUrls = processAlbums();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<MusicBrainzAlbum>>(
        future: imageUrls,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // Number of columns in the grid
                crossAxisSpacing: 1,
                mainAxisSpacing: 1,
                childAspectRatio: 3 / 4, // Width / Height ratio
              ),
              itemCount: snapshot.data!.length, // Number of cards to display
              itemBuilder: (context, index) {
                final album = snapshot.data![index];
                final genres = album.genres?.join(", ").toString();
                final foundImage = album.imageURL;
                final artists = album.artist;
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(10), // Rounded corners
                          ),
                          child: Card(
                            elevation: 1, // Shadow elevation for the card
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10), // Rounded corners
                            ),
                            child: InkWell(
                                onTap: () {
                                  // Action to perform when the card is tapped
                                  showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      builder: (BuildContext context) {
                                        initialChildSize:
                                        0.9; // Takes up 90% of the screen

                                        return MyReviewSheetContentForm(
                                          title:
                                              album.title ?? "no album found",
                                          albumImageUrl: foundImage ?? "",
                                          artist: artists ?? "unknown",
                                        );
                                      });
                                },
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
                                        : null)),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: 8.0, left: 10.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    album.title,
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  Text(
                                    album.artist,
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
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
