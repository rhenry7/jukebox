import 'package:flutter/material.dart';
import 'package:flutter_test_project/providers/popular_tracks_provider.dart';
import 'package:flutter_test_project/ui/screens/addReview/reviewSheetContentForm.dart';
import 'package:flutter_test_project/utils/cached_image.dart';
import 'package:gap/gap.dart';

/// A vertical card (~200w x 300h) displaying a globally popular track.
///
/// Dark themed with album art on top, track name/artist below, and
/// a popularity stat pill at the bottom.
class PopularTrackCard extends StatelessWidget {
  final PopularTrack track;

  const PopularTrackCard({super.key, required this.track});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (BuildContext context) {
            return MyReviewSheetContentForm(
              title: track.name,
              artist: track.artist,
              albumImageUrl: track.imageUrl,
            );
          },
        );
      },
      child: Container(
        width: 200,
        height: 300,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Album art — fills card width, rounded top corners
            track.imageUrl.isNotEmpty
                ? AppCachedImage(
                    imageUrl: track.imageUrl,
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
                    child: const Icon(Icons.music_note,
                        color: Colors.white70, size: 48),
                  ),

            // Text content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Track name
                    Text(
                      track.name,
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
                      track.artist,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const Spacer(),

                    // Popularity pill
                    Row(
                      children: [
                        _StatPill(
                          icon: Icons.trending_up,
                          iconColor: Colors.green,
                          label: '${track.popularity}',
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

/// Small pill showing an icon + label.
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
        color: Colors.white.withOpacity(0.08),
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
