import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test_project/models/enhanced_user_preferences.dart';
import 'package:flutter_test_project/models/music_recommendation.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/services/genre_cache_service.dart';
import 'package:flutter_test_project/services/review_analysis_service.dart';

Future<List<Review>> fetchUserReviews() async {
  final snapshot = await FirebaseFirestore.instance
      .collectionGroup('reviews')
      .orderBy('date', descending: true)
      .get();

  return snapshot.docs.map((doc) => Review.fromFirestore(doc.data())).toList();
}

Future<void> submitReview(String review, double score, String artist,
    String title, bool liked, String albumImageUrl,
    [List<String>? tags]) async {
  // album display image url
  debugPrint(artist);
  final User? user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    debugPrint(review.toString());
    final String userId = user.uid;
    
    // Fetch and cache genres for this track (in background, don't block)
    unawaited(GenreCacheService.getGenresWithCache(title, artist).then((genres) {
      debugPrint('Cached genres for review: $genres');
    }).catchError((e) {
      debugPrint('Error caching genres for review: $e');
    }));
    
    try {
      // Try to get genres from cache (non-blocking, but try to include in review)
      final cachedGenres = await GenreCacheService.getCachedGenres(title, artist);
      
      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reviews')
          .add({
        'displayName': user.displayName,
        'email': user.email,
        'userId': userId,
        'artist': artist,
        'title': title,
        'review': review,
        'score': score,
        'liked': liked,
        'date': FieldValue.serverTimestamp(), // Adds server timestamp
        'albumImageUrl': albumImageUrl,
        if (cachedGenres != null && cachedGenres.isNotEmpty) 'genres': cachedGenres,
        if (tags != null && tags.isNotEmpty) 'tags': tags,
      });
      
      debugPrint('✅ Review saved successfully! Document ID: ${docRef.id}');
      debugPrint('📁 Path: users/$userId/reviews/${docRef.id}');
      
      // Auto-update preferences and invalidate cache (run in background)
      unawaited(Future(() async {
        try {
          // Invalidate cache so next analysis will be fresh
          await ReviewAnalysisService.clearCache(userId);
          
          // Update preferences from reviews
          await _updatePreferencesFromReviews(userId);
        } catch (e) {
          debugPrint('Error updating preferences/cache: $e');
        }
      }));
    } catch (e) {
      debugPrint('❌ Could not post review');
      debugPrint('Error: ${e.toString()}');
      debugPrint('Error type: ${e.runtimeType}');
      // Don't rethrow - let UI handle the error state
    }
  } else {
    debugPrint('could not place review, user not signed in');
  }
}

void addUserReview() async {
  final FirebaseAuth auth = FirebaseAuth.instance;
  if (auth.currentUser != null) {
    // Function implementation pending
  }
}

Future<void> deleteReview(String userId, String reviewDocId) async {
  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('reviews')
        .doc()
        .delete();
  } catch (e) {
    debugPrint('Could not delete review: $e');
  }
}

/// Auto-update user preferences based on review analysis
Future<void> _updatePreferencesFromReviews(String userId) async {
  try {
    final reviewProfile = await ReviewAnalysisService.analyzeUserReviews(userId);
    
    // Get current preferences
    final prefsDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('musicPreferences')
        .doc('profile')
        .get();
    
    if (!prefsDoc.exists) {
      debugPrint('Preferences document does not exist, skipping update');
      return;
    }
    
    final currentPrefs = EnhancedUserPreferences.fromJson(prefsDoc.data()!);
    
    // Update genre weights based on review analysis
    final updatedGenreWeights = Map<String, double>.from(currentPrefs.genreWeights);
    reviewProfile.genrePreferences.forEach((genre, pref) {
      // Blend existing weight with review-based preference (60% existing, 40% review-based)
      final existingWeight = updatedGenreWeights[genre] ?? 0.5;
      final reviewWeight = pref.preferenceStrength;
      updatedGenreWeights[genre] = (existingWeight * 0.6 + reviewWeight * 0.4).clamp(0.0, 1.0);
    });
    
    // Update favorite artists from highly-rated reviews
    final updatedFavoriteArtists = List<String>.from(currentPrefs.favoriteArtists);
    final topArtists = reviewProfile.artistPreferences.entries.toList()
      ..sort((a, b) => b.value.preferenceScore.compareTo(a.value.preferenceScore));
    
    for (final entry in topArtists.take(5)) {
      if (!updatedFavoriteArtists.contains(entry.key) && 
          entry.value.preferenceScore > 0.7 &&
          entry.value.reviewCount >= 2) { // At least 2 reviews
        updatedFavoriteArtists.add(entry.key);
      }
    }
    
    // Update favorite genres from top genre preferences
    final updatedFavoriteGenres = List<String>.from(currentPrefs.favoriteGenres);
    final topGenres = reviewProfile.genrePreferences.entries.toList()
      ..sort((a, b) => b.value.preferenceStrength.compareTo(a.value.preferenceStrength));
    
    for (final entry in topGenres.take(3)) {
      if (!updatedFavoriteGenres.contains(entry.key) && 
          entry.value.preferenceStrength > 0.6 &&
          entry.value.reviewCount >= 3) { // At least 3 reviews in this genre
        updatedFavoriteGenres.add(entry.key);
      }
    }
    
    // Update preferences document
    await prefsDoc.reference.update({
      'genreWeights': updatedGenreWeights,
      'favoriteArtists': updatedFavoriteArtists,
      'favoriteGenres': updatedFavoriteGenres,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
    
    debugPrint('Auto-updated preferences from reviews');
  } catch (e) {
    debugPrint('Error updating preferences from reviews: $e');
  }
}

Future<void> updateSavedTracks(String artist, String title) async {
  final String userId = FirebaseAuth.instance.currentUser != null
      ? FirebaseAuth.instance.currentUser!.uid
      : '';
  if (userId.isEmpty) {
    debugPrint('User not logged in, cannot upload preferences.');
    return;
  }
  final String saved = 'arist: $artist, song: $title';

  await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('musicPreferences')
      .doc('profile')
      .update({
    'savedTracks': FieldValue.arrayUnion([saved]),
  });
}

Future<void> updateDislikedTracks(String artist, String title) async {
  final String userId = FirebaseAuth.instance.currentUser != null
      ? FirebaseAuth.instance.currentUser!.uid
      : '';
  if (userId.isEmpty) {
    debugPrint('User not logged in, cannot upload preferences.');
    return;
  }
  final String disliked = 'arist: $artist, song: $title';

  await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('musicPreferences')
      .doc('profile')
      .update({
    'dislikedTracks': FieldValue.arrayUnion([disliked]),
  });
}

Future<void> updateRemovePreferences(String artist, String title) async {
  final String userId = FirebaseAuth.instance.currentUser != null
      ? FirebaseAuth.instance.currentUser!.uid
      : '';
  if (userId.isEmpty) {
    debugPrint('User not logged in, cannot upload preferences.');
    return;
  }
  final String saved = 'arist: $artist, song: $title';

  await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('musicPreferences')
      .doc('profile')
      .update({
    'savedTracks': FieldValue.arrayRemove([saved]),
  });
}

List<MusicRecommendation> removeDuplicatesFaster({
  required List<MusicRecommendation> albums,
  required List<MusicRecommendation> savedTracks,
}) {
  final savedSet = savedTracks
      .map((t) =>
          '${t.artist.toLowerCase().trim()}|${t.song.toLowerCase().trim()}')
      .toSet();

  return albums.where((album) {
    final key =
        '${album.artist.toLowerCase().trim()}|${album.song.toLowerCase().trim()}';
    return !savedSet.contains(key);
  }).toList();
}

///  upload to firebase list of preferences
///  preferences included savedTracks, [arist: Eagles, song: Hotel California]
///  OpenAi recommendation includes: arist: Eagles, song: Hotel California,
///  filter recommended list, to remove song already saved, reduce duplication

List<MusicRecommendation> removeDuplication(
    List<MusicRecommendation> albums, EnhancedUserPreferences preferences) {
  final String userId = FirebaseAuth.instance.currentUser != null
      ? FirebaseAuth.instance.currentUser!.uid
      : '';
  if (userId.isEmpty) {
    debugPrint('User not logged in, cannot upload preferences.');
    return [];
  }
  final List<String> savedTracks = preferences.savedTracks;
  albums.removeWhere((album) =>
      savedTracks.contains('artist: ${album.artist}, song: ${album.song}'));
  return albums;
}
