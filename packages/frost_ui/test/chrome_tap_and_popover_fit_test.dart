import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_button_control.dart';

import 'support.dart';

void main() {
  Future<int Function()> pumpPage(WidgetTester tester, {required double width, required String title}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 844);
    addTearDown(tester.view.reset);
    var taps = 0;
    final tabs = FrostTabController(length: 2, vsync: const TestVSync());
    addTearDown(tabs.dispose);
    await tester.pumpWidget(
      frostTestApp(
        FrostPinnedChrome(
          chrome: FrostContentColumn(
            child: FrostHeaderSections(
              header: FrostPageHeader(
                title: FrostText(title),
                actions: [FrostToolbarItem.action(icon: testIcons.search, label: 'Search', onPressed: () {})],
              ),
              tabs: FrostTabBar(
                controller: tabs,
                scrollable: true,
                tabs: const [
                  FrostTab(label: 'A'),
                  FrostTab(label: 'B'),
                ],
              ),
            ),
          ),
          body: CustomScrollView(
            slivers: [
              const FrostChromeSpacer(),
              SliverToBoxAdapter(
                child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => taps++, child: const SizedBox(height: 3000)),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return () => taps;
  }

  const long = 'A page title long enough to leave no room for tabs';
  for (final (width, title, scroll, label) in [
    (1100.0, 'Page', 100.0, 'tabs in the header row'),
    (390.0, long, 20.0, 'tabs in their own row'),
    (390.0, long, 100.0, 'tabs in their own row after the header row slid away'),
  ]) {
    testWidgets('blank chrome takes the tap, the content below it does not: $label', (tester) async {
      final taps = await pumpPage(tester, width: width, title: title);
      await tester.drag(find.byType(CustomScrollView), Offset(0, -scroll));
      await tester.pumpAndSettle();
      final chrome = tester.getRect(find.byType(FrostHeaderSections)), tabs = tester.getRect(find.byType(FrostTabBar));
      await tester.tapAt(Offset(chrome.right - 8, tabs.center.dy));
      await tester.pumpAndSettle();
      expect(taps(), 0);
      // Below the rows on screen the content takes taps, including where a
      // slid-away row was.
      await tester.tapAt(Offset(chrome.center.dx, tabs.bottom + 8));
      await tester.pumpAndSettle();
      expect(taps(), 1);
      expect(tester.takeException(), isNull);
    });
  }

  for (final (content, label) in [(300.0, 'short'), (2000.0, 'tall')]) {
    testWidgets('a narrow popover with $label content fits it, up to large', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(411, 960);
      tester.view.padding = const FakeViewPadding(bottom: 15);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        frostTestApp(
          Center(
            child: FrostPopover(
              title: 'Ratings',
              builder: (context, focus, toggle) => FrostButtonControl(label: 'Filter', focusNode: focus, onPressed: toggle),
              contentBuilder: (_, _) => SizedBox(key: const ValueKey('content'), height: content),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();
      final box = find.byKey(const ValueKey('content'));
      if (content < 500) {
        expect(960 - tester.getBottomLeft(box).dy, 20 + 15);
      } else {
        final surface = find.ancestor(of: box, matching: find.byType(FrostSurface)).last;
        expect(tester.getRect(surface).top, greaterThan(0));
        expect(find.byType(Scrollable), findsWidgets);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
