import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

void main() {
  for (final width in [380.0, 900.0]) {
    testWidgets('an overflowing tab bar in a sectioned header keeps the offset it was scrolled to ($width wide)', (tester) async {
      await tester.pumpWidget(
        frostTestApp(
          Material(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: FrostDefaultTabController(
                  length: 3,
                  child: FrostHeaderSections(
                    header: const FrostPageHeader(title: FrostText('History')),
                    tabs: FrostTabBar(
                      scrollable: true,
                      tabs: [
                        const FrostTab(label: 'Illustrations and manga long label'),
                        FrostTab(label: 'Novels ${'and series ' * (width ~/ 120)}'),
                        const FrostTab(label: 'Last'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final strip = tester.state<ScrollableState>(find.descendant(of: find.byType(FrostTabBar), matching: find.byType(Scrollable))).position;
      expect(strip.maxScrollExtent, greaterThan(0), reason: 'the tabs overflow');

      await tester.ensureVisible(find.text('Last'));
      await tester.pump();
      final scrolled = strip.pixels;
      expect(scrolled, greaterThan(0));
      await tester.pumpAndSettle();
      expect(strip.pixels, scrolled, reason: 'laying the header out again keeps the offset');

      final bar = tester.getRect(find.byType(FrostTabBar));
      final last = tester.getRect(find.text('Last'));
      expect(bar.contains(last.center), isTrue);
      await tester.tap(find.text('Last'));
      await tester.pumpAndSettle();
      expect(FrostDefaultTabController.of(tester.element(find.byType(FrostTabBar))).index, 2);
      expect(tester.takeException(), isNull);
    });
  }
}
