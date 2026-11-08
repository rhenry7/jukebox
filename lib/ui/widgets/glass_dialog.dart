import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'glass.dart';

/// Shows [GlassDialog] over a lightly dimmed screen, so the frosted glass
/// has the feed behind it to blur.
Future<T?> showGlassDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black38,
    builder: builder,
  );
}

/// A frosted-glass dialog: a [GlassSurface] panel, like the nav dock.
class GlassDialog extends StatelessWidget {
  const GlassDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions = const [],
  });

  final String title;
  final Widget content;
  final List<Widget> actions;

  static const BorderRadius _shape =
      BorderRadius.all(Radius.circular(AppRadius.xl));

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl, vertical: AppSpacing.xl),
      child: GlassSurface(
        borderRadius: _shape,
        shadow: true,
        child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DefaultTextStyle.merge(
                      style: const TextStyle(
                          color: AppColors.onSurfaceVariant, fontSize: 14),
                      child: content,
                    ),
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: actions,
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
