import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_test_project/apis.dart';
import 'package:flutter/widgets.dart' as flutter;
import 'package:spotify/spotify.dart';

class CardTracks extends StatefulWidget {
  const CardTracks({super.key});

  @override
  State<CardTracks> createState() => ListOfTracks();
}

class ListOfTracks extends State<CardTracks> {
  late Future<List<Track>> spotifyTracks;
  double? _rating;

  @override
  void initState() {
    super.initState();
    fetchSpotifyAlbums();
    spotifyTracks = fetchSpotifyTracks();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FutureBuilder<List<Track>>(
        future: spotifyTracks,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final track = snapshot.data![index];
                final albumImages = track.album!.images;
                final smallImageUrl =
                    albumImages!.isNotEmpty ? albumImages.last.url : null;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: ListTile(
                            leading: smallImageUrl != null
                                ? flutter.Image.network(smallImageUrl)
                                : const Icon(Icons
                                    .music_note), // Fallback if no image is available,
                            title: Text(track.name as String),
                            subtitle: Text(track.artists!
                                .map((artist) => artist.name)
                                .join(', ')),
                          ),
                        ),
                        RatingBar(
                          minRating: 0,
                          maxRating: 5,
                          allowHalfRating: true,
                          itemSize: 18,
                          itemPadding:
                              const EdgeInsets.symmetric(horizontal: 2.0),
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
          return const CircularProgressIndicator();
        },
      ),
    );
  }
}
