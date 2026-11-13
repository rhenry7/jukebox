import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// "Why this is for you" above a recommended review card, as a pill: solid
/// dark grey with light text, like the tag pills (not glass: it repeats on
/// every card in a scrolling list). As wide as its text; a long reason wraps
/// to a second line inside the pill.
class ReasonLabel extends StatelessWidget {
  const ReasonLabel(this.reason, {super.key});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.pill,
          // Round at one line, still soft if it wraps to two.
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs + 2,
          ),
          child: Text(
            reason,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ),
      ),
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
        // Lined up with the card's left edge, so it reads as the card's tab.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.cardGap,
            AppSpacing.md,
            AppSpacing.cardGap,
            AppSpacing.xs,
          ),
          child: ReasonLabel(reason),
        ),
        child,
      ],
    );
  }
}
