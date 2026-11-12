import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/home_feed_controls.dart';
import '../../providers/tag_reviews_provider.dart' show normalizeTag;
import '../theme/tokens.dart';
import 'app_states.dart';
import 'genre_pills.dart';
import 'glass.dart';

/// The row under the Home tabs: a swipeable carousel of tags (most of the
/// width) that filters the feeds, and a sort button on the right that opens
/// a glass dropdown. State lives in [homeTagFilterProvider] and
/// [homeSortProvider], shared by Popular, Friends and For You.
class HomeFeedControls extends ConsumerWidget {
  const HomeFeedControls({super.key});

  static const double height = 34;

  /// Width of the fade at the carousel's right edge.
  static const double _fadeWidth = 28;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(homeTagChoicesProvider);
    final selected = ref.watch(homeTagFilterProvider);
    final sort = ref.watch(homeSortProvider);

    void toggle(String tag) {
      final key = normalizeTag(tag);
      final next = {...selected};
      if (!next.remove(key)) next.add(key);
      ref.read(homeTagFilterProvider.notifier).state = next;
    }

    return SizedBox(
      height: height,
      child: Row(
        children: [
          Expanded(
            // Tags fade out toward the sort button (which also says "swipe
            // for more"). The pills fade, not a painted band, so it works on
            // the see-through header.
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) => LinearGradient(
                colors: const [Colors.white, Colors.white, Colors.transparent],
                stops: [0, 1 - _fadeWidth / rect.width, 1],
              ).createShader(rect),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: AppSpacing.pageGutter),
                itemCount: tags.length + 1,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, i) => Center(
                  child: i == 0
                      ? TagPill(
                          label: 'All',
                          selected: selected.isEmpty,
                          onTap: () =>
                              ref.read(homeTagFilterProvider.notifier).state =
                                  const {},
                        )
                      : TagPill(
                          label: tags[i - 1],
                          selected: selected.contains(
                            normalizeTag(tags[i - 1]),
                          ),
                          onTap: () => toggle(tags[i - 1]),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.pageGutter),
            child: _SortButton(active: sort != HomeSort.standard),
          ),
        ],
      ),
    );
  }
}

/// The glass tile with the filter icon; a dot shows when a sort is on.
class _SortButton extends ConsumerWidget {
  const _SortButton({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Tooltip(
      message: 'Sort reviews',
      // Solid grey like the tag pills beside it.
      child: Material(
        color: AppColors.pill,
        borderRadius: AppRadius.cardAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: AppRadius.cardAll,
          onTap: () => _openSortMenu(context, ref),
          child: SizedBox(
            width: 44,
            height: HomeFeedControls.height,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.tune, size: 18, color: Colors.white),
                if (active)
                  const Positioned(
                    top: 6,
                    right: 8,
                    child: CircleAvatar(
                      radius: 3,
                      backgroundColor: AppColors.primary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A glass dropdown right under the button, aligned to its right edge.
  void _openSortMenu(BuildContext context, WidgetRef ref) {
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final button = context.findRenderObject()! as RenderBox;
    final rect =
        button.localToGlobal(Offset.zero, ancestor: overlay) & button.size;
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close sort menu',
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (dialogContext, _, __) => Stack(
        children: [
          Positioned(
            top: rect.bottom + AppSpacing.sm,
            right: overlay.size.width - rect.right,
            child: const _SortMenu(),
          ),
        ],
      ),
      transitionBuilder: (_, animation, __, child) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          alignment: Alignment.topRight,
          scale: Tween(begin: 0.95, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SortMenu extends ConsumerWidget {
  const _SortMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(homeSortProvider);
    final hasTags = ref.watch(homeTagFilterProvider).isNotEmpty;
    return SizedBox(
      width: 240,
      child: GlassSurface(
        borderRadius: AppRadius.cardAll,
        shadow: true,
        child: Material(
          type: MaterialType.transparency,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.xs,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: Text(
                    'SORT REVIEWS',
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                for (final option in HomeSort.values)
                  _MenuRow(
                    label: option.label,
                    checked: option == sort,
                    onTap: () {
                      ref.read(homeSortProvider.notifier).state = option;
                      Navigator.of(context).pop();
                    },
                  ),
                if (hasTags) ...[
                  Divider(
                    height: AppSpacing.md,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  _MenuRow(
                    label: 'Clear tag filters',
                    icon: Icons.close,
                    onTap: () {
                      ref.read(homeTagFilterProvider.notifier).state = const {};
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.label,
    required this.onTap,
    this.checked = false,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final bool checked;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 15,
                  fontWeight: checked ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (checked)
              const Icon(Icons.check, size: 18, color: AppColors.onSurface)
            else if (icon != null)
              Icon(icon, size: 18, color: AppColors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// A Home tab's empty state when no review has any of the picked tags.
class NoTagMatches extends StatelessWidget {
  const NoTagMatches({super.key});

  @override
  Widget build(BuildContext context) => const AppEmptyState(
    icon: Icons.tune,
    title: 'No reviews with these tags',
    message: 'Try other tags, or tap All to see everything.',
  );
}
