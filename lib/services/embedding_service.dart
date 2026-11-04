import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/utils/scoring_utils.dart';

/// User taste vectors built from review embeddings.
///
/// Embedding generation is disabled in the app (see below), so taste vectors
/// come only from embeddings already cached in Firestore; otherwise callers
/// get their neutral fallback.
///
/// Concepts from Grainger Ch. 8-10:
///   - Keywords miss meaning. "incredible energy, makes me want to dance" and
///     "great workout vibe, perfect beats" express the same taste but share zero
///     keywords. Embeddings capture this semantic similarity.
///   - The user's taste vector is the weighted average of their review embeddings
///     (weighted by rating). It is cached in Firestore and refreshed incrementally.
class EmbeddingService {
  /// Model name stored with cached taste vectors written by earlier versions.
  static const _embeddingModel = 'text-embedding-3-large';

  // ─── Embedding generation (disabled in the app) ───────────────

  // The app must never call a paid AI API: anything in a --dart-define ships
  // in the public web bundle (see CLAUDE.md). Embeddings are computed
  // server-side in functions/. These keep their signatures so callers fall
  // back the same way they did when no key was configured.

  /// Always `null`: embeddings are not generated in the app.
  static Future<List<double>?> generateEmbedding(String text) async => null;

  /// One `null` per text: embeddings are not generated in the app.
  static Future<List<List<double>?>> generateBatchEmbeddings(
          List<String> texts) async =>
      List<List<double>?>.filled(texts.length, null);

  /// Always `null`: callers treat this as "no embeddings available".
  static Future<_BatchEmbeddingResult?> _generateBatchEmbeddingsResolved(
          List<String> texts) async =>
      null;

  // ─── Taste Vector Generation ─────────────────────────────────

  /// Generate a taste vector by averaging review embeddings, weighted by rating.
  ///
  /// Higher-rated reviews contribute more to the taste vector. The result
  /// captures what the user *likes* semantically, not just keywords.
  static Future<List<double>?> generateTasteVector(
    List<Review> reviews, {
    TasteEmbeddingMetadata? metadata,
  }) async {
    final result = await _generateTasteVectorResult(
      reviews,
      metadata: metadata,
    );
    return result?.vector;
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
    TasteEmbeddingMetadata? metadata,
  }) async {
    final metadataSignature = metadata?.signature ?? 'none';
    final allowIncrementalUpdate = metadata == null || metadata.isEmpty;

    if (!forceRefresh) {
      // Try to load from cache
      final cached = await _loadCachedTasteVector(userId);
      if (cached != null) {
        final cacheModelSupported = cached.model == _embeddingModel;
        final metadataMatches = cached.metadataSignature == metadataSignature;
        final dimensionsMatch = cached.dimensions == cached.vector.length;

        if (!cacheModelSupported || !metadataMatches || !dimensionsMatch) {
          debugPrint(
            '[EMBED] Cached vector is stale '
            '(model=${cached.model}, dims=${cached.dimensions}, '
            'metadataMatch=$metadataMatches) — regenerating',
          );
        } else {
          debugPrint('[EMBED] Using cached taste vector '
              '(${cached.reviewCount} reviews, dims=${cached.vector.length}, model=${cached.model})');

          // Check if we need incremental update
          if (cached.reviewCount >= reviews.length) {
            return cached.vector;
          }

          // Incremental blend: only embed new reviews and blend with existing.
          // Disabled when metadata is included because the metadata context must
          // be re-applied uniformly across the full corpus.
          final newReviews =
              reviews.take(reviews.length - cached.reviewCount).toList();
          if (allowIncrementalUpdate && newReviews.length <= 5) {
            debugPrint(
              '[EMBED] Incremental update: ${newReviews.length} new reviews',
            );
            final updated = await _incrementalBlend(
              cached.vector,
              cached.reviewCount,
              newReviews,
              existingModel:
                  cached.model.isEmpty ? _embeddingModel : cached.model,
              metadata: metadata,
            );
            if (updated != null) {
              await _cacheTasteVector(
                userId,
                updated.vector,
                reviews.length,
                model: updated.model,
                metadataSignature: metadataSignature,
              );
              return updated.vector;
            }
          }
          // Fall through to full regeneration if incremental fails
        }
      }
    }

    // Full generation
    debugPrint(
        '[EMBED] Generating full taste vector from ${reviews.length} reviews');
    final result = await _generateTasteVectorResult(
      reviews,
      metadata: metadata,
    );
    if (result != null) {
      await _cacheTasteVector(
        userId,
        result.vector,
        reviews.length,
        model: result.model,
        metadataSignature: metadataSignature,
      );
    }
    return result?.vector;
  }

  /// Incrementally blend new review embeddings into the existing taste vector.
  static Future<_TasteVectorBuildResult?> _incrementalBlend(
    List<double> existingVector,
    int existingCount,
    List<Review> newReviews, {
    required String existingModel,
    TasteEmbeddingMetadata? metadata,
  }) async {
    final newResult = await _generateTasteVectorResult(
      newReviews,
      metadata: metadata,
    );
    if (newResult == null) {
      return _TasteVectorBuildResult(
        vector: existingVector,
        model: existingModel,
        dimensions: existingVector.length,
      );
    }

    final newVector = newResult.vector;
    if (newVector.length != existingVector.length) {
      // Mixed dimensions cannot be blended safely.
      return null;
    }

    // Weighted blend: existing contributes proportionally to its review count
    final totalCount = existingCount + newReviews.length;
    final existingWeight = existingCount / totalCount;
    final newWeight = newReviews.length / totalCount;

    final blended = List<double>.filled(existingVector.length, 0.0);
    for (int i = 0; i < blended.length; i++) {
      blended[i] =
          existingVector[i] * existingWeight + newVector[i] * newWeight;
    }

    return _TasteVectorBuildResult(
      vector: blended,
      model: newResult.model,
      dimensions: blended.length,
    );
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
      final dimensions =
          (data['dimensions'] as num?)?.toInt() ?? vectorData?.length ?? 0;
      final model = (data['model'] as String?)?.trim() ?? '';
      final metadataSignature =
          (data['metadataSignature'] as String?)?.trim() ?? 'none';

      if (vectorData == null || vectorData.isEmpty) return null;

      return _CachedTasteVector(
        vector: vectorData.map((e) => (e as num).toDouble()).toList(),
        reviewCount: reviewCount,
        dimensions: dimensions,
        model: model,
        metadataSignature: metadataSignature,
      );
    } catch (e) {
      debugPrint('[EMBED] Error loading cached taste vector: $e');
      return null;
    }
  }

  static Future<void> _cacheTasteVector(
    String userId,
    List<double> vector,
    int reviewCount, {
    required String model,
    required String metadataSignature,
  }) async {
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
        'dimensions': vector.length,
        'model': model,
        'metadataSignature': metadataSignature,
      }, SetOptions(merge: true));

      debugPrint('[EMBED] Cached taste vector '
          '($reviewCount reviews, model=$model, dims=${vector.length})');
    } catch (e) {
      debugPrint('[EMBED] Error caching taste vector: $e');
    }
  }

  static Future<_TasteVectorBuildResult?> _generateTasteVectorResult(
    List<Review> reviews, {
    TasteEmbeddingMetadata? metadata,
  }) async {
    final inputs = _buildTasteVectorInputs(reviews, metadata: metadata);
    if (inputs == null) return null;

    final batchResult = await _generateBatchEmbeddingsResolved(inputs.texts);
    if (batchResult == null) return null;

    final tasteVector = _computeWeightedTasteVector(
      embeddings: batchResult.embeddings,
      weights: inputs.weights,
    );
    if (tasteVector == null) return null;

    return _TasteVectorBuildResult(
      vector: tasteVector,
      model: batchResult.model,
      dimensions: tasteVector.length,
    );
  }

  static _TasteVectorInputs? _buildTasteVectorInputs(
    List<Review> reviews, {
    TasteEmbeddingMetadata? metadata,
  }) {
    if (reviews.isEmpty) return null;

    final metadataContext = metadata?.toEmbeddingContext() ?? '';
    final texts = <String>[];
    final weights = <double>[];

    for (final review in reviews) {
      final reviewText = _buildReviewEmbeddingText(
        review,
        metadataContext: metadataContext,
      );
      if (reviewText.length < 10) continue;

      texts.add(reviewText);
      // Weight by normalized rating (0.0 to 1.0), with a floor so very low
      // ratings still contribute to "what to avoid".
      weights.add((review.score / 5.0).clamp(0.2, 1.0).toDouble());
    }

    if (texts.isEmpty) return null;

    if (metadataContext.isNotEmpty) {
      texts.add('User Spotify taste context: $metadataContext');
      weights.add(0.8);
    }

    return _TasteVectorInputs(texts: texts, weights: weights);
  }

  static List<double>? _computeWeightedTasteVector({
    required List<List<double>?> embeddings,
    required List<double> weights,
  }) {
    if (embeddings.isEmpty ||
        weights.isEmpty ||
        embeddings.length != weights.length) {
      return null;
    }

    List<double>? tasteVector;
    double totalWeight = 0.0;

    for (int i = 0; i < embeddings.length; i++) {
      final embedding = embeddings[i];
      if (embedding == null || embedding.isEmpty) continue;

      if (tasteVector == null) {
        tasteVector = List<double>.filled(embedding.length, 0.0);
      }
      if (embedding.length != tasteVector.length) {
        debugPrint(
          '[EMBED] Skipping embedding with unexpected dimensions '
          '(${embedding.length}, expected ${tasteVector.length})',
        );
        continue;
      }

      final weight = weights[i];
      totalWeight += weight;
      for (int d = 0; d < tasteVector.length; d++) {
        tasteVector[d] += embedding[d] * weight;
      }
    }

    if (tasteVector == null || totalWeight == 0) {
      return null;
    }

    for (int d = 0; d < tasteVector.length; d++) {
      tasteVector[d] /= totalWeight;
    }

    return tasteVector;
  }

  static String _buildReviewEmbeddingText(
    Review review, {
    required String metadataContext,
  }) {
    final genres = review.genres == null || review.genres!.isEmpty
        ? ''
        : ' Genres: ${review.genres!.join(", ")}.';
    final base =
        'Artist: ${review.artist}. Track: ${review.title}. Rating: ${review.score}/5.$genres Review: ${review.review}';
    if (metadataContext.isEmpty) {
      return base.trim();
    }
    return '$base Spotify context: $metadataContext'.trim();
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
    final cosine =
        ScoringUtils.cosineSimilarity(tasteVector, candidateEmbedding);
    return ((cosine + 1.0) / 2.0).clamp(0.0, 1.0);
  }

  /// Batch-score multiple candidates against a taste vector.
  ///
  /// More efficient than calling [scoreCandidate] in a loop because
  /// it uses a single batch embedding call.
  static Future<List<double>> scoreCandidatesBatch({
    required List<double> tasteVector,
    required List<CandidateInfo> candidates,
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

  /// Scores candidates while reusing a cached taste vector when possible and
  /// falling back to a single combined embedding batch when regeneration is
  /// required.
  ///
  /// This avoids separate "taste vector" and "candidate scoring" embedding
  /// API calls on cache misses.
  static Future<List<double>> scoreCandidatesWithUserTaste({
    required String userId,
    required List<Review> reviews,
    required List<CandidateInfo> candidates,
    TasteEmbeddingMetadata? metadata,
  }) async {
    if (candidates.isEmpty) return [];

    final metadataSignature = metadata?.signature ?? 'none';
    final cached = await _loadCachedTasteVector(userId);

    final canUseCached = cached != null &&
        cached.model == _embeddingModel &&
        cached.metadataSignature == metadataSignature &&
        cached.dimensions == cached.vector.length &&
        cached.reviewCount >= reviews.length;

    if (canUseCached) {
      return scoreCandidatesBatch(
        tasteVector: cached.vector,
        candidates: candidates,
      );
    }

    final inputs = _buildTasteVectorInputs(reviews, metadata: metadata);
    if (inputs == null) {
      return List<double>.filled(candidates.length, 0.5);
    }

    final candidateDescriptions = candidates
        .map(
          (c) =>
              'Artist: ${c.artist}. Track: ${c.track}. Album: ${c.album}. Genres: ${c.genres.join(", ")}.',
        )
        .toList();
    final combinedTexts = <String>[
      ...inputs.texts,
      ...candidateDescriptions,
    ];

    final batchResult = await _generateBatchEmbeddingsResolved(combinedTexts);
    if (batchResult == null) {
      return List<double>.filled(candidates.length, 0.5);
    }

    final tasteEmbeddings =
        batchResult.embeddings.take(inputs.texts.length).toList();
    final candidateEmbeddings =
        batchResult.embeddings.skip(inputs.texts.length).toList();
    final tasteVector = _computeWeightedTasteVector(
      embeddings: tasteEmbeddings,
      weights: inputs.weights,
    );
    if (tasteVector == null) {
      return List<double>.filled(candidates.length, 0.5);
    }

    await _cacheTasteVector(
      userId,
      tasteVector,
      reviews.length,
      model: batchResult.model,
      metadataSignature: metadataSignature,
    );

    return candidateEmbeddings.map((embedding) {
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
  final int dimensions;
  final String model;
  final String metadataSignature;

  const _CachedTasteVector({
    required this.vector,
    required this.reviewCount,
    required this.dimensions,
    required this.model,
    required this.metadataSignature,
  });
}

class _BatchEmbeddingResult {
  final String model;
  final List<List<double>?> embeddings;

  const _BatchEmbeddingResult({
    required this.model,
    required this.embeddings,
  });
}

class _TasteVectorBuildResult {
  final List<double> vector;
  final String model;
  final int dimensions;

  const _TasteVectorBuildResult({
    required this.vector,
    required this.model,
    required this.dimensions,
  });
}

class _TasteVectorInputs {
  final List<String> texts;
  final List<double> weights;

  const _TasteVectorInputs({
    required this.texts,
    required this.weights,
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

/// Additional Spotify-derived metadata that can be fused into the user's
/// taste embedding input for higher-fidelity personalization.
class TasteEmbeddingMetadata {
  final List<String> topTracks;
  final List<String> savedArtists;
  final List<String> playlistNames;
  final List<String> recentTrackContexts;

  const TasteEmbeddingMetadata({
    this.topTracks = const [],
    this.savedArtists = const [],
    this.playlistNames = const [],
    this.recentTrackContexts = const [],
  });

  bool get isEmpty =>
      topTracks.isEmpty &&
      savedArtists.isEmpty &&
      playlistNames.isEmpty &&
      recentTrackContexts.isEmpty;

  String get signature {
    final payload = <String, List<String>>{
      'topTracks': _normalizeAndLimit(topTracks, 12),
      'savedArtists': _normalizeAndLimit(savedArtists, 12),
      'playlistNames': _normalizeAndLimit(playlistNames, 12),
      'recentTrackContexts': _normalizeAndLimit(recentTrackContexts, 16),
    };
    return jsonEncode(payload);
  }

  String toEmbeddingContext() {
    if (isEmpty) return '';

    final sections = <String>[];

    final tracks = _normalizeAndLimit(topTracks, 10);
    if (tracks.isNotEmpty) {
      sections.add('Top tracks: ${tracks.join(", ")}.');
    }

    final artists = _normalizeAndLimit(savedArtists, 10);
    if (artists.isNotEmpty) {
      sections.add('Saved artists: ${artists.join(", ")}.');
    }

    final playlists = _normalizeAndLimit(playlistNames, 8);
    if (playlists.isNotEmpty) {
      sections.add('Playlist themes: ${playlists.join(", ")}.');
    }

    final contexts = _normalizeAndLimit(recentTrackContexts, 10);
    if (contexts.isNotEmpty) {
      sections.add('Recent listening patterns: ${contexts.join(", ")}.');
    }

    return sections.join(' ');
  }

  static List<String> _normalizeAndLimit(List<String> values, int maxItems) {
    if (values.isEmpty || maxItems <= 0) return const <String>[];
    final seen = <String>{};
    final output = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      final normalized = trimmed.toLowerCase();
      if (!seen.add(normalized)) continue;
      output.add(trimmed);
      if (output.length >= maxItems) break;
    }
    return output;
  }
}
