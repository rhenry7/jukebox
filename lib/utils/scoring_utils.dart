import 'dart:math' as math;

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

  // ─── Signal-Aggregated Scoring (Grainger Ch. 5-7) ────────────
  //
  // Instead of hand-tuned weights per feature, we aggregate actual
  // user interaction signals. Each signal type has a base strength
  // that is multiplied by temporal decay and context weight.

  // ─── Combined Final Score ────────────────────────────────────

}
