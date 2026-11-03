import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../models/review.dart';
import '../providers/reviews_provider.dart' show ReviewWithDocId;
import 'review_recommendation_service.dart' show ScoredReview;

/// A review suggested right after the user posts one of their own.
class ReviewMatch {
  const ReviewMatch({required this.review, required this.reason});

  final ReviewWithDocId review;

  /// Why it was suggested, e.g. "Also praises the clean jazz guitar, like
  /// your review of Khobs".
  final String reason;
}

/// Client for the server-side CF-RAG recommender (`functions/`).
///
/// All AI work happens in Cloud Functions; the app only reads the cached
/// For You list and calls two callables. No API keys live in the client.
class ForYouService {
  static FirebaseFunctions get _functions => FirebaseFunctions.instance;

  /// Reviews by other people the user will probably like, based on the review
  /// they just wrote. Returns an empty list on any failure.
  static Future<List<ReviewMatch>> matchesForReview(String reviewPath) async {
    try {
      final result = await _functions
          .httpsCallable(
            'analyzeAndMatch',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
          )
          .call<Map<String, dynamic>>({'reviewPath': reviewPath});
      final matches = (result.data['matches'] as List?) ?? const [];
      final reasons = <String, String>{
        for (final m in matches.cast<Map>())
          m['reviewPath'] as String: (m['reason'] as String?) ?? '',
      };
      final reviews = await fetchReviews(reasons.keys.toList());
      return [
        for (final r in reviews)
          ReviewMatch(review: r, reason: reasons[r.fullReviewId] ?? ''),
      ];
    } catch (e) {
      debugPrint('[FOR_YOU] analyzeAndMatch failed: $e');
      return const [];
    }
  }

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

  /// The cached For You list for [userId]. Emits null while no cache exists
  /// (new user, or the backend isn't deployed yet) so callers can fall back.
  static Stream<List<ScoredReview>?> watch(
    String userId, {
    FirebaseFirestore? db,
  }) {
    final firestore = db ?? FirebaseFirestore.instance;
    return firestore
        .doc('users/$userId/forYou/current')
        .snapshots()
        .asyncMap((snap) async {
      final items = (snap.data()?['items'] as List?)?.cast<Map>() ?? const [];
      if (items.isEmpty) return null;
      final reviews = await fetchReviews(
        items.map((i) => i['reviewPath'] as String).toList(),
        db: firestore,
      );
      final byPath = {for (final r in reviews) r.fullReviewId: r};
      return [
        for (final i in items)
          if (byPath[i['reviewPath']] case final review?)
            ScoredReview(
              reviewWithDocId: review,
              finalScore: (i['score'] as num?)?.toDouble() ?? 0,
              reason: i['reason'] as String?,
            ),
      ];
    });
  }

  /// Loads review documents by full path, keeping the given order and
  /// skipping any that were deleted since the list was built.
  static Future<List<ReviewWithDocId>> fetchReviews(
    List<String> paths, {
    FirebaseFirestore? db,
  }) async {
    final firestore = db ?? FirebaseFirestore.instance;
    final snaps = await Future.wait(paths.map((p) => firestore.doc(p).get()));
    return [
      for (final s in snaps)
        if (s.exists && s.data() != null)
          ReviewWithDocId(
            review: Review.fromFirestore(s.data()!),
            docId: s.id,
            fullReviewId: s.reference.path,
          ),
    ];
  }
}
