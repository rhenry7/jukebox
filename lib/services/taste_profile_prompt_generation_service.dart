import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for analyzing music profiles and generating recommendation prompts
class MusicProfileService {
  final FirebaseFirestore? _firestore;

  /// [firestore] is optional for testing. Pass [FirebaseFirestore.instance]
  /// in production (after Firebase.initializeApp()).
  MusicProfileService({FirebaseFirestore? firestore}) : _firestore = firestore;

  /// Fetches the user's music profile from Firestore
  Future<Map<String, dynamic>?> getUserMusicProfile(String userId) async {
    if (_firestore == null) return null;
    try {
      final docSnapshot = await _firestore!
          .collection('users')
          .doc(userId)
          .collection('musicProfile')
          .doc('profile')
          .get();

      if (docSnapshot.exists) {
        return docSnapshot.data();
      }
      return null;
    } catch (e) {
      print('Error fetching music profile: $e');
      return null;
    }
  }

  /// Analyzes reviews to extract sentiment and preferences
  Map<String, dynamic> analyzeReviews(List<dynamic> reviews) {
    final lovedKeywords = <String>[];
    final hatedKeywords = <String>[];
    final artistMentions = <String>[];
    final genreMentions = <String>[];

    for (var review in reviews) {
      if (review is! String) continue;

      final lowerReview = review.toLowerCase();

      // Extract sentiment
      if (lowerReview.contains('loved') ||
          lowerReview.contains('love') ||
          lowerReview.contains('great') ||
          lowerReview.contains('amazing')) {
        lovedKeywords.addAll(_extractMusicTerms(lowerReview, positive: true));
      }

      if (lowerReview.contains('hated') ||
          lowerReview.contains('hate') ||
          lowerReview.contains('bad') ||
          lowerReview.contains('terrible')) {
        hatedKeywords.addAll(_extractMusicTerms(lowerReview, positive: false));
      }

      // Extract artist mentions (simple pattern matching)
      final artistPattern = RegExp(r'by ([a-z\s\.]+)');
      final artistMatches = artistPattern.allMatches(lowerReview);
      for (var match in artistMatches) {
        if (match.group(1) != null) {
          artistMentions.add(match.group(1)!.trim());
        }
      }
    }

    return {
      'lovedKeywords': lovedKeywords,
      'hatedKeywords': hatedKeywords,
      'artistMentions': artistMentions,
      'genreMentions': genreMentions,
    };
  }

  /// Extracts music-related terms from review text
  List<String> _extractMusicTerms(String text, {required bool positive}) {
    final terms = <String>[];
    final musicKeywords = [
      'bass',
      'groove',
      'beat',
      'melody',
      'rhythm',
      'vocals',
      'production',
      'energy',
      'vibe',
      'tempo',
      'lyrics'
    ];

    for (var keyword in musicKeywords) {
      if (text.contains(keyword)) {
        terms.add(keyword);
      }
    }

    return terms;
  }

  /// Generates a detailed music taste profile from the user's data
  String generateMusicTastePrompt(Map<String, dynamic> profile) {
    final favoriteGenres = List<String>.from(profile['favoriteGenres'] ?? []);
    final dislikedGenres = List<String>.from(profile['dislikedGenres'] ?? []);
    final favoriteArtists = List<String>.from(profile['favoriteArtists'] ?? []);
    final genreWeights =
        Map<String, dynamic>.from(profile['genreWeights'] ?? {});
    final reviews = List<dynamic>.from(profile['reviews'] ?? []);
    final savedTracks = List<String>.from(profile['savedTracks'] ?? []);
    final moodPreferences = profile['moodPreferences'];

    // Analyze reviews
    final reviewAnalysis = analyzeReviews(reviews);

    // Get top weighted genres (0.7 and above)
    final topGenres = genreWeights.entries
        .where((entry) => entry.value >= 0.7)
        .map((entry) => entry.key)
        .toList()
      ..sort((a, b) {
        final aWeight = genreWeights[a] ?? 0;
        final bWeight = genreWeights[b] ?? 0;
        return (bWeight as num).compareTo(aWeight as num);
      });

    // Build the prompt
    final promptBuffer = StringBuffer();

    promptBuffer
        .writeln('Generate music recommendations based on this user profile:');
    promptBuffer.writeln();

    // Primary preferences
    promptBuffer.writeln('STRONGLY PREFERRED GENRES (priority order):');
    for (var genre in topGenres.take(5)) {
      final weight = genreWeights[genre];
      promptBuffer.writeln('- $genre (weight: $weight)');
    }
    promptBuffer.writeln();

    // Favorite artists
    if (favoriteArtists.isNotEmpty) {
      promptBuffer.writeln('FAVORITE ARTISTS:');
      for (var artist in favoriteArtists) {
        promptBuffer.writeln('- $artist');
      }
      promptBuffer.writeln();
    }

    // Disliked genres
    if (dislikedGenres.isNotEmpty) {
      promptBuffer.writeln('AVOID THESE GENRES:');
      promptBuffer.writeln(dislikedGenres.join(', '));
      promptBuffer.writeln();
    }

    // Mood preferences
    if (moodPreferences != null) {
      promptBuffer.writeln('MOOD PREFERENCES:');
      if (moodPreferences is List) {
        promptBuffer.writeln(moodPreferences.join(', '));
      } else if (moodPreferences is String) {
        promptBuffer.writeln(moodPreferences);
      }
      promptBuffer.writeln();
    }

    // Review insights
    if (reviews.isNotEmpty) {
      promptBuffer.writeln('LISTENING PREFERENCES FROM REVIEWS:');
      final lovedKeywords = reviewAnalysis['lovedKeywords'] as List;
      final hatedKeywords = reviewAnalysis['hatedKeywords'] as List;

      if (lovedKeywords.isNotEmpty) {
        promptBuffer.writeln('Loves: ${lovedKeywords.join(', ')}');
      }
      if (hatedKeywords.isNotEmpty) {
        promptBuffer.writeln('Dislikes: ${hatedKeywords.join(', ')}');
      }
      promptBuffer.writeln();
    }

    // Saved tracks as reference
    if (savedTracks.isNotEmpty) {
      promptBuffer.writeln('REFERENCE TRACKS (user has saved):');
      for (var track in savedTracks.take(5)) {
        promptBuffer.writeln('- $track');
      }
      promptBuffer.writeln();
    }

    promptBuffer.writeln('Recommend 10 songs that match this profile.');

    return promptBuffer.toString();
  }

  /// Generates a concise JSON-like summary for API requests
  Map<String, dynamic> generateTasteProfile(Map<String, dynamic> profile) {
    final genreWeights =
        Map<String, dynamic>.from(profile['genreWeights'] ?? {});
    final reviewAnalysis = analyzeReviews(profile['reviews'] ?? []);

    // Get top genres
    final topGenres = genreWeights.entries
        .where((entry) => entry.value >= 0.7)
        .map((entry) => entry.key)
        .toList()
      ..sort((a, b) {
        final aWeight = genreWeights[a] ?? 0;
        final bWeight = genreWeights[b] ?? 0;
        return (bWeight as num).compareTo(aWeight as num);
      });

    return {
      'preferredGenres': topGenres,
      'avoidGenres': profile['dislikedGenres'] ?? [],
      'favoriteArtists': profile['favoriteArtists'] ?? [],
      'moodPreferences': profile['moodPreferences'] ?? [],
      'audioPreferences': {
        'loved': reviewAnalysis['lovedKeywords'],
        'disliked': reviewAnalysis['hatedKeywords'],
      },
      'referenceTracks': (profile['savedTracks'] ?? []).take(5).toList(),
    };
  }

  /// Updates the music profile in Firestore
  Future<void> updateMusicProfile(
      String userId, Map<String, dynamic> updates) async {
    if (_firestore == null) return;
    try {
      await _firestore!
          .collection('users')
          .doc(userId)
          .collection('musicProfile')
          .doc('profile')
          .update({
        ...updates,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating music profile: $e');
      rethrow;
    }
  }

  /// Creates initial music profile if it doesn't exist
  Future<void> createMusicProfile(
      String userId, Map<String, dynamic> initialProfile) async {
    if (_firestore == null) return;
    try {
      await _firestore!
          .collection('users')
          .doc(userId)
          .collection('musicProfile')
          .doc('profile')
          .set({
        ...initialProfile,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error creating music profile: $e');
      rethrow;
    }
  }

  /// Increments listening metrics
  Future<void> trackListeningActivity(String userId, String trackId,
      {bool skipped = false, bool repeated = false}) async {
    if (_firestore == null) return;
    try {
      final updates = <String, dynamic>{};

      if (skipped) {
        updates['skipCounts.$trackId'] = FieldValue.increment(1);
      }

      if (repeated) {
        updates['repeatCounts.$trackId'] = FieldValue.increment(1);
      }

      await _firestore!
          .collection('users')
          .doc(userId)
          .collection('musicProfile')
          .doc('profile')
          .update(updates);
    } catch (e) {
      print('Error tracking listening activity: $e');
      rethrow;
    }
  }

  /// Adds a track to recently played
  Future<void> addToRecentlyPlayed(String userId, String trackId) async {
    if (_firestore == null) return;
    try {
      await _firestore!
          .collection('users')
          .doc(userId)
          .collection('musicProfile')
          .doc('profile')
          .update({
        'recentlyPlayed': FieldValue.arrayUnion([trackId]),
      });
    } catch (e) {
      print('Error adding to recently played: $e');
      rethrow;
    }
  }
}
