import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart' show currentUserIdProvider;
import '../../providers/reviews_provider.dart'
    show ReviewWithDocId, firestoreProvider;
import '../theme/tokens.dart';
import '../../services/for_you_feedback_service.dart';
import 'glass_dialog.dart';
import 'app_toast.dart';

/// Swipe left or long-press your own review to open its options (edit,
/// delete). Other people's reviews have no options, so they don't swipe and
/// [child] is returned as is. Adds no padding.
class OwnReviewOptions extends ConsumerWidget {
  const OwnReviewOptions({
    super.key,
    required this.review,
    required this.child,
    this.onDeleted,
  });

  final ReviewWithDocId review;
  final Widget child;

  /// Runs after the review is deleted, e.g. to refresh a feed that doesn't
  /// update by itself.
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null || review.review.userId != userId) return child;
    return Dismissible(
      key: Key('options-${review.docId}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        // Show the options instead of dismissing the card.
        _showOptions(context, ref);
        return false;
      },
      background: Container(
        decoration: const BoxDecoration(
          color: Color.fromARGB(255, 220, 53, 69),
          borderRadius: AppRadius.cardAll,
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.xl),
        child: const Icon(
          Icons.more_vert,
          color: Colors.white,
          size: 28,
        ),
      ),
      child: GestureDetector(
        onLongPress: () => _showOptions(context, ref),
        child: child,
      ),
    );
  }

  void _showOptions(BuildContext context, WidgetRef ref) {
    showGlassDialog(
      context: context,
      builder: (dialogContext) => GlassDialog(
        title: 'Your review',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${review.review.title} · ${review.review.artist}',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: AppSpacing.sm),
            _GlassOption(
              icon: Icons.edit_outlined,
              label: 'Edit review',
              onTap: () {
                Navigator.pop(dialogContext);
                _editReview(context);
              },
            ),
            _GlassOption(
              icon: Icons.delete_outline,
              label: 'Delete review',
              destructive: true,
              onTap: () {
                Navigator.pop(dialogContext);
                _deleteReview(context, ref);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(foregroundColor: AppColors.onSurface),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _editReview(BuildContext context) {
    // Navigate to edit review screen or show edit dialog
    showAppToast(context, 'Edit review: ${review.docId}');
  }

  void _deleteReview(BuildContext context, WidgetRef ref) {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      showAppToast(context, 'You must be signed in to delete reviews', tone: ToastTone.warning);
      return;
    }
    final db = ref.read(firestoreProvider);
    final messenger = ScaffoldMessenger.of(context);

    showGlassDialog(
      context: context,
      builder: (dialogContext) => GlassDialog(
        title: 'Delete review?',
        content: const Text(
          'This review will be deleted for good. This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(foregroundColor: AppColors.onSurface),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await db
                    .collection('users')
                    .doc(userId)
                    .collection('reviews')
                    .doc(review.docId)
                    .delete();
                onDeleted?.call();
                messenger.showAppToast('Review deleted', tone: ToastTone.success);
              } catch (e) {
                debugPrint('Could not delete review: $e');
                messenger.showAppToast("Couldn't delete the review. Try again.", tone: ToastTone.error);
              }
            },
            child:
                const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

/// Swipe left or long-press a For You card to say "Not for me": the card
/// hides at once (via `forYouDismissedProvider`), and Cloud Functions rebuild
/// the list so that song never comes back and similar artists rank lower.
/// Your own reviews and signed-out users get [child] as is. Adds no padding.
class NotForMeOptions extends ConsumerWidget {
  const NotForMeOptions({
    super.key,
    required this.review,
    required this.child,
  });

  final ReviewWithDocId review;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    final path = review.fullReviewId;
    if (userId == null || path == null || review.review.userId == userId) {
      return child;
    }
    return Dismissible(
      key: Key('not-for-me-$path'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        // Show the options instead of dismissing the card.
        _showOptions(context, ref, userId, path);
        return false;
      },
      background: Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerHighest,
          borderRadius: AppRadius.cardAll,
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.xl),
        child: const Icon(Icons.more_vert, color: Colors.white, size: 28),
      ),
      child: GestureDetector(
        onLongPress: () => _showOptions(context, ref, userId, path),
        child: child,
      ),
    );
  }

  void _showOptions(
      BuildContext context, WidgetRef ref, String userId, String path) {
    final messenger = ScaffoldMessenger.of(context);
    final service = ForYouFeedbackService(ref.read(firestoreProvider));
    showGlassDialog(
      context: context,
      builder: (dialogContext) => GlassDialog(
        title: 'For You',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${review.review.title} · ${review.review.artist}',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: AppSpacing.sm),
            _GlassOption(
              icon: Icons.thumb_down_outlined,
              label: 'Not for me',
              onTap: () async {
                Navigator.pop(dialogContext);
                try {
                  await service.notForMe(userId, path);
                  messenger.showAppToast(
                      "Got it. You'll see less like this.",
                      tone: ToastTone.success);
                } catch (e) {
                  debugPrint('Could not save Not for me: $e');
                  messenger.showAppToast("Couldn't save that. Try again.",
                      tone: ToastTone.error);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(foregroundColor: AppColors.onSurface),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

/// One row in the review options dialog.
class _GlassOption extends StatelessWidget {
  const _GlassOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Colors.redAccent : AppColors.onSurface;
    return InkWell(
      borderRadius: AppRadius.mdAll,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs, vertical: AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: AppSpacing.md),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 15, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
