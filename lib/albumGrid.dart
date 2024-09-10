import 'package:flutter/material.dart';
import 'package:spotify/spotify.dart';
import 'package:flutter/widgets.dart' as flutter;
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
    imageUrls = fetchSpotifyAlbums();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Whats Hot'),
      ),
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
              padding: const EdgeInsets.all(16.0),
              itemCount: snapshot.data!.length, // Number of cards to display
              itemBuilder: (context, index) {
                final album = snapshot.data![index];
                final albumImages = album.images;
                final foundImage =
                    albumImages!.isNotEmpty ? albumImages.first.url : "";
                // print(album.label);
                return Card(
                  elevation: 5, // Shadow elevation for the card
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10), // Rounded corners
                  ),
                  child: InkWell(
                    onTap: () {
                      // Action to perform when the card is tapped
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Card $index tapped')),
                      );
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
          return const CircularProgressIndicator();
        },
      ),
    );
  }
}
