import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/models/notification_event.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/providers/activity_provider.dart';
import 'package:flutter_test_project/providers/reviews_provider.dart';
import 'package:flutter_test_project/services/activity_service.dart';

ActivityItem _item(String id, DateTime? at,
        {String type = ActivityType.like}) =>
    ActivityItem(id: id, type: type, createdAt: at);

ReviewWithDocId _own(String id, DateTime date, {bool repost = false}) =>
    ReviewWithDocId(
      docId: id,
      fullReviewId: 'users/me/reviews/$id',
      review: Review(
        displayName: repost ? 'Mia' : 'Me',
        userId: 'me',
        artist: 'Artist',
        review: 'text',
        score: 4.5,
        likes: 0,
        replies: 0,
        reposts: 0,
        title: 'Title $id',
        albumImageUrl: 'https://img/$id.jpg',
        date: date,
        isRepost: repost,
      ),
    );

NotificationEvent _notif(String id, String type, DateTime at,
        {String? reviewId}) =>
    NotificationEvent(
      id: id,
      type: type,
      actorId: 'u-$id',
      actorDisplayName: '',
      reviewId: reviewId,
      createdAt: at,
    );

void main() {
  test('newestFirst orders by date, entries without a time first', () {
    final sorted = newestFirst([
      _item('old', DateTime(2026, 1, 1)),
      _item('just-now', null),
      _item('new', DateTime(2026, 3, 1)),
    ]);
    expect([for (final i in sorted) i.id], ['just-now', 'new', 'old']);
  });

  group('buildActivity', () {
    final items = buildActivity(
      log: [
        _item('log-like', DateTime(2026, 1, 5)),
        // Reposts come from own reviews, so the log's copy is dropped.
        _item('log-repost', DateTime(2026, 1, 6), type: ActivityType.repost),
      ],
      ownReviews: [
        _own('r1', DateTime(2026, 1, 1)),
        _own('rp1', DateTime(2026, 1, 3), repost: true),
      ],
      notifications: [
        _notif('n1', NotificationType.reviewLike, DateTime(2026, 1, 4),
            reviewId: 'users/me/reviews/r1'),
        _notif('n2', NotificationType.friendAdded, DateTime(2026, 1, 2)),
        _notif('n3', 'unknown_type', DateTime(2026, 1, 7)),
        // Older notification: review path in another form, title still set.
        NotificationEvent(
          id: 'n4',
          type: NotificationType.reviewLike,
          actorId: 'u4',
          actorDisplayName: 'Jo',
          reviewId: 'users_me_reviews_r1',
          reviewTitle: 'title r1',
          reviewArtist: 'ARTIST',
          createdAt: DateTime(2025, 12, 1),
        ),
      ],
    );
    final byId = {for (final i in items) i.id: i};

    test('merges every source newest first, skipping unknown types', () {
      expect([
        for (final i in items) i.id
      ], [
        'log-like',
        'notif_n1',
        'own_rp1',
        'notif_n2',
        'own_r1',
        'notif_n4'
      ]);
    });

    test('own reviews become review rows with their rating', () {
      expect(byId['own_r1']!.type, ActivityType.review);
      expect(byId['own_r1']!.score, 4.5);
    });

    test('repost copies become repost rows crediting the original author', () {
      expect(byId['own_rp1']!.type, ActivityType.repost);
      expect(byId['own_rp1']!.reviewAuthorName, 'Mia');
    });

    test('notifications on your reviews borrow the album art', () {
      expect(byId['notif_n1']!.type, ActivityType.likedYourReview);
      expect(byId['notif_n1']!.albumImageUrl, 'https://img/r1.jpg');
      expect(byId['notif_n4']!.albumImageUrl, 'https://img/r1.jpg');
      expect(ActivityType.isOnYou(byId['notif_n1']!.type), isTrue);
      expect(ActivityType.isOnYou(byId['own_r1']!.type), isFalse);
    });
  });

  test('repeated likes by the same person on one review show once', () {
    final items =
        buildActivity(log: const [], ownReviews: const [], notifications: [
      _notif('a', NotificationType.reviewLike, DateTime(2026, 1, 1),
          reviewId: 'users/me/reviews/r1'),
      _notif('a', NotificationType.reviewLike, DateTime(2026, 1, 3),
          reviewId: 'users/me/reviews/r1'),
      _notif('b', NotificationType.reviewLike, DateTime(2026, 1, 2),
          reviewId: 'users/me/reviews/r1'),
    ]);
    // Same actor ('u-a') twice → newest kept; a different actor stays.
    expect(items.length, 2);
    expect(items.first.createdAt, DateTime(2026, 1, 3));
  });

  test('needsActorName catches blanks and the old placeholder', () {
    expect(needsActorName(null), isTrue);
    expect(needsActorName('  '), isTrue);
    expect(needsActorName('Someone'), isTrue);
    expect(needsActorName('Mia'), isFalse);
  });
}
