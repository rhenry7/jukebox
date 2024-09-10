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
        future: albums.then((value) => value.reversed.toList()),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final album = snapshot.data![index];
                final albumImages = album.images;
                final mediumImage =
                    albumImages!.isNotEmpty ? albumImages.first.url : null;
                var cardImage = NetworkImage(mediumImage!);

                return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side:
                          BorderSide(color: Color.fromARGB(103, 158, 158, 158)),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(album.name as String),
                          subtitle: Text(album.artists!
                              .map((artist) => artist.name)
                              .join(', ')),
                          trailing: OutlinedButton(
                            onPressed: () {
                              debugPrint('Received click');
                            },
                            child: const Text("Pop",
                                style: TextStyle(color: Colors.white)),
                          ),
                        ),
                        Container(
                          height: 300.0,
                          child: Ink.image(
                            image: cardImage,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.only(left: 2.0, top: 16.0),
                          alignment: Alignment.centerLeft,
                          child: const ListTile(
                            //leading: Icon(Icons.account_box_outlined),
                            title: Text("UserNameExample123 says:"),
                            subtitle: Text(
                                '"Its the best, just the absolute best there ever was in the history of ever and ever. Just the bes, dont you think?"',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.only(
                              left: 10.0, top: 4.0, bottom: 16.0),
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
