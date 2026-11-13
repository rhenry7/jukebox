import 'package:flutter/widgets.dart';

/// Scrolls [child] (a text field) to the middle of the visible area when it
/// gains focus. Flutter only scrolls a field into view when the keyboard
/// first opens; moving to the next field with the keyboard already up (Next,
/// or a tap lower down) left it behind the keyboard on phones.
class RevealOnFocus extends StatelessWidget {
  const RevealOnFocus({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      // Only listens: the field inside takes the focus.
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) {
        if (!focused) return;
        // After the frame, so the page has made room for the keyboard.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          Scrollable.ensureVisible(
            context,
            alignment: 0.5,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        });
      },
      child: child,
    );
  }
}
