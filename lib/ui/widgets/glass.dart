import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// How strong a [GlassSurface] is. See docs/glassmorphism.md.
enum GlassLevel {
  /// Light blur, clear white tint: tag pills and small controls sitting on
  /// album art or the page.
  pill,

  /// Heavy blur, dark tint: anything floating with text on it (dock, drawer,
  /// sheets, dialogs, menus, toasts).
  panel,
}

/// Frosted glass: whatever is behind it, blurred, under a tint that is
/// lighter at the top-left (where the light hits) and a faint light edge.
/// The one place the glass recipe lives; every frosted surface in the app is
/// built from it. Numbers come from [AppGlass].
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.level = GlassLevel.panel,
    this.borderRadius = AppRadius.cardAll,
    this.shadow = false,
    this.accent,
    this.grouped = false,
  });

  final Widget child;
  final GlassLevel level;
  final BorderRadius borderRadius;

  /// The ambient shadow ([AppShadows.ambient]) that lifts a floating panel
  /// off the page. Drawn outside the clip.
  final bool shadow;

  /// Tints the edge (a toast's success / error color). Never fills the glass.
  final Color? accent;

  /// Uses BackdropFilter.grouped, so many surfaces on screen (tag pills)
  /// share one capture of the background through the BackdropGroup in
  /// main.dart instead of one each.
  final bool grouped;

  @override
  Widget build(BuildContext context) {
    final pill = level == GlassLevel.pill;
    final blur = pill ? AppGlass.pillBlur : AppGlass.panelBlur;
    final ImageFilter filter = pill
        ? ImageFilter.blur(sigmaX: blur, sigmaY: blur)
        : ImageFilter.compose(
            outer: const ColorFilter.matrix(AppGlass.saturate),
            inner: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          );
    final edge =
        accent?.withValues(alpha: AppGlass.accentEdgeOpacity) ??
        (pill ? AppGlass.pillEdge : AppGlass.panelEdge);
    final glass = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(color: edge),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: pill
              ? const [AppGlass.pillTintLit, AppGlass.pillTintFar]
              : const [AppGlass.panelTintLit, AppGlass.panelTintFar],
        ),
      ),
      child: child,
    );
    Widget surface = ClipRRect(
      borderRadius: borderRadius,
      child: grouped
          ? BackdropFilter.grouped(filter: filter, child: glass)
          : BackdropFilter(filter: filter, child: glass),
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
