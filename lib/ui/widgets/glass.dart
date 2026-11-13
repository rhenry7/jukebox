import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Frosted glass: whatever is behind it, blurred, under a dark tint that is
/// lighter at the top-left (where the light hits), with Apple's iOS 26
/// "Liquid Glass" light on it ([LiquidRim]): a bright rim, an inner glow and
/// a sheen.
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
    Widget surface = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: filter,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppGlass.panelTintLit, AppGlass.panelTintFar],
            ),
          ),
          // The light on the glass, painted over the content's edges.
          child: CustomPaint(
            foregroundPainter: LiquidRim(
              borderRadius: borderRadius,
              accent: accent,
            ),
            child: child,
          ),
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

/// The light on a Liquid Glass surface (iOS 26 style), painted over it: a
/// rim brightest at the top-left that glints again at the bottom-right, a
/// thin glow just inside the top edge, and a faint sheen over the upper part.
/// Gradients and strokes only, so it costs nothing like a blur does. With an
/// [accent] (a toast's success / error color) the rim takes that color.
class LiquidRim extends CustomPainter {
  const LiquidRim({required this.borderRadius, this.accent});

  final BorderRadius borderRadius;
  final Color? accent;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final outer = borderRadius.toRRect(rect).deflate(0.5);

    // Sheen: the upper part catches a little light.
    canvas.drawRRect(
      outer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [AppGlass.sheen, Color(0x00FFFFFF)],
        ).createShader(rect),
    );

    // Inner glow just under the top edge.
    canvas.drawRRect(
      outer.deflate(1.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment(0, -0.2),
          colors: [AppGlass.innerGlow, Color(0x00FFFFFF)],
        ).createShader(rect),
    );

    // The rim: lit corner, dim sides, softer far glint.
    final a = accent;
    canvas.drawRRect(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0, 0.45, 1],
          colors: a == null
              ? const [AppGlass.rimLit, AppGlass.rimMid, AppGlass.rimFar]
              : [
                  a.withValues(alpha: AppGlass.accentEdgeOpacity),
                  a.withValues(alpha: 0.15),
                  a.withValues(alpha: 0.35),
                ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(LiquidRim old) =>
      old.borderRadius != borderRadius || old.accent != accent;
}

/// A small Liquid Glass control without a blur (round header buttons, search
/// pills, the dock's selection lens): a faint white fill with [LiquidRim]'s
/// light. Over the app's black backgrounds a blur would show nothing, and the
/// light on the edge is what reads as glass, at no GPU cost.
class LiquidSurface extends StatelessWidget {
  const LiquidSurface({
    super.key,
    required this.borderRadius,
    required this.child,
  });

  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppGlass.liquidFillTop, AppGlass.liquidFillBottom],
        ),
      ),
      child: CustomPaint(
        foregroundPainter: LiquidRim(borderRadius: borderRadius),
        child: child,
      ),
    );
  }
}
