import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test_project/providers/tag_reviews_provider.dart'
    show searchKeysFor;
import 'package:flutter_test_project/models/enhanced_user_preferences.dart';
import 'package:flutter_test_project/services/genre_cache_service.dart';
import 'package:flutter_test_project/services/review_analysis_service.dart';
import 'package:flutter_test_project/services/review_recommendation_service.dart';

/// A fresh id for a review that hasn't been saved yet. The review form takes
/// one when it opens and saves under it, so however many times a save is
/// retried, it's still the same one review.
/// Same shape as a Firestore auto-ID (20 random letters and digits), made
/// here so the form doesn't need Firebase to open.
String newReviewId() {
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  final random = Random.secure();
  return String.fromCharCodes(
      List.generate(20, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
}

/// Saves the review under `users/{uid}/reviews/{reviewId}` and returns its
/// Firestore path, or null if no one is signed in. Throws if the save fails.
/// Saving again with the same [reviewId] overwrites it rather than adding a
/// second review. [spotifyUrl] is the picked song or album on Spotify, saved
/// so cards can link to it without searching.
Future<String?> submitReview(String review, double score, String artist,
    String title, bool liked, String albumImageUrl, List<String>? genres,
    {required String reviewId, String? spotifyUrl}) async {
  // album display image url
  debugPrint(artist);
  final User? user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    debugPrint(review.toString());
    final String userId = user.uid;

    // Fetch and cache genres for this track (in background, don't block)
    unawaited(
        GenreCacheService.getGenresWithCache(title, artist).then((genres) {
      debugPrint('Cached genres for review: $genres');
    }).catchError((e) {
      debugPrint('Error caching genres for review: $e');
    }));

    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reviews')
          .doc(reviewId);
      await docRef.set({
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
        // if (cachedGenres != null && cachedGenres.isNotEmpty) 'genres': cachedGenres,
        if (genres != null && genres.isNotEmpty) 'genres': genres,
        if (spotifyUrl != null && spotifyUrl.isNotEmpty)
          'spotifyUrl': spotifyUrl,
        // Tag page index (also kept up to date by the onReviewWritten
        // function).
        ...searchKeysFor(genres: genres, review: review),
        // Merge, so a retried save never wipes likes or comment counts the
        // first one already picked up.
      }, SetOptions(merge: true));

      debugPrint('✅ Review saved successfully! Document ID: ${docRef.id}');
      debugPrint('📁 Path: users/$userId/reviews/${docRef.id}');

      // Invalidate recommendation cache immediately so the For You tab
      // re-fetches on next focus.
      ReviewRecommendationService.markNeedsRefresh(userId);

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
      return docRef.path;
    } catch (e) {
      debugPrint('❌ Could not post review');
      debugPrint('Error: ${e.toString()}');
      debugPrint('Error type: ${e.runtimeType}');
      rethrow;
    }
  } else {
    debugPrint('could not place review, user not signed in');
  }
  return null;
}

Future<void> deleteReview(String userId, String reviewDocId) async {
  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('reviews')
        .doc(reviewDocId)
        .delete();
  } catch (e) {
    debugPrint('Could not delete review: $e');
  }
}

/// Auto-update user preferences based on review analysis
Future<void> _updatePreferencesFromReviews(String userId) async {
  try {
    final reviewProfile =
        await ReviewAnalysisService.analyzeUserReviews(userId);

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
    final updatedGenreWeights =
        Map<String, double>.from(currentPrefs.genreWeights);
    reviewProfile.genrePreferences.forEach((genre, pref) {
      // Blend existing weight with review-based preference (60% existing, 40% review-based)
      final existingWeight = updatedGenreWeights[genre] ?? 0.5;
      final reviewWeight = pref.preferenceStrength;
      updatedGenreWeights[genre] =
          (existingWeight * 0.6 + reviewWeight * 0.4).clamp(0.0, 1.0);
    });

    // Update favorite artists from highly-rated reviews
    final updatedFavoriteArtists =
        List<String>.from(currentPrefs.favoriteArtists);
    final topArtists = reviewProfile.artistPreferences.entries.toList()
      ..sort(
          (a, b) => b.value.preferenceScore.compareTo(a.value.preferenceScore));

    for (final entry in topArtists.take(5)) {
      if (!updatedFavoriteArtists.contains(entry.key) &&
          entry.value.preferenceScore > 0.7 &&
          entry.value.reviewCount >= 2) {
        // At least 2 reviews
        updatedFavoriteArtists.add(entry.key);
      }
    }

    // Update favorite genres from top genre preferences
    final updatedFavoriteGenres =
        List<String>.from(currentPrefs.favoriteGenres);
    final topGenres = reviewProfile.genrePreferences.entries.toList()
      ..sort((a, b) =>
          b.value.preferenceStrength.compareTo(a.value.preferenceStrength));

    for (final entry in topGenres.take(3)) {
      if (!updatedFavoriteGenres.contains(entry.key) &&
          entry.value.preferenceStrength > 0.6 &&
          entry.value.reviewCount >= 3) {
        // At least 3 reviews in this genre
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
  final String saved = 'artist: $artist, song: $title';

  await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('musicPreferences')
      .doc('profile')
      .update({
    'savedTracks': FieldValue.arrayUnion([saved]),
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
  final String saved = 'artist: $artist, song: $title';

  await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('musicPreferences')
      .doc('profile')
      .update({
    'savedTracks': FieldValue.arrayRemove([saved]),
  });
}

///  upload to firebase list of preferences
///  preferences included savedTracks, [arist: Eagles, song: Hotel California]
///  OpenAi recommendation includes: arist: Eagles, song: Hotel California,
///  filter recommended list, to remove song already saved, reduce duplication

