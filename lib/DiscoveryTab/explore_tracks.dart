import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' as flutter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/GIFs/gifs.dart';
import 'package:flutter_test_project/Api/apis.dart';
import 'package:flutter_test_project/services/taste_profile_prompt_generation_service.dart';
import 'package:flutter_test_project/services/wikipedia_service.dart';
import 'package:spotify/spotify.dart';

class ExploreTracks extends ConsumerStatefulWidget {
  const ExploreTracks({super.key});
  @override
  ConsumerState<ExploreTracks> createState() => ExploreTracksState();
}

class ExploreTracksState extends ConsumerState<ExploreTracks> {
  late Future<Pages<Category>> categories;
  
  /// Get artist bio from Wikipedia (with Firestore caching)
  /// The WikipediaService now handles caching automatically via WikipediaBioCacheService
  Future<String?> _getArtistBio(String artistName) async {
    // WikipediaService.getArtistSummary now uses Firestore caching automatically
    return WikipediaService.getArtistSummary(artistName);
  }
  
  /// Filter tracks to only include those with substantial bios (2+ lines, ~100+ characters)
  /// FALLBACK: If no bios are found, returns empty map but tracks will still be shown
  Future<Map<String, String?>> _filterTracksWithBios(List<Track> tracks) async {
    final bios = <String, String?>{};
    int successCount = 0;
    int failureCount = 0;
    
    // Fetch bios in parallel with timeout for better performance
    final bioFutures = <Future<void>>[];
    
    for (final track in tracks) {
      final artistName = track.artists != null && track.artists!.isNotEmpty
          ? track.artists!.first.name ?? 'Unknown Artist'
          : 'Unknown Artist';
      
      // Skip if already processed
      if (bios.containsKey(artistName)) continue;
      
      // Fetch bio with timeout
      bioFutures.add(
        _getArtistBio(artistName)
            .timeout(
              const Duration(seconds: 8), // Longer timeout for production
              onTimeout: () {
                failureCount++;
                return null;
              },
            )
            .then((bio) {
              if (bio != null && bio.length >= 100) {
                final sentences = bio.split('.');
                if (sentences.length >= 2) {
                  bios[artistName] = bio;
                  successCount++;
                } else {
                  failureCount++;
                }
              } else {
                failureCount++;
              }
            })
            .catchError((e) {
              failureCount++;
              // Log errors in production for debugging
              debugPrint('⚠️  Error fetching bio for $artistName: $e');
            }),
      );
    }
    
    // Wait for all bio fetches to complete
    try {
      await Future.wait(bioFutures, eagerError: false);
    } catch (e) {
      debugPrint('⚠️  Error in parallel bio fetching: $e');
    }
    
    debugPrint('📊 Bio fetch results: $successCount successful, $failureCount failed');
    
    // FALLBACK: If we got some tracks but no bios, return empty map
    // The UI will show tracks without bios rather than showing "No tracks"
    return bios;
  }

  @override
  Widget build(BuildContext context) {
    // Fetch taste profile to get user's music preferences
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final tasteProfileService = MusicProfileService(
      firestore: FirebaseFirestore.instance,
    );
    
    // Build the tracks future based on taste profile
    final tracksFuture = userId != null
        ? _buildTracksFromTasteProfile(tasteProfileService, userId)
        : fetchExploreTracks(); // Use defaults if not logged in
    
    return RefreshIndicator(
      onRefresh: () async {
        // Refresh by invalidating state
        setState(() {});
        await Future.delayed(const Duration(milliseconds: 500));
      },
      color: Colors.red[600],
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Center(
              child: FutureBuilder<List<Track>>(
                future: tracksFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    if (snapshot.data!.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.explore_outlined, 
                                  size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No tracks to explore',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 20),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Pull down to refresh and discover new music!',
                                style: TextStyle(color: Colors.white70),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    
                    // Show all tracks - fetch bios in background (optional, non-blocking)
                    final allTracks = snapshot.data!;
                    
                    // Start fetching bios in background (non-blocking)
                    final biosFuture = _filterTracksWithBios(allTracks);
                    
                    return ListView.builder(
                      padding: EdgeInsets.zero, // Match home section - no padding on ListView
                      itemCount: allTracks.length,
                      physics: const NeverScrollableScrollPhysics(), // Disable
                      shrinkWrap: true,
                      itemBuilder: (context, index) {
                        final track = allTracks[index];
                        final albumImages = track.album!.images;
                        // Use first image (largest) instead of last (smallest)
                        final imageUrl = albumImages!.isNotEmpty 
                            ? albumImages.first.url 
                            : null;
                        final trackDescription = track.album!.releaseDate;
                        
                        // Get artist name for Wikipedia bio
                        final artistName = track.artists != null && track.artists!.isNotEmpty
                            ? track.artists!.first.name ?? 'Unknown Artist'
                            : 'Unknown Artist';
                        
                        // Use FutureBuilder to show bio when available (non-blocking)
                        return FutureBuilder<Map<String, String?>>(
                          future: biosFuture,
                          builder: (context, bioSnapshot) {
                            final bios = bioSnapshot.data ?? {};
                            final bio = bios[artistName];
                            
                            // Wrap card in Padding to match home/friends section spacing
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                              child: Card(
                                elevation: 1,
                                margin: const EdgeInsets.all(0), // Match home section - no margin
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(8)),
                                  side: BorderSide(color: Color.fromARGB(56, 158, 158, 158)),
                                ),
                                color: Colors.white10, // Match home/friends section
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0), // Match home section padding
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Top Row: Image and Track Info
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          // Album cover image
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: imageUrl != null
                                                ? flutter.Image.network(
                                                    imageUrl,
                                                    width: 80,
                                                    height: 80,
                                                    fit: flutter.BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) {
                                                      return const Icon(Icons.music_note, size: 80, color: Colors.white70);
                                                    },
                                                    loadingBuilder: (context, child, loadingProgress) {
                                                      if (loadingProgress == null) return child;
                                                      return Container(
                                                        width: 80,
                                                        height: 80,
                                                        decoration: BoxDecoration(
                                                          color: Colors.grey[800],
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: const Center(
                                                          child: DiscoBallLoading(),
                                                        ),
                                                      );
                                                    },
                                                  )
                                                : const Icon(Icons.music_note, size: 80, color: Colors.white70),
                                          ),
                                          const SizedBox(width: 16),
                                          // Track info
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                // Artist name
                                                Text(
                                                  track.artists != null && track.artists!.isNotEmpty
                                                      ? track.artists!.map((artist) => artist.name).join(', ')
                                                      : 'Unknown Artist',
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                // Track title
                                                Text(
                                                  track.name as String,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      // Artist bio from Wikipedia (optional, shown when available)
                                      if (bio != null && bio.isNotEmpty) ...[
                                        const SizedBox(height: 16), // Match spacing from home section
                                        Text(
                                          bio,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14.0,
                                            fontStyle: FontStyle.italic,
                                          ),
                                          maxLines: 5,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  } else if (snapshot.hasError) {
                    debugPrint('Tracks load error: ${snapshot.error}');
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, 
                                size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            const Text(
                              'Error loading tracks',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 18),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${snapshot.error}',
                              style: const TextStyle(color: Colors.white70),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {});
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: DiscoBallLoading(),
                  );
                },
              ),
            ),
            //const Gap(10),
          ],
        ),
      ),
    );
  }
  
  /// Build tracks future from taste profile
  Future<List<Track>> _buildTracksFromTasteProfile(
    MusicProfileService tasteProfileService,
    String userId,
  ) async {
    try {
      // Fetch music profile (with caching)
      final musicProfile = await tasteProfileService.getUserMusicProfile(userId);
      
      if (musicProfile != null) {
        // Generate taste profile to get structured data
        final tasteProfile = tasteProfileService.generateTasteProfile(musicProfile);
        
        // Extract preferred genres and genre weights
        final preferredGenres = (tasteProfile['preferredGenres'] as List?)?.cast<String>() ?? [];
        final genreWeights = (musicProfile['genreWeights'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        ) ?? <String, double>{};
        
        debugPrint('🎵 [EXPLORE] Using taste profile: ${preferredGenres.take(5).join(", ")}');
        
        if (preferredGenres.isNotEmpty) {
          return fetchExploreTracks(
            userGenres: preferredGenres,
            genreWeights: genreWeights.isNotEmpty ? genreWeights : null,
          );
        }
      }
      
      // Fallback to defaults if no taste profile
      debugPrint('🎵 [EXPLORE] No taste profile found, using defaults...');
      return fetchExploreTracks();
    } catch (e) {
      debugPrint('⚠️ Error fetching taste profile for explore: $e');
      // Fallback to defaults on error
      return fetchExploreTracks();
    }
  }
}
