import 'package:flutter/material.dart';
import 'package:flutter_test_project/providers/recommended_artists_provider.dart';
import 'package:flutter_test_project/ui/screens/addReview/reviewSheetContentForm.dart';
import 'package:flutter_test_project/utils/cached_image.dart';
import 'package:gap/gap.dart';

/// A vertical card (~200w x 300h) displaying an AI-recommended artist.
///
/// Dark themed with artist image on top, name/genres/reason below, and
/// a genre pill row at the bottom.
class RecommendedArtistCard extends StatelessWidget {
  final RecommendedArtist artist;

  const RecommendedArtistCard({super.key, required this.artist});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (BuildContext context) {
            return MyReviewSheetContentForm(
              title: '',
              artist: artist.name,
              albumImageUrl: artist.imageUrl,
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
            // Artist image — fills card width, rounded top corners
            artist.imageUrl.isNotEmpty
                ? AppCachedImage(
                    imageUrl: artist.imageUrl,
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
                    child: const Icon(Icons.person,
                        color: Colors.white70, size: 48),
                  ),

            // Text content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Artist name
                    Text(
                      artist.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(4),
                    // Genres (up to 2)
                    if (artist.genres.isNotEmpty)
                      Text(
                        artist.genres.take(2).join(', '),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const Gap(2),
                    // AI reason
                    Text(
                      artist.reason,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const Spacer(),

                    // Genre pills
                    if (artist.genres.isNotEmpty)
                      Row(
                        children: artist.genres
                            .take(2)
                            .map(
                              (g) => Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: _GenrePill(label: g),
                              ),
                            )
                            .toList(),
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

/// Small pill showing a genre label.
class _GenrePill extends StatelessWidget {
  final String label;

  const _GenrePill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 11),
      ),
    );
  }
}
