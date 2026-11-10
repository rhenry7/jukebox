import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/ui/theme/tokens.dart';
import 'package:flutter_test_project/ui/widgets/app_toast.dart';
import 'package:flutter_test_project/ui/widgets/glass.dart';

Future<BuildContext> _pump(WidgetTester tester) async {
  late BuildContext ctx;
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(builder: (c) {
        ctx = c;
        return const SizedBox.expand();
      }),
    ),
  ));
  return ctx;
}

void main() {
  testWidgets('a toast is a floating glass panel with its message',
      (tester) async {
    final context = await _pump(tester);
    showAppToast(context, 'Review deleted', tone: ToastTone.success);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Review deleted'), findsOneWidget);
    final bar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(bar.behavior, SnackBarBehavior.floating);
    expect(bar.backgroundColor, Colors.transparent);
    final glass = tester.widget<GlassSurface>(
      find.ancestor(
        of: find.text('Review deleted'),
        matching: find.byType(GlassSurface),
      ),
    );
    expect(glass.accent, AppColors.success, reason: 'tone tints the edge');
    expect(find.byIcon(ToastTone.success.icon!), findsOneWidget);
  });

  testWidgets('info toasts have no icon or accent', (tester) async {
    final context = await _pump(tester);
    showAppToast(context, 'You have signed out');
    await tester.pump(const Duration(milliseconds: 300));
    final glass = tester.widget<GlassSurface>(find.byType(GlassSurface));
    expect(glass.accent, isNull);
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('a new toast replaces the one showing', (tester) async {
    final context = await _pump(tester);
    showAppToast(context, 'First');
    await tester.pump(const Duration(milliseconds: 300));
    showAppToast(context, 'Second', tone: ToastTone.error);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
  });

  testWidgets('tapping a toast dismisses it', (tester) async {
    final context = await _pump(tester);
    showAppToast(context, 'Tap me');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300)); // fully in
    await tester.tap(find.text('Tap me'));
    await tester.pump(); // starts the exit animation
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(); // removed once it has finished
    expect(find.text('Tap me'), findsNothing);
  });
}
