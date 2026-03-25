import 'package:flutter/material.dart';
import 'package:flutter_test_project/providers/recommended_albums_provider.dart';
import 'package:flutter_test_project/ui/screens/Trending/album_detail_page.dart';
import 'package:flutter_test_project/utils/cached_image.dart';
import 'package:gap/gap.dart';

/// A vertical card (~200w x 300h) displaying an album recommendation.
///
/// Dark themed with album art on top, title/artist/genres below, and
/// stat pills (rating + review count) at the bottom.
class RecommendedAlbumCard extends StatelessWidget {
  final AlbumRecommendation album;

  const RecommendedAlbumCard({super.key, required this.album});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AlbumDetailPage(album: album),
          ),
        );
      },
      child: Container(
        width: 200,
        height: 300,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Album art — fills card width, rounded top corners
            album.albumImageUrl.isNotEmpty
                ? AppCachedImage(
                    imageUrl: album.albumImageUrl,
                    width: 200,
                    height: 160,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  )
                : Container(
                    width: 200,
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                    ),
                    child:
                        const Icon(Icons.album, color: Colors.white70, size: 48),
                  ),

            // Text content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      album.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(2),
                    // Artist
                    Text(
                      album.artist,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(4),
                    // Genres (up to 2)
                    if (album.genres.isNotEmpty)
                      Text(
                        album.genres.take(2).join(', '),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                    const Spacer(),

                    // Stat pills
                    Row(
                      children: [
                        _StatPill(
                          icon: Icons.star_rounded,
                          iconColor: Colors.amber,
                          label: album.averageScore.toStringAsFixed(1),
                        ),
                        const Gap(6),
                        _StatPill(
                          icon: Icons.rate_review_outlined,
                          iconColor: Colors.white54,
                          label: '${album.reviewCount}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small pill showing an icon + label, used for rating and review count.
class _StatPill extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;

  const _StatPill({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor),
          const Gap(3),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
