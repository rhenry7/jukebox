import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/models/review_comment.dart';
import 'package:flutter_test_project/providers/auth_provider.dart';
import 'package:flutter_test_project/providers/review_comments_provider.dart';
import 'package:flutter_test_project/providers/review_likes_provider.dart';
import 'package:flutter_test_project/providers/reviews_provider.dart';
import 'package:flutter_test_project/providers/similar_reviews_provider.dart';

/// Screen tests stand in fake data through the app's own Riverpod
/// providers, so no real Firebase, Spotify or network is touched.

final testUser = MockUser(uid: 'me', displayName: 'Tester', email: 't@x.io');

Review sampleReview({
  String userId = 'someone',
  String title = 'Bang Bang',
  String artist = 'Nancy Sinatra',
  String text = 'Great storytelling and a haunting guitar.',
  List<String> genres = const ['country', 'western'],
}) =>
    Review(
      displayName: 'wuTangFan',
      userId: userId,
      artist: artist,
      review: text,
      score: 5,
      likes: 0,
      replies: 0,
      reposts: 0,
      title: title,
      genres: genres,
      date: DateTime(2026, 4, 1),
    );

ReviewComment sampleComment(String id, String text) => ReviewComment(
      id: id,
      userId: 'u-$id',
      displayName: 'Commenter $id',
      text: text,
      createdAt: DateTime(2026, 4, 2),
      likes: 0,
    );

/// Overrides for a screen showing reviews: who is signed in, like counts,
/// comments, and the "More like this" row.
List<Override> reviewScreenOverrides({
  User? user,
  int likeCount = 0,
  Stream<List<ReviewComment>>? comments,
}) =>
    [
      currentUserProvider.overrideWithValue(user),
      firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
      reviewLikeCountProvider
          .overrideWith((ref, id) => Stream.value(likeCount)),
      reviewUserLikeStatusProvider
          .overrideWith((ref, id) => Stream.value(false)),
      reviewCommentsProvider.overrideWith(
          (ref, id) => comments ?? Stream.value(const <ReviewComment>[])),
      similarReviewsProvider
          .overrideWith((ref, key) => Stream.value(const <SimilarReview>[])),
    ];

/// [child] in the app's dark theme, with [overrides], at phone size.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: overrides,
    child: MaterialApp(theme: ThemeData.dark(), home: child),
  ));
}
