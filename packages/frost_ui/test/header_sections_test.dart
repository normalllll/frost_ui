import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'support.dart';

Finder get _header => find.byType(FrostPageHeader);
Finder get _tabs => find.byType(FrostTabBar);
Finder _row(int index) => find.text('row $index');
const _trailing = SizedBox(key: ValueKey('week'), width: 56, height: 28);

void main() {
  late FocusNode search;
  late TextEditingController query;
  late List<int> taps;
  setUp(() {
    search = FocusNode(debugLabel: 'search');
    query = TextEditingController();
    taps = [];
  });
  tearDown(() {
    search.dispose();
    query.dispose();
  });

  void viewport(WidgetTester tester, double width) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 800);
    addTearDown(tester.view.reset);
  }

  Widget page({bool rtl = false, bool reduceMotion = false, bool searchField = false, Widget? trailing, FrostRefreshAction? onRefresh}) {
    Widget layout(List<Widget> leading) => FrostBrowseLayout(
      header: FrostPageHeader(
        leading: [
          FrostTitleMenu(
            title: 'yande',
            entries: [FrostMenuAction('konachan', onSelected: () {})],
          ),
        ],
        middle: searchField ? FrostSearchInput(controller: query, focusNode: search, placeholder: 'Search', onSubmitted: (_) {}) : null,
        actions: [
          FrostToolbarItem.action(icon: testIcons.filter, label: 'Filter', onPressed: () {}),
          FrostToolbarItem.action(icon: testIcons.download, label: 'Batch', onPressed: () {}),
          FrostToolbarItem.action(icon: testIcons.more, label: 'More', onPressed: () {}),
        ],
      ),
      sections: FrostHeaderSections(
        tabs: const FrostTabBar(
          scrollable: true,
          tabs: [
            FrostTab(label: 'New'),
            FrostTab(label: 'Hot'),
            FrostTab(label: 'Random'),
          ],
        ),
        trailing: trailing,
      ),
      slivers: [
        ...leading,
        SliverList.builder(
          itemCount: 80,
          itemBuilder: (_, i) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps.add(i),
            child: SizedBox(height: 40, child: Text('row $i')),
          ),
        ),
      ],
    );
    return frostTestApp(
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
          child: Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: DefaultTabController(
              length: 3,
              child: onRefresh == null
                  ? layout(const [])
                  : FrostRefreshView(onRefresh: onRefresh, builder: (context, physics, locators) => layout([locators.sliverHeader!])),
            ),
          ),
        ),
      ),
    );
  }

  double top(WidgetTester tester, Finder finder) => tester.getTopLeft(finder).dy;
  ScrollPosition content(WidgetTester tester) =>
      tester.stateList<ScrollableState>(find.byType(Scrollable)).firstWhere((state) => state.position.axis == Axis.vertical).position;

  Future<void> scrollContent(WidgetTester tester, double by) async {
    await tester.dragFrom(const Offset(200, 600), Offset(0, -by));
    await tester.pumpAndSettle();
  }

  testWidgets('a wide header row holds the tabs between its title and actions as one pinned row', (tester) async {
    viewport(tester, 1147);
    await tester.pumpWidget(page(trailing: _trailing));
    final header = tester.getRect(_header), tabs = tester.getRect(_tabs);
    expect(tabs.center.dy, moreOrLessEquals(header.center.dy, epsilon: .5));
    expect(tabs.left, greaterThan(tester.getRect(find.byType(FrostTitleMenu)).right + FrostGap.section - 1));
    expect(tabs.right, lessThan(tester.getRect(find.bySemanticsLabel('Filter')).left));
    // The trailing control follows the tabs in the same row.
    expect(tester.getRect(find.byKey(const ValueKey('week'))).left, moreOrLessEquals(tabs.right + FrostGap.related, epsilon: .5));
    expect(tester.getRect(find.byKey(const ValueKey('week'))).center.dy, moreOrLessEquals(header.center.dy, epsilon: .5));
    expect(top(tester, _row(0)), header.bottom);

    // One row: nothing slides away with scrolling.
    await scrollContent(tester, 300);
    expect(tester.getRect(_header), header);
    expect(tester.getRect(_tabs), tabs);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a right-to-left header row holds the tabs after its title', (tester) async {
    viewport(tester, 1147);
    await tester.pumpWidget(page(trailing: _trailing, rtl: true));
    final header = tester.getRect(_header), tabs = tester.getRect(_tabs);
    expect(tabs.center.dy, moreOrLessEquals(header.center.dy, epsilon: .5));
    expect(tabs.right, lessThan(tester.getRect(find.byType(FrostTitleMenu)).left - FrostGap.section + 1));
    expect(tabs.left, greaterThan(tester.getRect(find.bySemanticsLabel('Filter')).right));
    expect(tester.getRect(find.byKey(const ValueKey('week'))).right, moreOrLessEquals(tabs.left - FrostGap.related, epsilon: .5));
  });

  testWidgets('a narrow header keeps the tabs in their own pinned row below it', (tester) async {
    viewport(tester, 412);
    await tester.pumpWidget(page(trailing: _trailing));
    final header = tester.getRect(_header), tabs = tester.getRect(_tabs);
    expect(header.top, 0);
    expect(tabs.top, header.bottom);
    // Labels share the header's start line.
    expect(tester.getTopLeft(find.text('New')).dx, tester.getTopLeft(find.text('yande')).dx);
    // The trailing control ends the tab row on the content edge.
    expect(tester.getRect(find.byKey(const ValueKey('week'))).right, moreOrLessEquals(header.right, epsilon: .5));
    expect(top(tester, _row(0)), tabs.bottom);
  });

  testWidgets('the narrow header row follows the scroll direction while the tab row stays', (tester) async {
    viewport(tester, 412);
    await tester.pumpWidget(page());
    final header = tester.getRect(_header), tabs = tester.getRect(_tabs);
    final position = content(tester);

    await scrollContent(tester, 300);
    expect(tester.getRect(_header).bottom, moreOrLessEquals(0, epsilon: .5));
    expect(tester.getRect(_tabs).top, moreOrLessEquals(0, epsilon: .5));
    // The body keeps the reserved height: rows sit where the offset puts them.
    final row = (position.pixels / 40).ceil();
    expect(top(tester, _row(row)), moreOrLessEquals(tabs.bottom + row * 40 - position.pixels, epsilon: .5));
    // The glass ends with the visible tab row, and the place of the header
    // row belongs to the content.
    final glass = find.descendant(of: find.byType(FrostPinnedChromeGlass), matching: find.byType(Positioned)).first;
    expect(tester.widget<Positioned>(glass).bottom, moreOrLessEquals(header.height, epsilon: .5));
    await tester.tapAt(Offset(200, tabs.bottom - 4));
    expect(taps, isNotEmpty);

    final pixels = position.pixels;
    await scrollContent(tester, -40);
    expect(tester.getRect(_header).top, moreOrLessEquals(0, epsilon: .5));
    expect(tester.getRect(_tabs).top, moreOrLessEquals(header.bottom, epsilon: .5));
    final back = (position.pixels / 40).ceil();
    expect(position.pixels, lessThan(pixels));
    expect(top(tester, _row(back)), moreOrLessEquals(tabs.bottom + back * 40 - position.pixels, epsilon: .5));
  });

  testWidgets('the header row waits until content can fill its place', (tester) async {
    viewport(tester, 412);
    await tester.pumpWidget(page());
    await scrollContent(tester, 30);
    expect(tester.getRect(_header).top, 0);
  });

  testWidgets('reduced motion hides and shows the header row without a transition', (tester) async {
    viewport(tester, 412);
    await tester.pumpWidget(page(reduceMotion: true));
    final header = tester.getRect(_header);
    await tester.dragFrom(const Offset(200, 600), const Offset(0, -300));
    await tester.pump();
    expect(tester.getRect(_header).top, -header.height);
    await tester.dragFrom(const Offset(200, 600), const Offset(0, 40));
    await tester.pump();
    expect(tester.getRect(_header).top, 0);
  });

  testWidgets('a focused or expanded header search keeps the header row shown', (tester) async {
    viewport(tester, 412);
    await tester.pumpWidget(page(searchField: true));
    search.requestFocus();
    await tester.pumpAndSettle();
    // The narrow row expands its search over the row.
    expect(find.text('L.cancel'), findsOneWidget);
    await scrollContent(tester, 300);
    expect(tester.getRect(_header).top, 0);

    // Focus left the field, but the search is still open over the row.
    search.unfocus();
    await tester.pumpAndSettle();
    await scrollContent(tester, 300);
    expect(tester.getRect(_header).top, 0);

    // Collapsed and unfocused, the row slides away; focus brings it back.
    await tester.tap(find.text('L.cancel'));
    await tester.pumpAndSettle();
    search.unfocus();
    await tester.pumpAndSettle();
    await scrollContent(tester, 300);
    expect(tester.getRect(_header).bottom, moreOrLessEquals(0, epsilon: .5));
    search.requestFocus();
    await tester.pumpAndSettle();
    expect(tester.getRect(_header).top, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resizing merges and splits the rows by the width the header has', (tester) async {
    viewport(tester, 412);
    await tester.pumpWidget(page());
    await scrollContent(tester, 300);
    expect(tester.getRect(_header).bottom, moreOrLessEquals(0, epsilon: .5));
    final position = content(tester);
    final pixels = position.pixels;

    tester.view.physicalSize = const Size(1147, 800);
    await tester.pumpAndSettle();
    final header = tester.getRect(_header);
    expect(header.top, 0);
    expect(tester.getRect(_tabs).center.dy, moreOrLessEquals(header.center.dy, epsilon: .5));
    expect(position.pixels, pixels);

    tester.view.physicalSize = const Size(412, 800);
    await tester.pumpAndSettle();
    expect(tester.getRect(_tabs).top, tester.getRect(_header).bottom);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pull to refresh starts below both rows with the header row shown', (tester) async {
    viewport(tester, 412);
    var refreshed = 0;
    await tester.pumpWidget(
      page(
        onRefresh: () async {
          refreshed++;
          return true;
        },
      ),
    );
    final tabs = tester.getRect(_tabs);
    expect(top(tester, _row(0)), tabs.bottom);
    final gesture = await tester.startGesture(const Offset(200, 300));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
    }
    expect(tester.getRect(_header).top, 0);
    expect(tester.getRect(_tabs), tabs);
    expect(top(tester, _row(0)), greaterThan(tabs.bottom));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(refreshed, 1);
    expect(top(tester, _row(0)), tabs.bottom);
  });
}
