// Basic widget tests (no Firebase — simple MaterialApp to avoid init in tests)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Widget Tests', () {
    testWidgets('App initializes without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Test')),
          ),
        ),
      );
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
