import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test_project/services/signal_collection_service.dart';

/// Service for tracking recommendation outcomes and adjusting signal weights.
///
/// Concepts from Grainger Ch. 11-13:
///   - A recommendation system that cannot learn from its own mistakes is static.
///   - Track whether recommendations led to positive reviews, negative reviews,
///     clicks without reviews, or were ignored entirely.
///   - Use precision-based weight calibration: for each signal type, measure how
///     often it predicted a positive outcome. Adjust weights accordingly.
///   - This is a lightweight client-side version of Learning to Rank.
///
/// Firestore structure: users/{userId}/recommendationOutcomes/{outcomeId}
class RecommendationOutcomeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── Outcome types ───────────────────────────────────────────

  static const String reviewedPositive = 'reviewed_positive';
  static const String reviewedNegative = 'reviewed_negative';
  static const String clickedNoReview = 'clicked_no_review';
  static const String ignored = 'ignored';

  // ─── Default signal weights (starting point) ────────────────

  static const Map<String, double> defaultComponentWeights = {
    'signals': 0.30,
    'collaborative': 0.20,
    'semantic': 0.30,
    'novelty': 0.20,
  };

  // ─── Logging recommendations when shown ──────────────────────

  /// Log that a set of recommendations was shown to the user.
  ///
  /// Call this when recommendations are displayed so we can later
  /// check if the user interacted with them.
  static Future<void> logRecommendationsShown({
    required List<RecommendationRecord> recommendations,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final batch = _firestore.batch();
      final outcomesRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('recommendationOutcomes');

      for (final rec in recommendations) {
        batch.set(outcomesRef.doc(), {
          'recommendedTrack': rec.track,
          'recommendedArtist': rec.artist,
          'recommendationSource': rec.source,
          'recommendedAt': FieldValue.serverTimestamp(),
          'outcome': 'pending', // Will be updated when we detect interaction
          'userRating': null,
          'signalWeightsAtTime': rec.weightsSnapshot,
        });
      }

      await batch.commit();
      debugPrint('[OUTCOMES] Logged ${recommendations.length} shown recommendations');
    } catch (e) {
      debugPrint('[OUTCOMES] Error logging shown recommendations: $e');
    }
  }

  // ─── Recording outcomes ──────────────────────────────────────

  /// Check if a newly submitted review matches any pending recommendation.
  ///
  /// Call this after a review is submitted (from review_analysis_service
  /// or the review submission flow).
  static Future<void> checkAndRecordOutcome({
    required String artist,
    required String track,
    required double rating,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      // Find pending outcomes that match this artist+track
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('recommendationOutcomes')
          .where('outcome', isEqualTo: 'pending')
          .limit(50)
          .get();

      final artistLower = artist.toLowerCase().trim();
      final trackLower = track.toLowerCase().trim();

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final recArtist =
            (data['recommendedArtist'] as String? ?? '').toLowerCase().trim();
        final recTrack =
            (data['recommendedTrack'] as String? ?? '').toLowerCase().trim();

        // Fuzzy match: artist contains/matches and track contains/matches
        final artistMatch = recArtist.contains(artistLower) ||
            artistLower.contains(recArtist);
        final trackMatch =
            recTrack.contains(trackLower) || trackLower.contains(recTrack);

        if (artistMatch && trackMatch) {
          final outcome = rating >= 3.5 ? reviewedPositive : reviewedNegative;

          await doc.reference.update({
            'outcome': outcome,
            'userRating': rating,
            'resolvedAt': FieldValue.serverTimestamp(),
          });

          debugPrint('[OUTCOMES] Recorded outcome: $outcome '
              'for "$track" by "$artist" (rating: $rating)');

          // Check if we should recalibrate weights
          await _maybeRecalibrateWeights(userId);
          return;
        }
      }
    } catch (e) {
      debugPrint('[OUTCOMES] Error checking outcome: $e');
    }
  }

  /// Record a click-without-review outcome for recommendations the user
  /// clicked but never reviewed (detected after a timeout period).
  static Future<void> resolveStaleOutcomes() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final staleThreshold =
          DateTime.now().subtract(const Duration(days: 7));

      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('recommendationOutcomes')
          .where('outcome', isEqualTo: 'pending')
          .limit(50)
          .get();

      final batch = _firestore.batch();
      int resolved = 0;

      for (final doc in querySnapshot.docs) {
        final recAt = (doc.data()['recommendedAt'] as Timestamp?)?.toDate();
        if (recAt != null && recAt.isBefore(staleThreshold)) {
          // Check if user clicked this recommendation (via signals)
          final recTrack =
              (doc.data()['recommendedTrack'] as String? ?? '').toLowerCase();
          final recArtist =
              (doc.data()['recommendedArtist'] as String? ?? '').toLowerCase();

          // Simple heuristic: if there's a rec_click signal for this track,
          // mark as clicked_no_review; otherwise ignored
          final signals =
              await SignalCollectionService.getRecentSignals(limit: 100);
          final wasClicked = signals.any((s) =>
              s.type == SignalCollectionService.recClick &&
              s.targetTrack.toLowerCase().contains(recTrack) &&
              s.targetArtist.toLowerCase().contains(recArtist));

          batch.update(doc.reference, {
            'outcome': wasClicked ? clickedNoReview : ignored,
            'resolvedAt': FieldValue.serverTimestamp(),
          });
          resolved++;
        }
      }

      if (resolved > 0) {
        await batch.commit();
        debugPrint('[OUTCOMES] Resolved $resolved stale outcomes');
        await _maybeRecalibrateWeights(userId);
      }
    } catch (e) {
      debugPrint('[OUTCOMES] Error resolving stale outcomes: $e');
    }
  }

  // ─── Weight Calibration (Grainger Ch. 11-13) ────────────────

  /// Recalibrate signal/component weights based on outcome precision.
  ///
  /// Triggered every 10 new resolved outcomes. For each recommendation source
  /// and signal type, we compute precision (fraction of positive outcomes)
  /// and adjust weights:
  ///   adjustedWeight = baseWeight * (0.5 + precision)
  static Future<void> _maybeRecalibrateWeights(String userId) async {
    try {
      // Count resolved outcomes since last calibration
      final metaDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('recommendationOutcomes')
          .doc('_meta')
          .get();

      final lastCalibratedCount =
          metaDoc.exists ? (metaDoc.data()?['lastCalibratedCount'] as int? ?? 0) : 0;

      final totalResolved = await _firestore
          .collection('users')
          .doc(userId)
          .collection('recommendationOutcomes')
          .where('outcome', isNotEqualTo: 'pending')
          .count()
          .get();

      final resolvedCount = totalResolved.count ?? 0;
      if (resolvedCount - lastCalibratedCount < 10) {
        return; // Not enough new outcomes to recalibrate
      }

      debugPrint('[OUTCOMES] Recalibrating weights '
          '($resolvedCount resolved, last calibrated at $lastCalibratedCount)');

      // Fetch all resolved outcomes
      final outcomesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('recommendationOutcomes')
          .where('outcome', isNotEqualTo: 'pending')
          .limit(100)
          .get();

      // Calculate precision per source
      final sourcePrecision = <String, _PrecisionTracker>{};

      for (final doc in outcomesSnapshot.docs) {
        final data = doc.data();
        final source = data['recommendationSource'] as String? ?? 'unknown';
        final outcome = data['outcome'] as String? ?? '';

        sourcePrecision.putIfAbsent(source, () => _PrecisionTracker());
        sourcePrecision[source]!.total++;

        if (outcome == reviewedPositive) {
          sourcePrecision[source]!.positive++;
        }
      }

      // Compute adjusted weights
      final adjustedWeights = Map<String, double>.from(defaultComponentWeights);

      // Map source names to component weight keys
      const sourceToComponent = {
        'ai': 'signals',
        'collaborative': 'collaborative',
        'spotify': 'novelty',
      };

      for (final entry in sourcePrecision.entries) {
        final componentKey = sourceToComponent[entry.key];
        if (componentKey == null) continue;

        final precision = entry.value.precision;
        final baseWeight = defaultComponentWeights[componentKey] ?? 0.2;
        adjustedWeights[componentKey] = baseWeight * (0.5 + precision);

        debugPrint('[OUTCOMES] Source "${entry.key}" precision: '
            '${precision.toStringAsFixed(2)} '
            '(${entry.value.positive}/${entry.value.total}) '
            '→ weight: ${adjustedWeights[componentKey]!.toStringAsFixed(3)}');
      }

      // Normalize weights so they sum to ~1.0
      final total = adjustedWeights.values.fold<double>(0.0, (s, w) => s + w);
      if (total > 0) {
        for (final key in adjustedWeights.keys) {
          adjustedWeights[key] = adjustedWeights[key]! / total;
        }
      }

      // Persist adjusted weights and calibration metadata
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('recommendationOutcomes')
          .doc('_meta')
          .set({
        'adjustedWeights': adjustedWeights,
        'lastCalibratedCount': resolvedCount,
        'lastCalibratedAt': FieldValue.serverTimestamp(),
        'sourcePrecision': sourcePrecision.map(
          (k, v) => MapEntry(k, {
            'positive': v.positive,
            'total': v.total,
            'precision': v.precision,
          }),
        ),
      }, SetOptions(merge: true));

      debugPrint('[OUTCOMES] Weights recalibrated and persisted');
    } catch (e) {
      debugPrint('[OUTCOMES] Error recalibrating weights: $e');
    }
  }

  // ─── Retrieve adjusted weights ───────────────────────────────

  /// Get the current adjusted component weights for scoring.
  ///
  /// Returns the feedback-calibrated weights if available, otherwise
  /// falls back to defaults.
  static Future<Map<String, double>> getAdjustedWeights() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return Map.from(defaultComponentWeights);

    try {
      final metaDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('recommendationOutcomes')
          .doc('_meta')
          .get();

      if (metaDoc.exists && metaDoc.data()?['adjustedWeights'] != null) {
        final weights = Map<String, dynamic>.from(
            metaDoc.data()!['adjustedWeights'] as Map);
        return weights
            .map((k, v) => MapEntry(k, (v as num).toDouble()));
      }
    } catch (e) {
      debugPrint('[OUTCOMES] Error fetching adjusted weights: $e');
    }

    return Map.from(defaultComponentWeights);
  }

  // ─── Prompt effectiveness tracking ───────────────────────────

  /// Get effectiveness scores per recommendation source.
  ///
  /// Used to refine AI prompts: if collaborative recs consistently
  /// get low ratings, reduce their influence in the prompt.
  static Future<Map<String, double>> getSourceEffectiveness() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return {};

    try {
      final metaDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('recommendationOutcomes')
          .doc('_meta')
          .get();

      if (metaDoc.exists && metaDoc.data()?['sourcePrecision'] != null) {
        final precisionData = Map<String, dynamic>.from(
            metaDoc.data()!['sourcePrecision'] as Map);
        return precisionData.map((k, v) {
          final data = v as Map<String, dynamic>;
          return MapEntry(k, (data['precision'] as num?)?.toDouble() ?? 0.5);
        });
      }
    } catch (e) {
      debugPrint('[OUTCOMES] Error fetching source effectiveness: $e');
    }

    return {};
  }
}

/// A recommendation record for logging when recommendations are shown.
class RecommendationRecord {
  final String track;
  final String artist;
  final String source; // "ai", "collaborative", "spotify"
  final Map<String, double> weightsSnapshot;

  const RecommendationRecord({
    required this.track,
    required this.artist,
    required this.source,
    this.weightsSnapshot = const {},
  });
}

/// Internal precision tracker for weight calibration.
class _PrecisionTracker {
  int positive = 0;
  int total = 0;

  double get precision => total == 0 ? 0.5 : positive / total;
}
