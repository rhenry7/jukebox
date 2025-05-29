// First, add this to your pubspec.yaml dependencies:
// http: ^1.1.0

import 'dart:convert';
import 'package:flutter_test_project/api_key.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class UnsplashService {
  // Get a free API key from unsplash.com/developers
  static const String _accessKey = unsplashAccessKey;
  static const String _baseUrl = 'https://api.unsplash.com';

  // Cache to avoid repeated API calls for the same search
  static Map<String, String> _imageCache = {};

  static Future<String?> getVinylImage({
    required String albumName,
    required String artistName,
  }) async {
    try {
      // Create a cache key
      final cacheKey = '${albumName}_${artistName}'.toLowerCase();
      if (_imageCache.containsKey(cacheKey)) {
        return _imageCache[cacheKey];
      }

      // Search terms for vinyl/record photos
      List<String> searchQueries = [
        'vinyl record $albumName $artistName',
        'vinyl record collection $artistName',
        'vinyl records music collection',
        'record player vinyl $artistName',
        'vinyl collection aesthetic',
      ];

      // Try each search query until we get results
      for (String query in searchQueries) {
        final url =
            Uri.parse('$_baseUrl/search/photos').replace(queryParameters: {
          'query': query,
          'per_page': '10',
          'orientation': 'square', // Good for album-like images
          'client_id': _accessKey,
        });

        final response = await http.get(url);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final results = data['results'] as List;

          if (results.isNotEmpty) {
            // Get a random image from the results
            final randomIndex =
                DateTime.now().millisecondsSinceEpoch % results.length;
            final imageUrl = results[randomIndex]['urls']['regular'];

            // Cache the result
            _imageCache[cacheKey] = imageUrl;
            return imageUrl;
          }
        }

        // Small delay between requests to respect rate limits
        await Future.delayed(Duration(milliseconds: 200));
      }

      return null;
    } catch (e) {
      print('Error fetching Unsplash image: $e');
      return null;
    }
  }

  // Fallback method for generic vinyl images
  static Future<String?> getGenericVinylImage() async {
    try {
      final url =
          Uri.parse('$_baseUrl/search/photos').replace(queryParameters: {
        'query': 'vinyl records',
        'per_page': '30',
        'orientation': 'squarish',
        'client_id': _accessKey,
      });

      final response = await http.get(url);
      print("response: ${response.body}");
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;
        print(results[0]);

        if (results.isNotEmpty) {
          final randomIndex =
              DateTime.now().millisecondsSinceEpoch % results.length;
          print("found: ${results[randomIndex]['urls']['small']}");
          return results[randomIndex]['urls']['small'];
        }
      }

      return null;
    } catch (e) {
      print('Error fetching generic vinyl image: $e');
      return null;
    }
  }
}

// Widget for displaying vinyl collection photos
class VinylPhotoWidget extends StatefulWidget {
  final String albumName;
  final String artistName;
  final double size;

  const VinylPhotoWidget({
    Key? key,
    required this.albumName,
    required this.artistName,
    this.size = 60.0,
  }) : super(key: key);

  @override
  _VinylPhotoWidgetState createState() => _VinylPhotoWidgetState();
}

class _VinylPhotoWidgetState extends State<VinylPhotoWidget> {
  String? vinylImageUrl;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVinylImage();
  }

  Future<void> _loadVinylImage() async {
    try {
      String? imageUrl = await UnsplashService.getVinylImage(
        albumName: widget.albumName,
        artistName: widget.artistName,
      );

      // Fallback to generic vinyl image if specific search fails
      imageUrl ??= await UnsplashService.getGenericVinylImage();

      if (mounted) {
        setState(() {
          vinylImageUrl = imageUrl;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: vinylImageUrl != null
            ? Image.network(
                vinylImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[200],
                    child: Icon(
                      Icons.music_note,
                      color: Colors.grey[600],
                      size: widget.size * 0.4,
                    ),
                  );
                },
              )
            : Container(
                color: Colors.grey[200],
                child: Icon(
                  Icons.music_note,
                  color: Colors.grey[600],
                  size: widget.size * 0.4,
                ),
              ),
      ),
    );
  }
}

// UserReview class definition
class UserReview {
  final String? albumName;
  final String? artistName;
  final String? reviewText;
  final int? rating;

  UserReview({
    this.albumName,
    this.artistName,
    this.reviewText,
    this.rating,
  });
}

// Your updated ListTile widget
Widget buildReviewListTile(UserReview review) {
  return ListTile(
    leading: VinylPhotoWidget(
      albumName: review.albumName ?? '',
      artistName: review.artistName ?? '',
      size: 60.0,
    ),
    title: Text(review.albumName ?? 'Unknown Album'),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(review.artistName ?? 'Unknown Artist'),
        Text(
          review.reviewText ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    ),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star, color: Colors.amber, size: 16),
        Text('${review.rating ?? 0}/5'),
      ],
    ),
  );
}

// Alternative: Preset vinyl images (if you don't want to use Unsplash API)
class PresetVinylImages {
  static final List<String> vinylImages = [
    'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=400', // Vinyl records
    'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400', // Record collection
    'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=400', // Turntable
    'https://images.unsplash.com/photo-1556379118-7b491cefb3dc?w=400', // Vinyl stack
    'https://images.unsplash.com/photo-1581833971358-2c8b550f87b3?w=400', // Record player
    // Add more preset URLs as needed
  ];

  static String getRandomVinylImage() {
    final index = DateTime.now().millisecondsSinceEpoch % vinylImages.length;
    return vinylImages[index];
  }
}
