import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/app_update/app_update_service.dart';
import '../theme/tokens.dart';

/// Keeps a deployed web app on the latest version (see [AppUpdateService]):
///  - on launch, a newer live version reloads the app straight away;
///  - on returning to the app, and every [checkEvery] while it's open, a
///    newer version shows an "Update" pill instead — reloading mid-use could
///    lose something being typed.
///
/// Use inside `MaterialApp.builder`. Does nothing in local runs and off the
/// web.
class AppUpdateWatcher extends StatefulWidget {
  const AppUpdateWatcher({super.key, required this.child});

  static const Duration checkEvery = Duration(minutes: 15);

  final Widget child;

  @override
  State<AppUpdateWatcher> createState() => _AppUpdateWatcherState();
}

class _AppUpdateWatcherState extends State<AppUpdateWatcher> {
  AppLifecycleListener? _lifecycle;
  Timer? _timer;
  bool _updateReady = false;
  bool _reloading = false;

  @override
  void initState() {
    super.initState();
    if (!AppUpdateService.enabled) return;
    AppUpdateService.removeLegacyServiceWorker();
    _checkOnLaunch();
    _lifecycle = AppLifecycleListener(onResume: _check);
    _timer = Timer.periodic(AppUpdateWatcher.checkEvery, (_) => _check());
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkOnLaunch() async {
    final newer = await AppUpdateService.newerBuildId();
    if (newer == null) return;
    debugPrint('[UPDATE] Newer version $newer is live; reloading');
    if (!await AppUpdateService.autoReload(newer) && mounted) {
      setState(() => _updateReady = true);
    }
  }

  Future<void> _check() async {
    if (_updateReady) return;
    final newer = await AppUpdateService.newerBuildId();
    if (newer != null && mounted) setState(() => _updateReady = true);
  }

  Future<void> _reload() async {
    setState(() => _reloading = true);
    await AppUpdateService.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_updateReady)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Center(
                  child: _UpdatePill(
                    reloading: _reloading,
                    onUpdate: _reload,
                    onDismiss: () => setState(() => _updateReady = false),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _UpdatePill extends StatelessWidget {
  const _UpdatePill({
    required this.reloading,
    required this.onUpdate,
    required this.onDismiss,
  });

  final bool reloading;
  final VoidCallback onUpdate;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerHigh,
      shape: StadiumBorder(
        side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.lg),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'A new version is available',
              style: TextStyle(color: AppColors.onSurface, fontSize: 13),
            ),
            const SizedBox(width: AppSpacing.xs),
            TextButton(
              onPressed: reloading ? null : onUpdate,
              style: TextButton.styleFrom(foregroundColor: AppColors.secondary),
              child: Text(reloading ? 'Updating…' : 'Update'),
            ),
            IconButton(
              tooltip: 'Later',
              onPressed: onDismiss,
              icon: const Icon(Icons.close,
                  size: 18, color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
