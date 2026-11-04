/// Browser hooks for [AppUpdateService] (web build).
library;

import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

const _reloadTargetKey = 'reverb_auto_reload_target';

/// The build id of the version currently live, from app_version.json (written
/// by the deploy). The timestamp query skips any cached copy.
Future<String?> fetchLiveBuildId() async {
  try {
    final url = Uri.base.resolve(
        'app_version.json?t=${DateTime.now().millisecondsSinceEpoch}');
    final response = await http.get(url).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;
    final id = (jsonDecode(response.body) as Map<String, dynamic>)['buildId'];
    return id is String && id.isNotEmpty ? id : null;
  } catch (e) {
    debugPrint('[UPDATE] Could not check for a new version: $e');
    return null;
  }
}

/// Unregisters service workers and clears their caches, then reloads.
Future<void> reloadToLatest() async {
  await removeServiceWorkers();
  web.window.location.reload();
}

/// Unregisters service workers and clears their caches: older deploys
/// installed one that kept serving stale files.
Future<void> removeServiceWorkers() async {
  try {
    final container = web.window.navigator.serviceWorker;
    final registrations = (await container.getRegistrations().toDart).toDart;
    for (final r in registrations) {
      await r.unregister().toDart;
    }
  } catch (e) {
    debugPrint('[UPDATE] Could not remove service workers: $e');
  }
  try {
    final caches = web.window.caches;
    final names = (await caches.keys().toDart).toDart;
    for (final name in names) {
      await caches.delete(name.toDart).toDart;
    }
  } catch (e) {
    debugPrint('[UPDATE] Could not clear caches: $e');
  }
}

String? readAutoReloadTarget() {
  try {
    return web.window.localStorage.getItem(_reloadTargetKey);
  } catch (_) {
    return null;
  }
}

void writeAutoReloadTarget(String buildId) {
  try {
    web.window.localStorage.setItem(_reloadTargetKey, buildId);
  } catch (_) {}
}
