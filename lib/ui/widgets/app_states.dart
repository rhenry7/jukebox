import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Shared empty / error / loading-more states.
///
/// Every list screen uses these instead of hand-building its own
/// icon + title + message column, so these states look the same everywhere.

/// A call to action shown under an [AppEmptyState] or [AppErrorState].
class AppStateAction {
  const AppStateAction({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
}

/// Centered icon, title, optional message and optional action.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.iconColor = AppColors.onSurfaceVariant,
  });

  final IconData icon;
  final String title;
  final String? message;
  final AppStateAction? action;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppSpacing.huge, color: iconColor),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: const TextStyle(color: AppColors.onSurface, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message!,
                style: const TextStyle(color: AppColors.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xl),
              _ActionButton(action: action!),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error variant of [AppEmptyState] with a Retry action.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.title,
    required this.onRetry,
    this.error,
  });

  final String title;
  final VoidCallback onRetry;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.error_outline,
      iconColor: AppColors.error,
      title: title,
      message: error?.toString(),
      action: AppStateAction(label: 'Retry', onPressed: onRetry),
    );
  }
}

/// Small spinner shown at the end of a list while the next page loads.
class AppLoadingFooter extends StatelessWidget {
  const AppLoadingFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.onSurface),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action});

  final AppStateAction action;

  @override
  Widget build(BuildContext context) {
    final style = ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
    );
    final label = Text(action.label);

    if (action.icon == null) {
      return ElevatedButton(
        onPressed: action.onPressed,
        style: style,
        child: label,
      );
    }
    return ElevatedButton.icon(
      onPressed: action.onPressed,
      style: style,
      icon: Icon(action.icon),
      label: label,
    );
  }
}
