import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test_project/Api/api_key.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/utils/scoring_utils.dart';
import 'package:http/http.dart' as http;

/// Service for generating OpenAI embeddings and user taste vectors.
///
/// Concepts from Grainger Ch. 8-10:
///   - Keywords miss meaning. "incredible energy, makes me want to dance" and
///     "great workout vibe, perfect beats" express the same taste but share zero
///     keywords. Embeddings capture this semantic similarity.
///   - We use OpenAI's `text-embedding-3-small` (1536 dims, ~$0.02/1M tokens).
///     A typical review is ~50 tokens, so embedding 100 reviews costs fractions
///     of a cent.
///   - The user's taste vector is the weighted average of their review embeddings
///     (weighted by rating). It is cached in Firestore and refreshed incrementally.
class EmbeddingService {
  static const _embeddingEndpoint = 'https://api.openai.com/v1/embeddings';
  static const _embeddingModel = 'text-embedding-3-small';
  static const int _embeddingDimensions = 1536;
  static const _timeout = Duration(seconds: 20);

  // ─── Generate a single embedding ─────────────────────────────

  /// Generate an embedding vector for [text] using OpenAI.
  ///
  /// Returns a list of [_embeddingDimensions] doubles, or `null` on failure.
  static Future<List<double>?> generateEmbedding(String text) async {
    if (text.trim().isEmpty) return null;
    if (openAIKey.isEmpty) {
      debugPrint('[EMBED] OpenAI key not configured — skipping embedding');
      return null;
    }

    try {
      final response = await http
          .post(
            Uri.parse(_embeddingEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $openAIKey',
            },
            body: jsonEncode({
              'model': _embeddingModel,
              'input': text.length > 8000 ? text.substring(0, 8000) : text,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final embedding = (data['data'][0]['embedding'] as List<dynamic>)
            .map((e) => (e as num).toDouble())
            .toList();
        return embedding;
      } else {
        debugPrint('[EMBED] API error ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[EMBED] Error generating embedding: $e');
      return null;
    }
  }

  // ─── Generate batch embeddings ───────────────────────────────

  /// Generate embeddings for multiple texts in a single API call.
  static Future<List<List<double>?>> generateBatchEmbeddings(
      List<String> texts) async {
    if (texts.isEmpty) return [];
    if (openAIKey.isEmpty) return List.filled(texts.length, null);

    try {
      final cleanTexts =
          texts.map((t) => t.length > 8000 ? t.substring(0, 8000) : t).toList();

      final response = await http
          .post(
            Uri.parse(_embeddingEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $openAIKey',
            },
            body: jsonEncode({
              'model': _embeddingModel,
              'input': cleanTexts,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final embeddings = (data['data'] as List<dynamic>).map((item) {
          return (item['embedding'] as List<dynamic>)
              .map((e) => (e as num).toDouble())
              .toList();
        }).toList();
        return embeddings;
      } else {
        debugPrint(
            '[EMBED] Batch API error ${response.statusCode}: ${response.body}');
        return List.filled(texts.length, null);
      }
    } catch (e) {
      debugPrint('[EMBED] Error generating batch embeddings: $e');
      return List.filled(texts.length, null);
    }
  }

  // ─── Taste Vector Generation ─────────────────────────────────

  /// Generate a taste vector by averaging review embeddings, weighted by rating.
  ///
  /// Higher-rated reviews contribute more to the taste vector. The result
  /// captures what the user *likes* semantically, not just keywords.
  static Future<List<double>?> generateTasteVector(List<Review> reviews) async {
    if (reviews.isEmpty) return null;

    // Build text snippets for embedding
    final textsWithWeights = <MapEntry<String, double>>[];
    for (final review in reviews) {
      final text =
          '${review.artist} - ${review.title}. ${review.review}'.trim();
      if (text.length < 10) continue;

      // Weight by normalized rating (0.0 to 1.0)
      final weight = review.score / 5.0;
      textsWithWeights.add(MapEntry(text, weight));
    }

    if (textsWithWeights.isEmpty) return null;

    // Generate embeddings in batch
    final texts = textsWithWeights.map((e) => e.key).toList();
    final embeddings = await generateBatchEmbeddings(texts);

    // Weighted average
    final tasteVector = List<double>.filled(_embeddingDimensions, 0.0);
    double totalWeight = 0.0;

    for (int i = 0; i < embeddings.length; i++) {
      final embedding = embeddings[i];
      if (embedding == null) continue;

      final weight = textsWithWeights[i].value;
      totalWeight += weight;

      for (int d = 0; d < _embeddingDimensions; d++) {
        tasteVector[d] += embedding[d] * weight;
      }
    }

    if (totalWeight == 0) return null;

    // Normalize
    for (int d = 0; d < _embeddingDimensions; d++) {
      tasteVector[d] /= totalWeight;
    }

    return tasteVector;
  }

  // ─── Taste Vector Caching ────────────────────────────────────

  /// Get or generate the user's taste vector, with Firestore caching.
  ///
  /// The taste vector is cached at `users/{userId}/reviewAnalysis/embeddings`
  /// and only refreshed when new reviews are added (incremental blending).
  static Future<List<double>?> getTasteVector(
    String userId,
    List<Review> reviews, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      // Try to load from cache
      final cached = await _loadCachedTasteVector(userId);
      if (cached != null) {
        debugPrint('[EMBED] Using cached taste vector '
            '(${cached.reviewCount} reviews, dims=${cached.vector.length})');

        // Check if we need incremental update
        if (cached.reviewCount >= reviews.length) {
          return cached.vector;
        }

        // Incremental blend: only embed new reviews and blend with existing
        final newReviews = reviews.take(reviews.length - cached.reviewCount).toList();
        if (newReviews.length <= 5) {
          debugPrint('[EMBED] Incremental update: ${newReviews.length} new reviews');
          final updated =
              await _incrementalBlend(cached.vector, cached.reviewCount, newReviews);
          if (updated != null) {
            await _cacheTasteVector(userId, updated, reviews.length);
            return updated;
          }
        }
        // Fall through to full regeneration if incremental fails
      }
    }

    // Full generation
    debugPrint('[EMBED] Generating full taste vector from ${reviews.length} reviews');
    final vector = await generateTasteVector(reviews);
    if (vector != null) {
      await _cacheTasteVector(userId, vector, reviews.length);
    }
    return vector;
  }

  /// Incrementally blend new review embeddings into the existing taste vector.
  static Future<List<double>?> _incrementalBlend(
    List<double> existingVector,
    int existingCount,
    List<Review> newReviews,
  ) async {
    final newVector = await generateTasteVector(newReviews);
    if (newVector == null) return existingVector;

    // Weighted blend: existing contributes proportionally to its review count
    final totalCount = existingCount + newReviews.length;
    final existingWeight = existingCount / totalCount;
    final newWeight = newReviews.length / totalCount;

    final blended = List<double>.filled(existingVector.length, 0.0);
    for (int i = 0; i < blended.length; i++) {
      blended[i] = existingVector[i] * existingWeight + newVector[i] * newWeight;
    }

    return blended;
  }

  static Future<_CachedTasteVector?> _loadCachedTasteVector(
      String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reviewAnalysis')
          .doc('embeddings')
          .get();

      if (!doc.exists || doc.data() == null) return null;

      final data = doc.data()!;
      final vectorData = data['tasteVector'] as List<dynamic>?;
      final reviewCount = data['reviewCount'] as int? ?? 0;

      if (vectorData == null || vectorData.isEmpty) return null;

      return _CachedTasteVector(
        vector: vectorData.map((e) => (e as num).toDouble()).toList(),
        reviewCount: reviewCount,
      );
    } catch (e) {
      debugPrint('[EMBED] Error loading cached taste vector: $e');
      return null;
    }
  }

  static Future<void> _cacheTasteVector(
    String userId,
    List<double> vector,
    int reviewCount,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reviewAnalysis')
          .doc('embeddings')
          .set({
        'tasteVector': vector,
        'reviewCount': reviewCount,
        'lastUpdated': FieldValue.serverTimestamp(),
        'dimensions': _embeddingDimensions,
        'model': _embeddingModel,
      }, SetOptions(merge: true));

      debugPrint('[EMBED] Cached taste vector ($reviewCount reviews)');
    } catch (e) {
      debugPrint('[EMBED] Error caching taste vector: $e');
    }
  }

  // ─── Candidate Scoring ───────────────────────────────────────

  /// Generate a short description embedding for a candidate recommendation
  /// and compare against the user's taste vector.
  ///
  /// Returns a semantic similarity score in [0.0, 1.0].
  static Future<double> scoreCandidate({
    required List<double> tasteVector,
    required String artist,
    required String track,
    required List<String> genres,
    String album = '',
  }) async {
    final description =
        'Artist: $artist. Track: $track. Album: $album. Genres: ${genres.join(", ")}.';

    final candidateEmbedding = await generateEmbedding(description);
    if (candidateEmbedding == null) return 0.5; // Neutral fallback

    // Cosine similarity maps [-1, 1] → remap to [0, 1]
    final cosine = ScoringUtils.cosineSimilarity(tasteVector, candidateEmbedding);
    return ((cosine + 1.0) / 2.0).clamp(0.0, 1.0);
  }

  /// Batch-score multiple candidates against a taste vector.
  ///
  /// More efficient than calling [scoreCandidate] in a loop because
  /// it uses a single batch embedding call.
  static Future<List<double>> scoreCandidatesBatch({
    required List<double> tasteVector,
    required List<_CandidateInfo> candidates,
  }) async {
    if (candidates.isEmpty) return [];

    final descriptions = candidates.map((c) {
      return 'Artist: ${c.artist}. Track: ${c.track}. '
          'Album: ${c.album}. Genres: ${c.genres.join(", ")}.';
    }).toList();

    final embeddings = await generateBatchEmbeddings(descriptions);

    return embeddings.map((embedding) {
      if (embedding == null) return 0.5;
      final cosine = ScoringUtils.cosineSimilarity(tasteVector, embedding);
      return ((cosine + 1.0) / 2.0).clamp(0.0, 1.0);
    }).toList();
  }

  // ─── Enhanced AI Prompt Descriptors ──────────────────────────

  /// Derive human-readable taste descriptors from the taste vector
  /// by comparing it against a set of genre/mood anchor embeddings.
  ///
  /// This replaces keyword matching in prompt generation with genuine
  /// semantic understanding (Grainger Ch. 8-10).
  static Future<List<String>> deriveTasteDescriptors(
    List<double> tasteVector, {
    int topN = 5,
  }) async {
    // Predefined anchor descriptors spanning the music taste space
    const anchors = [
      'Energetic dance music with heavy bass and electronic beats',
      'Calm acoustic folk with gentle vocals and storytelling',
      'Dark atmospheric hip-hop with deep lyrics and moody production',
      'Upbeat pop music with catchy melodies and polished production',
      'Raw punk rock with aggressive guitars and rebellious energy',
      'Smooth jazz with sophisticated harmonies and improvisation',
      'Emotional R&B with soulful vocals and lush arrangements',
      'Heavy metal with powerful riffs and intense energy',
      'Chill lo-fi beats with relaxed vibes and ambient textures',
      'Classical orchestral music with complex arrangements',
      'Latin rhythms with vibrant percussion and danceable grooves',
      'Indie rock with quirky melodies and experimental sounds',
      'Country music with storytelling and acoustic instrumentation',
      'Psychedelic music with spacey textures and trippy effects',
      'Ambient electronic with ethereal soundscapes',
    ];

    final anchorEmbeddings = await generateBatchEmbeddings(anchors);

    final scores = <MapEntry<String, double>>[];
    for (int i = 0; i < anchors.length; i++) {
      final embedding = anchorEmbeddings[i];
      if (embedding == null) continue;

      final similarity = ScoringUtils.cosineSimilarity(tasteVector, embedding);
      scores.add(MapEntry(anchors[i], similarity));
    }

    scores.sort((a, b) => b.value.compareTo(a.value));
    return scores.take(topN).map((e) => e.key).toList();
  }
}

/// Internal data class for cached taste vectors.
class _CachedTasteVector {
  final List<double> vector;
  final int reviewCount;

  const _CachedTasteVector({
    required this.vector,
    required this.reviewCount,
  });
}

/// Candidate info for batch scoring.
class CandidateInfo {
  final String artist;
  final String track;
  final String album;
  final List<String> genres;

  const CandidateInfo({
    required this.artist,
    required this.track,
    this.album = '',
    this.genres = const [],
  });
}

/// Private alias used internally by EmbeddingService.
typedef _CandidateInfo = CandidateInfo;
