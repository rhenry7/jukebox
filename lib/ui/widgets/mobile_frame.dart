import 'package:flutter/material.dart';

/// Keeps the app phone-width on wide screens (desktop browsers): the app is
/// mobile-first, so instead of stretching, it sits in a centred column.
///
/// Use as `MaterialApp.builder`, so every route, bottom sheet and dialog
/// stays inside the column. Inside, [MediaQuery] reports the column's size,
/// so anything sized from the screen width lays out as it would on a phone.
class MobileFrame extends StatelessWidget {
  const MobileFrame({super.key, required this.child});

  /// Widest the app gets — a large phone.
  static const double maxWidth = 480;

  /// The empty space either side of the app: a soft grey, lighter than the
  /// app's near-black, so the app column stands out.
  static const Color sideColor = Color(0xFF2A292E);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.size.width <= maxWidth) return child;

    return ColoredBox(
      color: sideColor,
      child: Center(
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: Border.symmetric(
              vertical: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          child: SizedBox(
            width: maxWidth,
            child: ClipRect(
              child: MediaQuery(
                data: media.copyWith(
                  size: Size(maxWidth, media.size.height),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
