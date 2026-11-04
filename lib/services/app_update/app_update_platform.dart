/// Browser hooks for [AppUpdateService]. This stub is used off the web, where
/// app stores handle updates.
library;

/// The build id of the version currently live, or null if unknown.
Future<String?> fetchLiveBuildId() async => null;

/// Drops cached app files and reloads the page onto the live version.
Future<void> reloadToLatest() async {}

/// Removes the service worker older deploys installed, and its caches.
Future<void> removeServiceWorkers() async {}

/// Remembers which build an automatic reload was for, so a stale CDN can't
/// cause a reload loop.
String? readAutoReloadTarget() => null;
void writeAutoReloadTarget(String buildId) {}
