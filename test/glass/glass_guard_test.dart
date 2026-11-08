import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Keeps glassmorphism in one place (see docs/glassmorphism.md): frosted
/// surfaces are built with GlassSurface and toasts with showAppToast, so
/// every one looks the same and a tweak to the recipe reaches all of them.
void main() {
  final libFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  List<String> filesMatching(RegExp pattern, Set<String> allowed) => [
        for (final f in libFiles)
          if (!allowed.contains(f.path) &&
              pattern.hasMatch(f.readAsStringSync()))
            f.path,
      ];

  test('only GlassSurface blurs the background', () {
    expect(
      filesMatching(
        RegExp(r'BackdropFilter(\.grouped)?\(|ImageFilter\.blur\('),
        {'lib/ui/widgets/glass.dart'},
      ),
      isEmpty,
      reason: 'Build frosted glass with GlassSurface '
          '(lib/ui/widgets/glass.dart). See docs/glassmorphism.md.',
    );
  });

  test('only showAppToast shows toasts', () {
    expect(
      filesMatching(
        RegExp(r'showSnackBar\(|\bSnackBar\('),
        {'lib/ui/widgets/app_toast.dart'},
      ),
      isEmpty,
      reason: 'Show toasts with showAppToast '
          '(lib/ui/widgets/app_toast.dart). See docs/glassmorphism.md.',
    );
  });
}
