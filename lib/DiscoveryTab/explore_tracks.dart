import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' as flutter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/GIFs/gifs.dart';
import 'package:flutter_test_project/Api/apis.dart';
import 'package:flutter_test_project/providers/preferences_provider.dart';
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
    return await WikipediaService.getArtistSummary(artistName);
  }
  
  /// Filter tracks to only include those with substantial bios (2+ lines, ~100+ characters)
  /// FALLBACK: If no bios are found, returns empty map but tracks will still be shown
  Future<Map<String, String?>> _filterTracksWithBios(List<Track> tracks) async {
    final bios = <String, String?>{};
    int successCount = 0;
    int failureCount = 0;
    
    // Fetch bios in parallel with timeout for better performance
    final bioFutures = <Future<void>>[];
    
    for (var track in tracks) {
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
              print('⚠️  Error fetching bio for $artistName: $e');
            }),
      );
    }
    
    // Wait for all bio fetches to complete
    try {
      await Future.wait(bioFutures, eagerError: false);
    } catch (e) {
      print('⚠️  Error in parallel bio fetching: $e');
    }
    
    print('📊 Bio fetch results: $successCount successful, $failureCount failed');
    
    // FALLBACK: If we got some tracks but no bios, return empty map
    // The UI will show tracks without bios rather than showing "No tracks"
    return bios;
  }

  @override
  Widget build(BuildContext context) {
    // Watch preferences to get user's favorite genres
    final preferencesAsync = ref.watch(userPreferencesProvider);
    
    // Build the tracks future based on preferences
    final tracksFuture = preferencesAsync.when(
      data: (preferences) {
        if (preferences.favoriteGenres.isNotEmpty) {
          return fetchExploreTracks(
            userGenres: preferences.favoriteGenres,
            genreWeights: preferences.genreWeights.isNotEmpty 
                ? preferences.genreWeights 
                : null,
          );
        } else {
          return fetchExploreTracks();
        }
      },
      loading: () => fetchExploreTracks(), // Use defaults while loading
      error: (_, __) => fetchExploreTracks(), // Use defaults on error
    );
    
    return RefreshIndicator(
      onRefresh: () async {
        // Refresh preferences - this will automatically rebuild and reload tracks
        ref.invalidate(userPreferencesProvider);
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
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.explore_outlined, 
                                  size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              const Text(
                                'No tracks to explore',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 20),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Pull down to refresh and discover new music!',
                                style: TextStyle(color: Colors.white70),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    
                    // Filter tracks with substantial bios (2+ lines) - use FutureBuilder for async filtering
                    return FutureBuilder<Map<String, String?>>(
                      future: _filterTracksWithBios(snapshot.data!),
                      builder: (context, bioSnapshot) {
                        if (bioSnapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(32.0),
                            child: DiscoBallLoading(),
                          );
                        }
                        
                        final bios = bioSnapshot.data ?? {};
                        
                        // FALLBACK: If no bios found, show tracks anyway (without bios)
                        // This prevents the "No tracks with artist information" message
                        // when Wikipedia API fails in production
                        final filteredTracks = bios.isEmpty
                            ? snapshot.data! // Show all tracks if no bios found
                            : snapshot.data!.where((track) {
                                final artistName = track.artists != null && track.artists!.isNotEmpty
                                    ? track.artists!.first.name ?? 'Unknown Artist'
                                    : 'Unknown Artist';
                                return bios.containsKey(artistName);
                              }).toList();
                        
                        // Only show empty message if we actually have no tracks at all
                        if (filteredTracks.isEmpty && snapshot.data!.isNotEmpty) {
                          // This shouldn't happen, but handle it gracefully
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.explore_outlined, 
                                      size: 64, color: Colors.grey),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No tracks with artist information',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 20),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Pull down to refresh and discover new music!',
                                    style: TextStyle(color: Colors.white70),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        
                        return ListView.builder(
                          padding: EdgeInsets.zero, // Match home section - no padding on ListView
                          itemCount: filteredTracks.length,
                          physics: const NeverScrollableScrollPhysics(), // Disable
                          shrinkWrap: true,
                          itemBuilder: (context, index) {
                            final track = filteredTracks[index];
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
                            
                            final bio = bios[artistName];
                        
                        //print(track);
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
                                  // Artist bio from Wikipedia (pre-fetched and filtered)
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
                    print(snapshot);
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
                                ref.invalidate(userPreferencesProvider);
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
}
