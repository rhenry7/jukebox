import 'package:cloud_firestore/cloud_firestore.dart';

/// "Not for me" on a For You card, stored at
/// `users/{uid}/forYouFeedback/{reviewDocId}`. Cloud Functions read it
/// (functions/src/implicit.ts): the song never comes back, and its artist
/// and ones like it rank lower. Writing it also rebuilds the list
/// (`onForYouFeedback`).
class ForYouFeedbackService {
  ForYouFeedbackService(this._db);

  final FirebaseFirestore _db;

  static String docIdFor(String reviewPath) =>
      reviewPath.replaceAll('/', '__');

  CollectionReference<Map<String, dynamic>> _feedback(String userId) =>
      _db.collection('users').doc(userId).collection('forYouFeedback');

  Future<void> notForMe(String userId, String reviewPath) =>
      _feedback(userId).doc(docIdFor(reviewPath)).set({
        'reviewPath': reviewPath,
        'reason': 'not_for_me',
        'createdAt': FieldValue.serverTimestamp(),
      });

  /// Review paths the user dismissed, live.
  Stream<Set<String>> dismissed(String userId) =>
      _feedback(userId).snapshots().map((snap) => {
            for (final d in snap.docs)
              if (d.data()['reviewPath'] case final String path) path,
          });
}
