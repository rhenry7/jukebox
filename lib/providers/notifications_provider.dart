import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/notification_event.dart';
import '../providers/auth_provider.dart';
import '../services/notifications_service.dart';

final notificationsServiceProvider = Provider<NotificationsService>((ref) {
  return NotificationsService();
});

final userNotificationsProvider =
    StreamProvider<List<NotificationEvent>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);

  final service = ref.watch(notificationsServiceProvider);
  return service.notificationsStream(userId);
});
