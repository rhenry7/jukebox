import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/providers/recommended_reviews_provider.dart';

/// Invisible widget that starts loading the For You list as soon as the main
/// navigation mounts, so it's ready by the time the user opens that tab.
///
/// The read is fire-and-forget: the tab handles its own loading and error
/// states.
class DataPreloader extends ConsumerStatefulWidget {
  final Widget child;

  const DataPreloader({super.key, required this.child});

  @override
  ConsumerState<DataPreloader> createState() => _DataPreloaderState();
}

class _DataPreloaderState extends ConsumerState<DataPreloader> {
  bool _preloaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_preloaded) {
        _preloaded = true;
        _preloadData();
      }
    });
  }

  void _preloadData() {
    try {
      // ignore: unused_local_variable
      final _ = ref.read(recommendedReviewsProvider.future);
    } catch (e) {
      debugPrint('[PRELOADER] recommendedReviewsProvider trigger failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
