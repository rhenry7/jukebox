/// Browser hooks for [openOnSpotify] (web build).
library;

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

bool isIosHomeScreenApp() {
  try {
    final standalone =
        web.window.matchMedia('(display-mode: standalone)').matches;
    final ua = web.window.navigator.userAgent;
    // iPadOS reports itself as a Mac, but with touch.
    final iOS = RegExp('iPhone|iPad|iPod').hasMatch(ua) ||
        (ua.contains('Macintosh') && web.window.navigator.maxTouchPoints > 1);
    return standalone && iOS;
  } catch (_) {
    return false;
  }
}

/// Navigates to the `spotify:` link, which hands straight to the app without
/// leaving a page behind, then waits to see whether the app took over (this
/// page goes into the background).
Future<bool> tryOpenApp(Uri appUri) async {
  try {
    web.window.location.href = appUri.toString();
    for (var i = 0; i < 15; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (web.document.hidden) return true;
    }
  } catch (e) {
    debugPrint('[SPOTIFY] Could not open the app: $e');
  }
  return false;
}
