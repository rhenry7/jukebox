import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/ui/widgets/mobile_frame.dart';

void main() {
  Future<Size> appSize(WidgetTester tester, Size screen) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late Size seen;
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MobileFrame(child: child!),
      home: Builder(builder: (context) {
        seen = MediaQuery.sizeOf(context);
        return const Scaffold(body: SizedBox.expand(key: Key('page')));
      }),
    ));
    expect(tester.getSize(find.byKey(const Key('page'))).width, seen.width);
    return seen;
  }

  testWidgets('desktop: app is a phone-width column', (tester) async {
    final size = await appSize(tester, const Size(1440, 900));
    expect(size, const Size(MobileFrame.maxWidth, 900));
  });

  testWidgets('phone: app uses the full screen', (tester) async {
    final size = await appSize(tester, const Size(393, 852));
    expect(size, const Size(393, 852));
  });
}
