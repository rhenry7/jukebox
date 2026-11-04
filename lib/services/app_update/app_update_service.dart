import 'package:flutter/foundation.dart';

import 'app_update_platform.dart'
    if (dart.library.js_interop) 'app_update_platform_web.dart' as platform;

/// Notices when a newer web build is live, so an installed copy (an iPhone
/// home-screen app especially) doesn't stay on an old version.
///
/// Each deploy compiles a build id into the app (`--dart-define=BUILD_ID`,
/// from scripts/build_id.sh) and publishes the same id as app_version.json.
/// Local runs have no build id and never check.
class AppUpdateService {
  /// The build id this copy of the app was built with.
  static const String currentBuildId = String.fromEnvironment('BUILD_ID');

  /// Whether this build can check for updates at all.
  static bool get enabled => kIsWeb && currentBuildId.isNotEmpty;

  /// The live build id, when it differs from this one; otherwise null.
  static Future<String?> newerBuildId() async {
    if (!enabled) return null;
    final live = await platform.fetchLiveBuildId();
    return isNewerBuild(current: currentBuildId, live: live) ? live : null;
  }

  /// Reloads onto [buildId] right away, unless an automatic reload for it
  /// already happened (the CDN may still be serving the old files, and
  /// reloading again would loop). Returns whether it reloaded.
  static Future<bool> autoReload(String buildId) async {
    if (platform.readAutoReloadTarget() == buildId) return false;
    platform.writeAutoReloadTarget(buildId);
    await platform.reloadToLatest();
    return true;
  }

  /// Removes the caching service worker older deploys installed, which
  /// otherwise keeps serving stale files. Safe to call on every launch.
  static Future<void> removeLegacyServiceWorker() async {
    if (enabled) await platform.removeServiceWorkers();
  }

  /// Reloads onto the live version (the user asked to).
  static Future<void> reload() => platform.reloadToLatest();
}

/// True when [live] is a known build that isn't [current].
@visibleForTesting
bool isNewerBuild({required String current, required String? live}) =>
    current.isNotEmpty && live != null && live.isNotEmpty && live != current;
