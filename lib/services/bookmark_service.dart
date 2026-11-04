import 'package:cloud_firestore/cloud_firestore.dart';

/// Reviews a user has saved, at users/{uid}/bookmarks/{id}. Each bookmark
/// stores only the review's path, so the saved list always shows the review
/// as it is now (and drops it if it was deleted). Private to the user.
class BookmarkService {
  BookmarkService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _bookmarks(String userId) =>
      _db.collection('users').doc(userId).collection('bookmarks');

  /// Doc id for a review path (users/u/reviews/r → users__u__reviews__r).
  static String docIdFor(String reviewPath) =>
      reviewPath.replaceAll('/', '__');

  /// The user's bookmarks, newest first: (review path, when saved).
  Stream<List<({String reviewPath, DateTime? savedAt})>> bookmarksStream(
      String userId) {
    return _bookmarks(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => [
              for (final doc in snap.docs)
                if (doc.data()['reviewPath'] case final String path)
                  (
                    reviewPath: path,
                    savedAt: (doc.data()['createdAt'] as Timestamp?)?.toDate(),
                  ),
            ]);
  }

  /// Saves [reviewPath], or un-saves it if already saved.
  Future<void> toggle({
    required String userId,
    required String reviewPath,
    required bool isBookmarked,
  }) {
    final ref = _bookmarks(userId).doc(docIdFor(reviewPath));
    if (isBookmarked) return ref.delete();
    return ref.set({
      'reviewPath': reviewPath,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
