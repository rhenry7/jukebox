import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' as flutter;
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_test_project/GIFs/gifs.dart';
import 'package:flutter_test_project/Api/apis.dart';
import 'package:spotify/spotify.dart';

class DiscoveryTrackCards extends StatefulWidget {
  const DiscoveryTrackCards({super.key});
  @override
  State<DiscoveryTrackCards> createState() => ListOfTracks();
}

class ListOfTracks extends State<DiscoveryTrackCards> {
  late Future<List<Track>> spotifyTracks;
  late Future<Pages<Category>> categories;
  double? _rating = 5.0;

  @override
  void initState() {
    super.initState();
    spotifyTracks = fetchExploreTracks();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 16),
          Center(
            child: FutureBuilder<List<Track>>(
              future: spotifyTracks,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return ListView.builder(
                    itemCount: snapshot.data!.length,
                    physics: const NeverScrollableScrollPhysics(), // Disable
                    shrinkWrap: true,
                    itemBuilder: (context, index) {
                      final track = snapshot.data![index];
                      final albumImages = track.album!.images;
                      // Use first image (largest) instead of last (smallest)
                      final imageUrl = albumImages!.isNotEmpty 
                          ? albumImages.first.url 
                          : null;
                      final trackDescription = track.album!.releaseDate;
                      //print(track);
                      return Card(
                        elevation: 0,
                        //margin: const EdgeInsets.all(0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(
                              color: Color.fromARGB(56, 158, 158, 158)),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: ListTile(
                                      leading: imageUrl != null
                                          ? ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              child: flutter.Image.network(
                                                imageUrl,
                                                width: 56,
                                                height: 56,
                                                fit: flutter.BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Container(
                                                    width: 56,
                                                    height: 56,
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey[800],
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: const Icon(
                                                      Icons.music_note,
                                                      color: Colors.white70,
                                                      size: 28,
                                                    ),
                                                  );
                                                },
                                                loadingBuilder: (context, child, loadingProgress) {
                                                  if (loadingProgress == null) return child;
                                                  return Container(
                                                    width: 56,
                                                    height: 56,
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey[800],
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: const Center(
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            )
                                          : Container(
                                              width: 56,
                                              height: 56,
                                              decoration: BoxDecoration(
                                                color: Colors.grey[800],
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Icon(
                                                Icons.music_note,
                                                color: Colors.white70,
                                                size: 28,
                                              ),
                                            ),
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
                                    itemPadding: const EdgeInsets.symmetric(
                                        horizontal: 2.0),
                                    ratingWidget: RatingWidget(
                                      full: const Icon(Icons.star,
                                          color: Colors.amber),
                                      empty: const Icon(Icons.star,
                                          color: Colors.grey),
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
                            const Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      "Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
                                      maxLines: 10,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12.0,
                                        fontStyle: FontStyle.italic,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          ],
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
          ),
          //const Gap(10),
        ],
      ),
    );
  }
}
