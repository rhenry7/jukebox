// Album List Widget
import 'package:flutter/material.dart';
import 'package:flutter_test_project/utils/reviews/review_helpers.dart';
import 'package:ionicons/ionicons.dart';

import '../models/music_recommendation.dart';

class TrackRecommendationFromPreferences extends StatelessWidget {
  final List<MusicRecommendation> albums;

  const TrackRecommendationFromPreferences({super.key, required this.albums});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: albums.length,
      itemBuilder: (_, index) {
        final album = albums[index];
        return Card(
          elevation: 1,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            side: BorderSide(color: Color.fromARGB(56, 158, 158, 158)),
          ),
          color: Colors.black,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.music_note,
                    size: 10,
                    color: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Expanded content with proper constraints
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      album.song,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      album.artist,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      album.album,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    // Button with size constraints
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                      onPressed: () => {
                            updateDislikedTracks(album.artist, album.song),
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Preferences Updated!'),
                                backgroundColor: Colors.red,
                              ),
                            ),
                            // Navigator.pop(context)
                          },
                      icon: const Icon(Ionicons.close_circle_outline,
                          color: Colors.red)),
                  IconButton(
                      onPressed: () => {
                            updateSavedTracks(album.artist, album.song),
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Recommendations Updated!',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            ),
                            //Navigator.pop(context)
                          },
                      icon: const Icon(Ionicons.add_circle_outline,
                          color: Colors.green)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
