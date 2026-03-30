import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' as flutter;

const _words = [
  'Vibing', 'Looping', 'Sampling', 'Layering', 'Improvising', 'Remixing',
  'Harmonizing', 'Composing', 'Arranging', 'Producing', 'Scratching',
  'Beatmaking', 'Freestyling', 'Noodling', 'Shredding', 'Jamming',
  'Swinging', 'Plucking', 'Strumming', 'Vamping',
];

class DiscoBallLoading extends StatefulWidget {
  const DiscoBallLoading({super.key});

  @override
  State<DiscoBallLoading> createState() => _DiscoBallLoadingState();
}

class _DiscoBallLoadingState extends State<DiscoBallLoading> {
  late String _word;
  int _dotCount = 1;
  late Timer _wordTimer;
  late Timer _dotTimer;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _word = _words[_rng.nextInt(_words.length)];

    // Cycle dots every second: 1 → 2 → 3 → 1 ...
    _dotTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _dotCount = (_dotCount % 3) + 1;
        });
      }
    });

    // Cycle to a new random word every 3 seconds
    _wordTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        setState(() {
          String next;
          do {
            next = _words[_rng.nextInt(_words.length)];
          } while (next == _word && _words.length > 1);
          _word = next;
          _dotCount = 1;
        });
      }
    });
  }

  @override
  void dispose() {
    _wordTimer.cancel();
    _dotTimer.cancel();
    super.dispose();
  }

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

        final dots = '.' * _dotCount;

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
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                  child: Text(
                    '$_word$dots',
                    key: ValueKey(_word),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
