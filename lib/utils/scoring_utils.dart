import 'dart:math' as math;

import 'package:flutter_test_project/services/signal_collection_service.dart';

/// Scoring utilities based on AI-Powered Search (Grainger Ch. 5-7).
///
/// Provides principled similarity metrics, temporal decay, and
/// signal-aggregated relevance scoring to replace hand-tuned weights.
class ScoringUtils {
  // ─── Jaccard Similarity (Grainger Ch. 5) ─────────────────────
  //
  // Principled set-similarity metric:
  //   J(A, B) = |A ∩ B| / |A ∪ B|
  // Returns 0.0 (no overlap) to 1.0 (identical sets).

  /// Jaccard similarity between two sets of strings (case-insensitive).
  static double jaccardSimilarity(Set<String> a, Set<String> b) {
    if (a.isEmpty && b.isEmpty) return 0.0;

    final normA = a.map((s) => s.toLowerCase().trim()).toSet();
    final normB = b.map((s) => s.toLowerCase().trim()).toSet();

    final intersection = normA.intersection(normB).length;
    final union = normA.union(normB).length;

    return union == 0 ? 0.0 : intersection / union;
  }

  /// Multi-dimensional user similarity combining artist, genre, and tag overlap.
  ///
  /// Returns a score in [0.0, 1.0].
  static double combinedUserSimilarity({
    required Set<String> userArtists,
    required Set<String> otherArtists,
    required Set<String> userGenres,
    required Set<String> otherGenres,
    Set<String> userTags = const {},
    Set<String> otherTags = const {},
    double artistWeight = 0.5,
    double genreWeight = 0.3,
    double tagWeight = 0.2,
  }) {
    final artistSim = jaccardSimilarity(userArtists, otherArtists);
    final genreSim = jaccardSimilarity(userGenres, otherGenres);
    final tagSim = jaccardSimilarity(userTags, otherTags);

    return (artistSim * artistWeight) +
        (genreSim * genreWeight) +
        (tagSim * tagWeight);
  }

  // ─── Temporal Decay (Grainger Ch. 5) ─────────────────────────
  //
  // Recency is the strongest relevance signal. Recent interactions
  // matter exponentially more than old ones.
  //   decay(age) = exp(-age_days / halfLife)

  /// Exponential temporal decay with configurable half-life (days).
  ///
  /// [timestamp] is the event time. [halfLifeDays] controls how quickly
  /// old events lose influence (default 30 days).
  /// Returns a multiplier in (0.0, 1.0].
  static double temporalDecay(DateTime timestamp, {double halfLifeDays = 30.0}) {
    final daysSince = DateTime.now().difference(timestamp).inHours / 24.0;
    if (daysSince <= 0) return 1.0;
    return math.exp(-daysSince / halfLifeDays);
  }

  // ─── Cosine Similarity (for embeddings — Phase 3) ────────────
  //
  // Measures angle between two vectors regardless of magnitude.

  /// Cosine similarity between two vectors of equal length.
  /// Returns a value in [-1.0, 1.0]. Higher = more similar.
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0.0;

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    final denominator = math.sqrt(normA) * math.sqrt(normB);
    return denominator == 0.0 ? 0.0 : dotProduct / denominator;
  }

  // ─── Signal-Aggregated Scoring (Grainger Ch. 5-7) ────────────
  //
  // Instead of hand-tuned weights per feature, we aggregate actual
  // user interaction signals. Each signal type has a base strength
  // that is multiplied by temporal decay and context weight.

  /// Compute an aggregate relevance score for a candidate track
  /// based on the user's interaction signals.
  ///
  /// For each signal that matches the candidate (by artist or genre),
  /// we add: signalStrength(type) × temporalDecay(age) × contextWeight.
  ///
  /// [adjustedWeights] allows overriding default signal weights (from
  /// the feedback loop in Phase 4).
  static double signalAggregatedScore({
    required String candidateArtist,
    required List<String> candidateGenres,
    required List<UserSignal> signals,
    Map<String, double>? adjustedWeights,
  }) {
    if (signals.isEmpty) return 0.5; // No signals — neutral score

    final weights = adjustedWeights ?? SignalCollectionService.signalWeights;
    final artistLower = candidateArtist.toLowerCase().trim();
    final genresLower = candidateGenres.map((g) => g.toLowerCase().trim()).toSet();

    double score = 0.0;
    int matchCount = 0;

    for (final signal in signals) {
      // Check if this signal is relevant to the candidate
      final artistMatch = signal.targetArtist.toLowerCase().trim() == artistLower;
      final genreMatch = signal.targetGenres
          .any((g) => genresLower.contains(g.toLowerCase().trim()));

      if (!artistMatch && !genreMatch) continue;

      final strength = weights[signal.type] ?? 0.0;
      final decay = temporalDecay(signal.timestamp);

      // Artist matches are stronger than genre matches
      final matchMultiplier = artistMatch ? 1.0 : 0.6;

      score += strength * decay * matchMultiplier;
      matchCount++;
    }

    // Normalize: map to [0, 1] range using sigmoid-like scaling
    if (matchCount == 0) return 0.5;
    return (0.5 + (score / (1.0 + score.abs()))).clamp(0.0, 1.0);
  }

  // ─── Combined Final Score ────────────────────────────────────

  /// Compute the final recommendation relevance score by combining
  /// signal-aggregated, collaborative, semantic, and novelty scores.
  ///
  /// Default weights: signals=0.3, collab=0.2, semantic=0.3, novelty=0.2
  /// These can be overridden by the feedback loop (Phase 4).
  static double finalRelevanceScore({
    required double signalScore,
    required double collaborativeScore,
    double semanticScore = 0.5,
    required double noveltyScore,
    double diversityBonus = 0.0,
    Map<String, double>? componentWeights,
  }) {
    final w = componentWeights ??
        const {
          'signals': 0.30,
          'collaborative': 0.20,
          'semantic': 0.30,
          'novelty': 0.20,
        };

    return ((signalScore * (w['signals'] ?? 0.3)) +
            (collaborativeScore * (w['collaborative'] ?? 0.2)) +
            (semanticScore * (w['semantic'] ?? 0.3)) +
            (noveltyScore * (w['novelty'] ?? 0.2)) +
            (diversityBonus * 0.1))
        .clamp(0.0, 1.0);
  }
}
