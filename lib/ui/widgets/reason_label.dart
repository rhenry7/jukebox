import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// "Why this is for you" line shown above a recommended review card.
class ReasonLabel extends StatelessWidget {
  const ReasonLabel(this.reason, {super.key});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.auto_awesome, size: 14, color: AppColors.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            reason,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

/// A review card with its [ReasonLabel] above it (or just the card).
class WithReason extends StatelessWidget {
  const WithReason({super.key, required this.reason, required this.child});

  final String? reason;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reason = this.reason;
    if (reason == null || reason.isEmpty) return child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReasonLabel(reason),
        const SizedBox(height: AppSpacing.xs),
        child,
      ],
    );
  }
}
