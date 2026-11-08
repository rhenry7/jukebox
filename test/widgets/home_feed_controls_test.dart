import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/providers/home_feed_controls.dart';
import 'package:flutter_test_project/ui/widgets/home_feed_controls.dart';

Future<ProviderContainer> _pump(WidgetTester tester) async {
  final container = ProviderContainer(
    overrides: [
      homeTagChoicesProvider.overrideWithValue(const ['rock', 'R&B', 'jazz']),
    ],
  );
  addTearDown(container.dispose);
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: HomeFeedControls(),
          ),
        ),
      ),
    ),
  );
  return container;
}

void main() {
  testWidgets('tapping tags filters; tapping again or All clears', (
    tester,
  ) async {
    final c = await _pump(tester);
    expect(find.text('All'), findsOneWidget);

    await tester.tap(find.text('R&B'));
    await tester.pump();
    await tester.tap(find.text('jazz'));
    await tester.pump();
    expect(c.read(homeTagFilterProvider), {'r&b', 'jazz'});

    await tester.tap(find.text('R&B'));
    await tester.pump();
    expect(c.read(homeTagFilterProvider), {'jazz'});

    await tester.tap(find.text('All'));
    await tester.pump();
    expect(c.read(homeTagFilterProvider), isEmpty);
  });

  testWidgets('the sort button opens the options and picks one', (
    tester,
  ) async {
    final c = await _pump(tester);

    await tester.tap(find.byTooltip('Sort reviews'));
    await tester.pumpAndSettle();
    for (final s in HomeSort.values) {
      expect(find.text(s.label), findsOneWidget);
    }

    await tester.tap(find.text('Rating: high to low'));
    await tester.pumpAndSettle();
    expect(c.read(homeSortProvider), HomeSort.ratingHigh);
    expect(find.text('Most recent'), findsNothing, reason: 'menu closed');
  });

  testWidgets('with tags picked, the menu offers to clear them', (
    tester,
  ) async {
    final c = await _pump(tester);
    c.read(homeTagFilterProvider.notifier).state = {'rock'};
    await tester.pump();

    await tester.tap(find.byTooltip('Sort reviews'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear tag filters'));
    await tester.pumpAndSettle();
    expect(c.read(homeTagFilterProvider), isEmpty);
  });
}
