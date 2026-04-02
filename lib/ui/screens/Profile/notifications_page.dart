import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/notification_event.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/notifications_provider.dart';
import '../../../services/friends_service.dart';
import '../../../utils/cached_image.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────

const _bg = Color(0xFF0E0E0E);
const _surface = Color(0xFF1A1919);
const _surfaceHigh = Color(0xFF201F1F);
const _primary = Color(0xFFEE2309);
const _secondary = Color(0xFF3FFF8B);
const _onSurfaceVariant = Color(0xFFADAAAA);

// ─── Date-grouping helpers ────────────────────────────────────────────────────

/// Groups a sorted-descending list of events into labelled sections.
/// Order is preserved: TODAY → YESTERDAY → older dates.
List<({String label, List<NotificationEvent> events})> _groupByDate(
    List<NotificationEvent> events) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));

  final seen = <String>[];
  final map = <String, List<NotificationEvent>>{};

  for (final e in events) {
    final d = e.createdAt;
    final String label;
    if (d == null) {
      label = 'EARLIER';
    } else {
      final day = DateTime(d.year, d.month, d.day);
      if (day == today) {
        label = 'TODAY';
      } else if (day == yesterday) {
        label = 'YESTERDAY';
      } else {
        label = _formatSectionDate(d);
      }
    }
    if (!seen.contains(label)) seen.add(label);
    map.putIfAbsent(label, () => []).add(e);
  }

  return [
    for (final label in seen) (label: label, events: map[label]!),
  ];
}

String _formatSectionDate(DateTime d) {
  const months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];
  return '${months[d.month - 1]} ${d.day}';
}

/// e.g. "2 HOURS AGO" or "YESTERDAY, 14:45"
String _formatCardTime(DateTime? d, String sectionLabel) {
  if (d == null) return '';
  final diff = DateTime.now().difference(d);

  if (sectionLabel == 'TODAY') {
    if (diff.inMinutes < 1) return 'JUST NOW';
    if (diff.inMinutes < 60) return '${diff.inMinutes} MIN AGO';
    return '${diff.inHours} HOUR${diff.inHours == 1 ? '' : 'S'} AGO';
  }

  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '$sectionLabel, $hh:$mm';
}

Color _avatarColor(String name) {
  const palette = [
    Color(0xFF6B3FA0), Color(0xFF1E5F74), Color(0xFF7B2D8B),
    Color(0xFF1A5E3E), Color(0xFF7A3B1E), Color(0xFF1E3A5F),
    Color(0xFF5C1E6B), Color(0xFF1E4D2B), Color(0xFF6B1E3A),
    Color(0xFF2A4B6B),
  ];
  if (name.isEmpty) return palette[0];
  return palette[name.codeUnitAt(0) % palette.length];
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: Text('Sign in to view notifications.',
              style: TextStyle(color: _onSurfaceVariant)),
        ),
      );
    }

    final notificationsAsync = ref.watch(userNotificationsProvider);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'NOTIFICATIONS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        centerTitle: false,
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return _EmptyState();
          }

          final sections = _groupByDate(notifications);

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: sections.fold<int>(0, (sum, s) => sum + 1 + s.events.length),
            itemBuilder: (context, idx) {
              // Flatten sections into a single list: header + items
              int cursor = 0;
              for (final section in sections) {
                if (idx == cursor) {
                  return _SectionHeader(label: section.label);
                }
                cursor++;
                for (final event in section.events) {
                  if (idx == cursor) {
                    return _buildCard(event, section.label, userId);
                  }
                  cursor++;
                }
              }
              return const SizedBox.shrink();
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(_primary),
          ),
        ),
        error: (e, _) => Center(
          child: Text('Failed to load notifications: $e',
              style: const TextStyle(color: _onSurfaceVariant)),
        ),
      ),
    );
  }

  Widget _buildCard(
      NotificationEvent event, String sectionLabel, String userId) {
    switch (event.type) {
      case NotificationType.friendAdded:
        return _FriendRequestCard(
            event: event, sectionLabel: sectionLabel, currentUserId: userId);
      case NotificationType.reviewLike:
        return _ReviewLikeCard(event: event, sectionLabel: sectionLabel);
      default:
        return _DefaultCard(event: event, sectionLabel: sectionLabel);
    }
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Text(
        label,
        style: const TextStyle(
          color: _onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

// ─── Shared avatar widget ─────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String? photoUrl;
  final String displayName;
  final Widget? badge;

  const _Avatar({
    required this.displayName,
    this.photoUrl,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _avatarColor(displayName),
          ),
          child: photoUrl != null && photoUrl!.isNotEmpty
              ? ClipOval(
                  child: AppCachedImage(
                    imageUrl: photoUrl!,
                    width: 48,
                    height: 48,
                  ),
                )
              : Center(
                  child: Text(
                    displayName.isNotEmpty
                        ? displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ),
        if (badge != null)
          Positioned(
            bottom: -2,
            right: -2,
            child: badge!,
          ),
      ],
    );
  }
}

Widget _heartBadge() => Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        color: _primary,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 11),
    );

Widget _personBadge() => Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: _surfaceHigh,
        shape: BoxShape.circle,
        border: Border.all(color: _primary, width: 1),
      ),
      child: const Icon(Icons.person_add_rounded, color: _primary, size: 11),
    );

// ─── Friend request card ──────────────────────────────────────────────────────

class _FriendRequestCard extends ConsumerStatefulWidget {
  final NotificationEvent event;
  final String sectionLabel;
  final String currentUserId;

  const _FriendRequestCard({
    required this.event,
    required this.sectionLabel,
    required this.currentUserId,
  });

  @override
  ConsumerState<_FriendRequestCard> createState() => _FriendRequestCardState();
}

class _FriendRequestCardState extends ConsumerState<_FriendRequestCard> {
  bool _accepting = false;
  bool _dismissed = false;

  Future<void> _accept() async {
    setState(() => _accepting = true);
    try {
      await FriendsService().addFriend(
        currentUserId: widget.currentUserId,
        friendId: widget.event.actorId,
        friendDisplayName: widget.event.actorDisplayName,
      );
      await _deleteNotification();
    } catch (e) {
      debugPrint('[NotifCard] Accept error: $e');
      if (mounted) setState(() => _accepting = false);
    }
  }

  Future<void> _dismiss() async {
    await _deleteNotification();
  }

  Future<void> _deleteNotification() async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .collection('notifications')
          .doc(widget.event.id)
          .delete();
    } catch (e) {
      debugPrint('[NotifCard] Delete error: $e');
    }
    if (mounted) setState(() => _dismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final actor = widget.event.actorDisplayName.isNotEmpty
        ? widget.event.actorDisplayName
        : 'Someone';

    return _CardShell(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(
            displayName: actor,
            photoUrl: widget.event.actorPhotoUrl,
            badge: _personBadge(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, height: 1.4),
                    children: [
                      TextSpan(
                        text: actor,
                        style: const TextStyle(
                          color: _primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(text: ' sent you a friend request.'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _ActionButton(
                      label: _accepting ? '...' : 'ACCEPT',
                      filled: true,
                      onTap: _accepting ? null : _accept,
                    ),
                    const SizedBox(width: 10),
                    _ActionButton(
                      label: 'DISMISS',
                      filled: false,
                      onTap: _dismiss,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.filled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? _primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: filled
              ? null
              : Border.all(color: Colors.white24, width: 1),
          boxShadow: filled
              ? [
                  BoxShadow(
                    color: _primary.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 0,
                  )
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: filled ? Colors.white : _onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

// ─── Review like card ─────────────────────────────────────────────────────────

class _ReviewLikeCard extends StatelessWidget {
  final NotificationEvent event;
  final String sectionLabel;

  const _ReviewLikeCard({required this.event, required this.sectionLabel});

  @override
  Widget build(BuildContext context) {
    final actor = event.actorDisplayName.isNotEmpty
        ? event.actorDisplayName
        : 'Someone';
    final title = event.reviewTitle ?? '';
    final artist = event.reviewArtist ?? '';
    final timeLabel = _formatCardTime(event.createdAt, sectionLabel);

    return _CardShell(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(
            displayName: actor,
            photoUrl: event.actorPhotoUrl,
            badge: _heartBadge(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header line
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, height: 1.4),
                    children: [
                      TextSpan(
                        text: actor,
                        style: const TextStyle(
                          color: _primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(text: ' liked your review of '),
                      if (title.isNotEmpty)
                        TextSpan(
                          text: '"$title"',
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                      if (artist.isNotEmpty)
                        TextSpan(text: ' by $artist'),
                    ],
                  ),
                ),

                // Review snippet quote block
                if (title.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        Container(
                          width: 2,
                          decoration: BoxDecoration(
                            color: _primary,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '"$title${artist.isNotEmpty ? ' by $artist' : ''}"',
                            style: const TextStyle(
                              color: _onSurfaceVariant,
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (timeLabel.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    timeLabel,
                    style: const TextStyle(
                      color: _onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Default / fallback card ──────────────────────────────────────────────────

class _DefaultCard extends StatelessWidget {
  final NotificationEvent event;
  final String sectionLabel;

  const _DefaultCard({required this.event, required this.sectionLabel});

  @override
  Widget build(BuildContext context) {
    final actor = event.actorDisplayName.isNotEmpty
        ? event.actorDisplayName
        : 'Someone';
    final timeLabel = _formatCardTime(event.createdAt, sectionLabel);

    return _CardShell(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _surfaceHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.notifications_rounded,
                color: _onSurfaceVariant, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, height: 1.4),
                    children: [
                      TextSpan(
                        text: actor,
                        style: const TextStyle(
                          color: _primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(text: ' sent an update.'),
                    ],
                  ),
                ),
                if (timeLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    timeLabel,
                    style: const TextStyle(
                      color: _onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card shell ───────────────────────────────────────────────────────────────

class _CardShell extends StatelessWidget {
  final Widget child;

  const _CardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: _onSurfaceVariant,
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'All caught up',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No new notifications yet.',
            style: TextStyle(
              color: _onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
