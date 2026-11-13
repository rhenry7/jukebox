import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'browser_metrics.dart'
    if (dart.library.js_interop) 'browser_metrics_web.dart'
    as browser;

/// Whether the page was opened with `?debugViewport=1` (web only).
bool get viewportDebugRequested =>
    kIsWeb && Uri.base.queryParameters['debugViewport'] == '1';

/// A small panel in the corner with the sizes Flutter lays out with (screen,
/// keyboard inset, safe areas) next to what the browser reports (visual
/// viewport, page height). Opened with `?debugViewport=1`, to diagnose
/// keyboard layout bugs on phones from a screenshot: with the keyboard up,
/// Flutter's "space left" should match the browser's visible height.
class ViewportDebugOverlay extends StatelessWidget {
  const ViewportDebugOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!viewportDebugRequested) return child;
    final mq = MediaQuery.of(context);
    final b = browser.browserMetrics();
    final left = mq.size.height - mq.viewInsets.bottom;
    final lines = [
      'flutter size ${mq.size.width.round()}×${mq.size.height.round()}',
      'keyboard inset ${mq.viewInsets.bottom.round()}',
      'space left ${left.round()}',
      'safe top ${mq.viewPadding.top.round()} bottom ${mq.viewPadding.bottom.round()}',
      'dpr ${mq.devicePixelRatio.toStringAsFixed(2)}',
      if (b != null) ...b,
    ];
    return Stack(
      children: [
        child,
        Positioned(
          top: mq.viewPadding.top + 4,
          right: 4,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.all(6),
              color: const Color(0xCC000000),
              child: Text(
                lines.join('\n'),
                style: const TextStyle(
                  color: Color(0xFF3FFF8B),
                  fontSize: 10,
                  height: 1.3,
                  decoration: TextDecoration.none,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
