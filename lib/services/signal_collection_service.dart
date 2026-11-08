import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Lightweight fire-and-forget service for collecting user interaction signals.
///
/// Every user action is a signal (Grainger Ch. 3-4):
///   - Explicit signals (reviews, ratings) are high-quality but sparse.
///   - Implicit signals (clicks, dismissals, searches) are noisy but abundant.
///   - Combining both builds a richer picture of user preferences.
///
/// Firestore structure: users/{userId}/signals/{signalId}
class SignalCollectionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── Signal types ─────────────────────────────────────────────

  static const String recClick = 'rec_click';
  static const String recDismiss = 'rec_dismiss';
  static const String searchQuery = 'search_query';
  static const String trackView = 'track_view';
  static const String reviewSubmit = 'review_submit';

  // ─── Signal strength weights (Grainger Ch. 4) ────────────────

  static const Map<String, double> signalWeights = {
    reviewSubmit: 1.0, // strongest explicit signal
    recClick: 0.6, // moderate intent signal
    searchQuery: 0.4, // indicates active interest
    trackView: 0.3, // weak interest signal
    recDismiss: -0.2, // negative implicit signal
  };

  // ─── In-memory batch buffer ──────────────────────────────────

  static final List<Map<String, dynamic>> _buffer = [];
  static const int _batchThreshold = 5;
  static bool _flushScheduled = false;

  // ─── Public API (fire-and-forget) ────────────────────────────

  /// Log a search query signal (call after debounce, only for final queries).
  static void logSearchQuery({
    required String query,
    String sourceContext = 'search',
    String filter = 'all',
  }) {
    _enqueue({
      'type': searchQuery,
      'targetArtist': '',
      'targetTrack': '',
      'targetGenres': <String>[],
      'sourceContext': sourceContext,
      'metadata': {
        'searchQuery': query,
        'filter': filter,
      },
    });
  }

  /// Log a review submission signal.
  static void logReviewSubmit({
    required String artist,
    required String track,
    required double rating,
    List<String> genres = const [],
  }) {
    _enqueue({
      'type': reviewSubmit,
      'targetArtist': artist,
      'targetTrack': track,
      'targetGenres': genres,
      'sourceContext': 'review',
      'metadata': {
        'rating': rating,
        'genres': genres,
      },
    });
  }

  // ─── Signal retrieval (for scoring) ──────────────────────────

  // ─── Internal batching logic ─────────────────────────────────

  static void _enqueue(Map<String, dynamic> signal) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return; // Not logged in — discard

    signal['timestamp'] = FieldValue.serverTimestamp();
    signal['userId'] = userId;
    _buffer.add(signal);

    if (_buffer.length >= _batchThreshold) {
      _flush();
    } else if (!_flushScheduled) {
      _flushScheduled = true;
      // Flush after a short delay if buffer doesn't fill up
      Future.delayed(const Duration(seconds: 10), () {
        _flushScheduled = false;
        if (_buffer.isNotEmpty) _flush();
      });
    }
  }

  static void _flush() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || _buffer.isEmpty) return;

    final batch = _firestore.batch();
    final signalsRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('signals');

    final toFlush = List<Map<String, dynamic>>.from(_buffer);
    _buffer.clear();

    for (final signal in toFlush) {
      batch.set(signalsRef.doc(), signal);
    }

    batch.commit().then((_) {
      debugPrint('[SIGNALS] Flushed ${toFlush.length} signals');
    }).catchError((e) {
      debugPrint('[SIGNALS] Error flushing signals: $e');
      // Re-enqueue on failure (best-effort)
      _buffer.addAll(toFlush);
    });
  }

}

/// A parsed user signal from Firestore.
class UserSignal {
  final String type;
  final String targetArtist;
  final String targetTrack;
  final List<String> targetGenres;
  final String sourceContext;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  const UserSignal({
    required this.type,
    required this.targetArtist,
    required this.targetTrack,
    required this.targetGenres,
    required this.sourceContext,
    required this.timestamp,
    required this.metadata,
  });
}
