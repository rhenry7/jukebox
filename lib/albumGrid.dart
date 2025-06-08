import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' as flutter;
import 'package:flutter_test_project/GIFs/gifs.dart';
import 'package:flutter_test_project/loadingWidget.dart';
import 'package:flutter_test_project/reviewSheetContentForm.dart';
import 'package:spotify/spotify.dart';

import 'apis.dart';

class AlbumGrid extends StatefulWidget {
  const AlbumGrid({super.key});

  @override
  _AlbumGrid createState() => _AlbumGrid();
}

class _AlbumGrid extends State<AlbumGrid> {
  late Future<List<Album>> imageUrls;

  @override
  void initState() {
    super.initState();
    imageUrls = fetchPopularAlbums();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Album>>(
        future: imageUrls,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // Number of columns in the grid
                crossAxisSpacing: 5.0, // Horizontal space between cards
                mainAxisSpacing: 5.0, // Vertical space between cards
              ),
              padding: const EdgeInsets.all(8.0),
              itemCount: snapshot.data!.length, // Number of cards to display
              itemBuilder: (context, index) {
                final album = snapshot.data![index];
                final albumImages = album.images;
                final foundImage =
                    albumImages!.isNotEmpty ? albumImages.first.url : "";
                final artists = album.artists?.map((n) => n.name).join("");
                final albumType = album.albumType.toString();

                // print(album.label);
                return Card(
                  elevation: 5, // Shadow elevation for the card
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10), // Rounded corners
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
                              title: album.name ?? "no album found",
                              albumImageUrl: foundImage ?? "",
                              artist: artists ?? "unknown",
                            );
                          });
                    },
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                            10), // Ensure image fits within rounded corners
                        child: foundImage != null
                            ? flutter.Image.network(
                                foundImage,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(child: Icon(Icons.error));
                                },
                              )
                            : null),
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
