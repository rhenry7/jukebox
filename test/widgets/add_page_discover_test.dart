import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/providers/add_page_discover_provider.dart';
import 'package:flutter_test_project/ui/widgets/add_page_discover.dart';

import '../helpers/screen_harness.dart';

DiscoverTrack _t(int i) => (
  title: 'Song $i',
  artist: 'Artist $i',
  imageUrl: 'https://i.scdn.co/$i.jpg',
  spotifyUrl: null,
  averageScore: 4.5,
  reviewCount: i,
);

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required void Function(DiscoverTrack) onPick,
  }) => pumpScreen(
    tester,
    Scaffold(body: AddPageDiscover(onPickTrack: onPick)),
    overrides: [
      ...reviewScreenOverrides(),
      addPageTopRatedProvider.overrideWith(
        (ref) => [for (var i = 1; i <= 8; i++) _t(i)],
      ),
      addPageSuggestedReviewersProvider.overrideWith((ref) {
        final hidden = ref.watch(dismissedSuggestionsProvider);
        return [
          for (final r in [
            (
              userId: 'u1',
              displayName: 'soulFan',
              imageUrl: null,
              reviewCount: 12,
              sharedArtist: 'Masego',
            ),
            (
              userId: 'u2',
              displayName: 'rockFan',
              imageUrl: null,
              reviewCount: 42,
              sharedArtist: null,
            ),
          ])
            if (!hidden.contains(r.userId)) r,
        ];
      }),
    ],
  );

  testWidgets('highly rated songs: tap one to review it; show more', (
    tester,
  ) async {
    DiscoverTrack? picked;
    await pump(tester, onPick: (t) => picked = t);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Highly rated'), findsOneWidget);
    expect(find.text('Song 5'), findsOneWidget);
    expect(find.text('Song 6'), findsNothing);

    await tester.tap(find.text('Song 2'));
    expect(picked?.title, 'Song 2');

    await tester.tap(find.text('Show more'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Song 6'), findsOneWidget);
    expect(find.text('Show more'), findsNothing, reason: 'all 8 shown');
  });

  testWidgets('suggested reviewers: why, follow button, hide', (tester) async {
    await pump(tester, onPick: (_) {});
    await tester.pump(const Duration(milliseconds: 200));
    await tester.scrollUntilVisible(
      find.text('soulFan'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Also into Masego'), findsOneWidget);
    expect(find.text('42 reviews'), findsOneWidget);
    expect(find.text('Follow'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Hide').first);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('soulFan'), findsNothing);
    expect(find.text('rockFan'), findsOneWidget);
  });
}
