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

  /// Log a recommendation click signal.
  static void logRecClick({
    required String artist,
    required String track,
    List<String> genres = const [],
    String sourceContext = 'discovery_tab',
    String recommendationSource = '',
    int positionInList = -1,
  }) {
    _enqueue({
      'type': recClick,
      'targetArtist': artist,
      'targetTrack': track,
      'targetGenres': genres,
      'sourceContext': sourceContext,
      'metadata': {
        'recommendationSource': recommendationSource,
        'positionInList': positionInList,
      },
    });
  }

  /// Log a recommendation dismissal / dislike signal.
  static void logRecDismiss({
    required String artist,
    required String track,
    List<String> genres = const [],
    String sourceContext = 'discovery_tab',
  }) {
    _enqueue({
      'type': recDismiss,
      'targetArtist': artist,
      'targetTrack': track,
      'targetGenres': genres,
      'sourceContext': sourceContext,
      'metadata': {},
    });
  }

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

  /// Log a track/album view signal (e.g. opening a review sheet for a track).
  static void logTrackView({
    required String artist,
    required String track,
    List<String> genres = const [],
    String sourceContext = 'community_feed',
  }) {
    _enqueue({
      'type': trackView,
      'targetArtist': artist,
      'targetTrack': track,
      'targetGenres': genres,
      'sourceContext': sourceContext,
      'metadata': {},
    });
  }

  // ─── Signal retrieval (for scoring) ──────────────────────────

  /// Fetch recent signals for the current user (up to [limit]).
  static Future<List<UserSignal>> getRecentSignals({int limit = 200}) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('signals')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return UserSignal(
          type: data['type'] as String? ?? '',
          targetArtist: data['targetArtist'] as String? ?? '',
          targetTrack: data['targetTrack'] as String? ?? '',
          targetGenres: List<String>.from(data['targetGenres'] ?? []),
          sourceContext: data['sourceContext'] as String? ?? '',
          timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
        );
      }).toList();
    } catch (e) {
      debugPrint('[SIGNALS] Error fetching signals: $e');
      return [];
    }
  }

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

  /// Force flush any remaining buffered signals (call on app pause/dispose).
  static void forceFlush() {
    if (_buffer.isNotEmpty) _flush();
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
