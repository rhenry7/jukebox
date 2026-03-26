import 'package:flutter/material.dart';
import 'package:flutter_test_project/providers/spotify_artist_provider.dart';
import 'package:flutter_test_project/utils/cached_image.dart';

class TopArtistsCard extends StatelessWidget {
  final List<TopArtistData> artists;

  const TopArtistsCard({super.key, required this.artists});

  @override
  Widget build(BuildContext context) {
    if (artists.isEmpty) return const SizedBox.shrink();

    return Card(
      color: Colors.grey[900],
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Artists',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: artists.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  return _ArtistItem(artist: artists[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtistItem extends StatelessWidget {
  final TopArtistData artist;

  const _ArtistItem({required this.artist});

  @override
  Widget build(BuildContext context) {
    final initial =
        artist.name.isNotEmpty ? artist.name[0].toUpperCase() : '?';
    final genreText =
        artist.genres.isNotEmpty ? artist.genres.first : '';

    return SizedBox(
      width: 80,
      child: Column(
        children: [
          // Circular artist image
          ClipOval(
            child: artist.imageUrl.isNotEmpty
                ? AppCachedImage(
                    imageUrl: artist.imageUrl,
                    width: 60,
                    height: 60,
                  )
                : CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.grey[800],
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          // Artist name
          Text(
            artist.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          // Genre
          if (genreText.isNotEmpty)
            Text(
              genreText,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          // Review count
          Text(
            '${artist.reviewCount} review${artist.reviewCount == 1 ? '' : 's'}',
            style: TextStyle(color: Colors.red[400], fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
