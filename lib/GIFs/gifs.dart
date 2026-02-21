import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' as flutter;

class DiscoBallLoading extends StatelessWidget {
  const DiscoBallLoading({super.key});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaSize = MediaQuery.sizeOf(context);
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : mediaSize.width;
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : mediaSize.height;

        final minSide =
            availableWidth < availableHeight ? availableWidth : availableHeight;
        final compact = availableWidth < 120 || availableHeight < 120;
        final loaderSize = compact
            ? (minSide * 0.72).clamp(16.0, 48.0)
            : (minSide * 0.34).clamp(56.0, 220.0);

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: loaderSize,
                height: loaderSize,
                child: flutter.Image.asset(
                  'lib/assets/images/discoball_loading.png',
                  fit: BoxFit.contain,
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 8),
                const Text(
                  'Thinking...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
