import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

import '../theme/tokens.dart';
import 'glass.dart';

/// What a toast is telling the user. Sets its icon and edge color; the glass
/// itself is the same for all of them.
enum ToastTone {
  info(null, null),
  success(Ionicons.checkmarkCircle, AppColors.success),
  warning(Ionicons.alertCircle, AppColors.warning),
  error(Ionicons.closeCircle, AppColors.error);

  const ToastTone(this.icon, this.color);
  final IconData? icon;
  final Color? color;
}

/// Shows a glass toast: a short message floating above the dock. A new toast
/// replaces the one showing rather than queueing behind it. Tap to dismiss.
///
/// The only way the app shows toasts: never call `showSnackBar` directly.
void showAppToast(
  BuildContext context,
  String message, {
  ToastTone tone = ToastTone.info,
  Duration duration = AppToast.defaultDuration,
}) {
  ScaffoldMessenger.of(context)
      .showAppToast(message, tone: tone, duration: duration);
}

/// For after an `await`, when the caller saved the messenger before the gap.
extension AppToastMessenger on ScaffoldMessengerState {
  void showAppToast(
    String message, {
    ToastTone tone = ToastTone.info,
    Duration duration = AppToast.defaultDuration,
  }) {
    hideCurrentSnackBar();
    showSnackBar(
      SnackBar(
        content: AppToast(message: message, tone: tone),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.md,
        ),
      ),
    );
  }
}

/// The toast's glass panel. Shown by [showAppToast].
class AppToast extends StatelessWidget {
  const AppToast({
    super.key,
    required this.message,
    this.tone = ToastTone.info,
  });

  final String message;
  final ToastTone tone;

  static const Duration defaultDuration = Duration(seconds: 3);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar(),
        child: GlassSurface(
          borderRadius: AppRadius.cardAll,
          accent: tone.color,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                if (tone.icon != null) ...[
                  Icon(tone.icon, size: 20, color: tone.color),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
