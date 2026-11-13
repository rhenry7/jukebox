import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/ui/theme/tokens.dart';
import 'package:flutter_test_project/ui/widgets/glass.dart';
import 'package:flutter_test_project/ui/widgets/round_icon_button.dart';

Iterable<LiquidRim> _rims(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((p) => p.foregroundPainter)
    .whereType<LiquidRim>();

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('glass surfaces carry the Liquid light, tinted by an accent', (
    tester,
  ) async {
    await _pump(
      tester,
      const GlassSurface(
        accent: AppColors.success,
        child: SizedBox(width: 100, height: 40),
      ),
    );
    final rim = _rims(tester).single;
    expect(rim.accent, AppColors.success);
    expect(rim.borderRadius, AppRadius.cardAll);
  });

  testWidgets('round buttons are Liquid controls (no blur)', (tester) async {
    await _pump(
      tester,
      RoundIconButton(icon: Icons.menu, tooltip: 'Menu', onTap: () {}),
    );
    expect(find.byType(LiquidSurface), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(_rims(tester), hasLength(1));
  });

  test('the rim repaints only when its shape or accent changes', () {
    const a = LiquidRim(borderRadius: AppRadius.pillAll);
    expect(
      a.shouldRepaint(const LiquidRim(borderRadius: AppRadius.pillAll)),
      isFalse,
    );
    expect(
      a.shouldRepaint(const LiquidRim(borderRadius: AppRadius.cardAll)),
      isTrue,
    );
    expect(
      a.shouldRepaint(
        const LiquidRim(borderRadius: AppRadius.pillAll, accent: Colors.red),
      ),
      isTrue,
    );
  });
}
