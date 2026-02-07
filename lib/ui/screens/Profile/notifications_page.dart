import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';

import '../../../models/notification_event.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/notifications_provider.dart';
import '../../../utils/helpers.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) {
      return const Scaffold(
        body: Center(
          child: Text('Sign in to view notifications.'),
        ),
      );
    }

    final notificationsAsync = ref.watch(userNotificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(
              child: Text('No notifications yet.'),
            );
          }

          return ListView.separated(
            itemCount: notifications.length,
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            separatorBuilder: (_, __) =>
                const Divider(height: 0.3, color: Colors.white24),
            itemBuilder: (context, index) {
              final event = notifications[index];
              return _NotificationTile(event: event);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Failed to load notifications: $error'),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationEvent event;

  const _NotificationTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final title = _buildTitle(event);
    final subtitle = _buildSubtitle(event);
    final timeLabel = formatRelativeTime(event.createdAt);

    return ListTile(
      leading: Icon(_iconForType(event.type), color: Colors.white70),
      title: Text(title),
      subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
      trailing: timeLabel.isNotEmpty
          ? Text(
              timeLabel,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            )
          : null,
    );
  }

  String _buildTitle(NotificationEvent event) {
    final actor =
        event.actorDisplayName.isNotEmpty ? event.actorDisplayName : 'Someone';
    switch (event.type) {
      case NotificationType.reviewLike:
        return '$actor liked your review';
      case NotificationType.friendAdded:
        return '$actor added you as a friend';
      default:
        return '$actor sent an update';
    }
  }

  String _buildSubtitle(NotificationEvent event) {
    if (event.type == NotificationType.reviewLike) {
      final details = <String>[];
      if (event.reviewTitle != null && event.reviewTitle!.isNotEmpty) {
        details.add('"${event.reviewTitle}"');
      }
      if (event.reviewArtist != null && event.reviewArtist!.isNotEmpty) {
        details.add(event.reviewArtist!);
      }
      return details.join(' • ');
    }
    return '';
  }

  IconData _iconForType(String type) {
    switch (type) {
      case NotificationType.reviewLike:
        return Ionicons.heart_circle;
      case NotificationType.friendAdded:
        return Ionicons.person_circle_outline;
      default:
        return Ionicons.notifications;
    }
  }
}
