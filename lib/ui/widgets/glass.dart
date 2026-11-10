import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Frosted glass: whatever is behind it, blurred, under a dark tint that is
/// lighter at the top-left (where the light hits) and a faint light edge.
/// The one place the glass recipe lives; every frosted surface in the app
/// (dock, drawer, sheets, dialogs, menus, toasts) is built from it. Numbers
/// come from [AppGlass]. See docs/glassmorphism.md.
///
/// Tag pills aren't glass: they're solid grey (`TagPill`, genre_pills.dart).
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = AppRadius.cardAll,
    this.shadow = false,
    this.accent,
  });

  final Widget child;
  final BorderRadius borderRadius;

  /// The ambient shadow ([AppShadows.ambient]) that lifts a floating panel
  /// off the page. Drawn outside the clip.
  final bool shadow;

  /// Tints the edge (a toast's success / error color). Never fills the glass.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final filter = ImageFilter.compose(
      outer: const ColorFilter.matrix(AppGlass.saturate),
      inner: ImageFilter.blur(
        sigmaX: AppGlass.panelBlur,
        sigmaY: AppGlass.panelBlur,
      ),
    );
    final edge = accent?.withValues(alpha: AppGlass.accentEdgeOpacity) ??
        AppGlass.panelEdge;
    Widget surface = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: filter,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(color: edge),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppGlass.panelTintLit, AppGlass.panelTintFar],
            ),
          ),
          child: child,
        ),
      ),
    );
    if (shadow) {
      surface = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: AppShadows.ambient,
        ),
        child: surface,
      );
    }
    return surface;
  }
}
