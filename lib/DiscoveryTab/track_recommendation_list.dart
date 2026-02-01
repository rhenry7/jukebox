// Album List Widget
import 'package:flutter/material.dart';
import 'package:flutter_test_project/MusicPreferences/musicRecommendationService.dart';
import 'package:flutter_test_project/utils/reviews/review_helpers.dart';
import 'package:flutter_test_project/ui/screens/addReview/reviewSheetContentForm.dart';
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
        return _RecommendationCard(album: album);
      },
    );
  }
}

class _RecommendationCard extends StatefulWidget {
  final MusicRecommendation album;

  const _RecommendationCard({required this.album});

  @override
  State<_RecommendationCard> createState() => _RecommendationCardState();
}

class _RecommendationCardState extends State<_RecommendationCard> {
  String? _imageUrl;
  bool _isLoadingImage = false;

  @override
  void initState() {
    super.initState();
    _imageUrl = widget.album.imageUrl;
    // Fetch image in background if not available
    if (_imageUrl == null || _imageUrl!.isEmpty) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (_isLoadingImage) return;
    
    setState(() {
      _isLoadingImage = true;
    });

    try {
      final imageUrl = await MusicRecommendationService
          .fetchAlbumImageForRecommendation(widget.album);
      
      if (mounted && imageUrl.isNotEmpty) {
        setState(() {
          _imageUrl = imageUrl;
          _isLoadingImage = false;
        });
      } else {
        setState(() {
          _isLoadingImage = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingImage = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
          elevation: 1,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            side: BorderSide(color: Color.fromARGB(56, 158, 158, 158)),
          ),
          color: Colors.white10,
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: (_imageUrl != null && _imageUrl!.isNotEmpty)
                      ? Image.network(
                          _imageUrl!,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.music_note,
                                color: Colors.white70,
                                size: 30,
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.music_note,
                            color: Colors.white70,
                            size: 30,
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
                        widget.album.song,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.album.artist,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.album.album,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Genre Tags (pills)
                      if (widget.album.genres.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6.0,
                          runSpacing: 6.0,
                          children: widget.album.genres.take(4).map((genre) {
                            return Chip(
                              label: Text(
                                genre,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              backgroundColor: Colors.white.withOpacity(0.1),
                              side: BorderSide(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                        onPressed: () => {
                              updateDislikedTracks(widget.album.artist, widget.album.song),
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
                        onPressed: () {
                          // Open review sheet with pre-populated data
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (BuildContext context) {
                              return MyReviewSheetContentForm(
                                title: widget.album.song,
                                artist: widget.album.artist,
                                albumImageUrl: _imageUrl ?? widget.album.imageUrl,
                              );
                            },
                          );
                        },
                        icon: const Icon(Ionicons.add_circle_outline,
                            color: Colors.green)),
                  ],
                ),
              ],
            ),
          ),
        );
  }
}
