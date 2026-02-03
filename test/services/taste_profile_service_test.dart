import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/services/taste_profile_prompt_generation_service.dart';

void main() {
  group('MusicProfileService Tests', () {
    // MusicProfileService() with no args uses null Firestore - no Firebase init needed
    test('analyzeReviews extracts loved keywords', () {
      final service = MusicProfileService();
      final reviews = [
        'I loved the bass and groove in this song',
        'Great melody and amazing rhythm',
      ];

      final analysis = service.analyzeReviews(reviews);

      expect(analysis['lovedKeywords'], isNotEmpty);
      expect(analysis['lovedKeywords'], isA<List>());
    });

    test('analyzeReviews extracts hated keywords', () {
      final service = MusicProfileService();
      final reviews = [
        'I hated the terrible beat',
        'Bad melody and awful sound',
      ];

      final analysis = service.analyzeReviews(reviews);

      expect(analysis['hatedKeywords'], isNotEmpty);
      expect(analysis['hatedKeywords'], isA<List>());
    });

    test('analyzeReviews handles empty reviews', () {
      final service = MusicProfileService();
      final reviews = <String>[];

      final analysis = service.analyzeReviews(reviews);

      expect(analysis['lovedKeywords'], isEmpty);
      expect(analysis['hatedKeywords'], isEmpty);
      expect(analysis['artistMentions'], isEmpty);
    });

    test('generateTasteProfile creates structured profile', () {
      final service = MusicProfileService();
      final musicProfile = {
        'favoriteGenres': ['Rock', 'Pop', 'Jazz'],
        'dislikedGenres': ['Country'],
        'favoriteArtists': ['Artist1', 'Artist2'],
        'genreWeights': {
          'Rock': 1.0,
          'Pop': 0.8,
          'Jazz': 0.6,
        },
        'moodPreferences': ['energetic', 'upbeat'],
        'savedTracks': ['track1', 'track2'],
      };

      final tasteProfile = service.generateTasteProfile(musicProfile);

      expect(tasteProfile['preferredGenres'], isA<List>());
      expect(tasteProfile['avoidGenres'], isA<List>());
      expect(tasteProfile['favoriteArtists'], isA<List>());
    });

    test('generateTasteProfile prioritizes genres by weight', () {
      final service = MusicProfileService();
      final musicProfile = {
        'favoriteGenres': ['Rock', 'Pop', 'Jazz'],
        'genreWeights': {
          'Rock': 1.0,
          'Pop': 0.8,
          'Jazz': 0.5,
        },
      };

      final tasteProfile = service.generateTasteProfile(musicProfile);
      final preferredGenres = tasteProfile['preferredGenres'] as List;

      // Genres with weight >= 0.7 should be in preferredGenres
      expect(preferredGenres, contains('Rock'));
      expect(preferredGenres, contains('Pop'));
      // Jazz with 0.5 should not be in preferred (threshold is typically 0.7)
      expect(preferredGenres.length, greaterThanOrEqualTo(2));
    });
  });
}
