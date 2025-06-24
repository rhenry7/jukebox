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
            double screenWidth = MediaQuery.of(context).size.width;
            int columns = 2;
            double tileWidth =
                (screenWidth - 3 * 10) / columns; // adjust for padding/gutter
            double desiredTileHeight = 350;
            double aspectRatio = tileWidth / desiredTileHeight;
            return GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // Number of columns in the grid
                crossAxisSpacing: 5, // Horizontal space between cards
                mainAxisSpacing: 5, // Vertical space between cards
                childAspectRatio: aspectRatio,
              ),
              padding: const EdgeInsets.all(8.0),
              itemCount: snapshot.data!.length, // Number of cards to display
              itemBuilder: (context, index) {
                final album = snapshot.data![index];
                final genres = album.genres?.join(", ").toString();
                final foundImage = album.imageURL;
                final artists = album.artist;
                return SizedBox(
                  child: Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(10), // Rounded corners
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            child: Card(
                          elevation: 5, // Shadow elevation for the card
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
                                        title: album.title ?? "no album found",
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
                        )),
                        Expanded(
                            child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${album.title}",
                                textAlign: TextAlign.left,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black),
                              ),
                              Text(
                                "${album.artist}",
                                textAlign: TextAlign.left,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.normal,
                                    color: Colors.black),
                              ),
                              Text(
                                "${album.releaseDate}",
                                textAlign: TextAlign.left,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.normal,
                                    color: Colors.black),
                              ),
                              Text(
                                "${genres}",
                                textAlign: TextAlign.left,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.normal,
                                    color: Colors.black),
                              ),
                            ],
                          ),
                        )),
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
