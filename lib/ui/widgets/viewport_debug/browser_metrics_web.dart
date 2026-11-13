import 'package:web/web.dart' as web;

/// What the browser reports: the visible (visual) viewport, where it sits,
/// and the page's own height. On iPhones the keyboard shrinks the visual
/// viewport; Flutter's keyboard inset should equal page − visible.
List<String>? browserMetrics() {
  try {
    final vv = web.window.visualViewport;
    final doc = web.document.documentElement;
    return [
      'visual ${vv?.width.round()}×${vv?.height.round()} '
          'top ${vv?.offsetTop.round()}',
      'page h ${doc?.clientHeight} inner h ${web.window.innerHeight}',
      'scrollY ${web.window.scrollY.round()}',
    ];
  } catch (_) {
    return null;
  }
}
