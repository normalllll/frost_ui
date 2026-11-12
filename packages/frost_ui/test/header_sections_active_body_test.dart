import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'page_support.dart';
import 'support.dart';

Finder get _header => find.byType(FrostPageHeader);
Finder get _glass => find.byType(FrostPinnedChromeGlass);
Finder _row(int section, int index) => find.text('S$section row $index', skipOffstage: false);
const _labels = ['New', 'Hot', 'Random', 'Top'];

void main() {
  late List<int> refreshed;
  setUp(() => refreshed = []);

  void viewport(WidgetTester tester, double width) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 800);
    addTearDown(tester.view.reset);
  }

  Widget page({bool refresh = false}) => frostTestApp(
    FrostDefaultTabController(
      length: _labels.length,
      child: sectionedPage(
        header: FrostPageHeader(
          leading: [
            FrostTitleMenu(
              title: 'yande',
              entries: [FrostMenuAction('konachan', onSelected: () {})],
            ),
          ],
          actions: [
            FrostToolbarItem.action(icon: testIcons.filter, label: 'Filter', onPressed: () {}),
            FrostToolbarItem.action(icon: testIcons.download, label: 'Batch', onPressed: () {}),
            FrostToolbarItem.action(icon: testIcons.more, label: 'More', onPressed: () {}),
          ],
        ),
        tabs: FrostTabBar(scrollable: true, tabs: [for (final label in _labels) FrostTab(label: label)]),
        sections: _labels.length,
        onRefresh: (section) => refresh
            ? () async {
                refreshed.add(section);
                return true;
              }
            : null,
        slivers: (context, section) => [SliverList.builder(itemCount: 80, itemBuilder: (_, i) => SizedBox(height: 40, child: Text('S$section row $i')))],
      ),
    ),
    platform: TargetPlatform.android,
  );

  ScrollPosition section(WidgetTester tester, int index) => Scrollable.of(tester.element(_row(index, 0))).position;
  double opacity(WidgetTester tester) => tester.widget<FrostPinnedChromeGlass>(_glass).opacity;

  testWidgets('the sliding header row and the glass follow the section on screen', (tester) async {
    viewport(tester, 412);
    await tester.pumpWidget(page());
    final header = tester.getRect(_header);
    expect(opacity(tester), 0);

    await tester.dragFrom(const Offset(200, 600), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getRect(_header).bottom, moreOrLessEquals(0, epsilon: .5));
    expect(opacity(tester), 1);

    // A section at its top cannot fill the row's place: the row comes back
    // and the glass clears.
    await tester.tap(find.text('Hot'));
    await tester.pumpAndSettle();
    expect(tester.getRect(_header).top, 0);
    expect(opacity(tester), 0);
    // Scrolling this section moves the bar; the scrolled one is off screen.
    section(tester, 1).jumpTo(12);
    await tester.pump();
    expect(opacity(tester), moreOrLessEquals(.5, epsilon: .01));

    // Back on the scrolled section the row keeps its place until scrolling
    // asks again, and the glass returns.
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    expect(tester.getRect(_header).top, 0);
    expect(opacity(tester), 1);
    await tester.dragFrom(const Offset(200, 600), const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(tester.getRect(_header).top, -header.height);
    expect(tester.takeException(), isNull);
  });

  testWidgets('each section pulls to refresh on its own below both rows', (tester) async {
    viewport(tester, 412);
    await tester.pumpWidget(page(refresh: true));
    final tabRow = tester.getRect(find.byType(FrostTabBar));
    expect(tester.getTopLeft(_row(0, 0)).dy, tabRow.bottom);
    Future<void> pull() async {
      final gesture = await tester.startGesture(const Offset(200, 300));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();
    }

    await pull();
    expect(refreshed, [0]);
    await tester.tap(find.text('Hot'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(_row(1, 0)).dy, tabRow.bottom);
    await pull();
    expect(refreshed, [0, 1]);
    expect(tester.getTopLeft(_row(1, 0)).dy, tabRow.bottom);
    expect(tester.takeException(), isNull);
  });
}
