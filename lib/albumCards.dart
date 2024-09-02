import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_test_project/apis.dart';
import 'package:flutter/widgets.dart' as flutter;
import 'package:spotify/spotify.dart';

class AlbumCard extends StatefulWidget {
  const AlbumCard({super.key});

  @override
  State<AlbumCard> createState() => AlbumList();
}

class AlbumList extends State<AlbumCard> {
  late Future<List<Album>> albums;
  double? _rating;

  @override
  void initState() {
    super.initState();
    albums = fetchSpotifyAlbums();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FutureBuilder<List<Album>>(
        future: albums,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final album = snapshot.data![index];
                print(album.images!.first.url);
                final albumImages = album.images;
                final mediumImage =
                    albumImages!.isNotEmpty ? albumImages.first.url : null;
                var cardImage = NetworkImage(mediumImage!);

                return Card(
                    elevation: 4.0,
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(album.name as String),
                          subtitle: Text(album.artists!
                              .map((artist) => artist.name)
                              .join(', ')),
                          trailing: const Icon(Icons.favorite_outline),
                        ),
                        Container(
                          height: 300.0,
                          child: Ink.image(
                            image: cardImage,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.only(left: 16.0, top: 16.0),
                          alignment: Alignment.centerLeft,
                          child: const Text(
                              "I love this one its the absolute best, just the best. Never been betterm never seen this ever."),
                        ),
                        Container(
                          padding: const EdgeInsets.only(
                              left: 10.0, top: 12.0, bottom: 16.0),
                          alignment: Alignment.centerLeft,
                          child: RatingBar(
                            minRating: 0,
                            maxRating: 5,
                            allowHalfRating: true,
                            itemSize: 24,
                            itemPadding:
                                const EdgeInsets.symmetric(horizontal: 5.0),
                            ratingWidget: RatingWidget(
                              full: const Icon(Icons.star, color: Colors.amber),
                              empty: const Icon(Icons.star, color: Colors.grey),
                              half: const Icon(Icons.star_half,
                                  color: Colors.amber),
                            ),
                            onRatingUpdate: (rating) {
                              _rating = rating;
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ));
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