import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../models/review.dart';
import '../providers/reviews_provider.dart' show ReviewWithDocId;

/// A review suggested right after the user posts one of their own.
class ReviewMatch {
  const ReviewMatch({required this.review, required this.reason});

  final ReviewWithDocId review;

  /// Why it was suggested, e.g. "Also praises the clean jazz guitar, like
  /// your review of Khobs".
  final String reason;
}

/// One recommendation in the server-built For You list.
class ForYouEntry {
  const ForYouEntry(
      {required this.reviewPath, required this.score, this.reason});

  final String reviewPath;
  final double score;
  final String? reason;
}

/// Client for the server-side CF-RAG recommender (`functions/`).
///
/// All AI work happens in Cloud Functions; the app only reads the cached
/// For You list and calls two callables. No API keys live in the client.
class ForYouService {
  static FirebaseFunctions get _functions => FirebaseFunctions.instance;

  /// Asks the server to rebuild the cached list (pull-to-refresh). Returns
  /// false if the function isn't reachable, so callers can fall back.
  static Future<bool> refresh() async {
    try {
      await _functions.httpsCallable('refreshForYou').call<void>();
      return true;
    } catch (e) {
      debugPrint('[FOR_YOU] refreshForYou failed: $e');
      return false;
    }
  }

  /// The cached For You list for [userId]: review paths in ranked order,
  /// without the reviews themselves, so the app fetches only the ones it
  /// shows. Emits null while no cache exists (new user, or the backend isn't
  /// deployed yet) so callers can fall back.
  static Stream<List<ForYouEntry>?> watchEntries(
    String userId, {
    FirebaseFirestore? db,
  }) {
    final firestore = db ?? FirebaseFirestore.instance;
    return firestore
        .doc('users/$userId/forYou/current')
        .snapshots()
        .map((snap) {
      final items = (snap.data()?['items'] as List?)?.cast<Map>() ?? const [];
      if (items.isEmpty) return null;
      return [
        for (final i in items)
          if (i['reviewPath'] case final String path)
            ForYouEntry(
              reviewPath: path,
              score: (i['score'] as num?)?.toDouble() ?? 0,
              reason: i['reason'] as String?,
            ),
      ];
    });
  }

  /// Loads review documents by full path, keeping the given order and
  /// skipping any that were deleted since the list was built. With
  /// [preferCache], reviews already on the device are used as they are and
  /// only the rest come from the server.
  static Future<List<ReviewWithDocId>> fetchReviews(
    List<String> paths, {
    FirebaseFirestore? db,
    bool preferCache = false,
  }) async {
    final reviews = await Future.wait(
        paths.map((p) => fetchReview(p, db: db, preferCache: preferCache)));
    return reviews.whereType<ReviewWithDocId>().toList();
  }

  /// One review by full path, or null if it was deleted. With [preferCache],
  /// the copy on the device is used when there is one.
  static Future<ReviewWithDocId?> fetchReview(
    String path, {
    FirebaseFirestore? db,
    bool preferCache = false,
  }) async {
    final ref = (db ?? FirebaseFirestore.instance).doc(path);
    DocumentSnapshot<Map<String, dynamic>>? snap;
    if (preferCache) {
      try {
        final cached = await ref.get(const GetOptions(source: Source.cache));
        if (cached.exists) snap = cached;
      } catch (_) {
        // Not on the device.
      }
    }
    snap ??= await ref.get();
    final data = snap.data();
    if (!snap.exists || data == null) return null;
    return ReviewWithDocId(
      review: Review.fromFirestore(data),
      docId: snap.id,
      fullReviewId: snap.reference.path,
    );
  }
}
