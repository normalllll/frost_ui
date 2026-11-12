import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_button_control.dart';
import 'package:frost_ui/src/controls/_calendar.dart' show FrostCalendar;

import 'page_support.dart';
import 'support.dart';

final _first = DateTime(2026, 11, 1), _last = DateTime(2026, 11, 20);

void _viewport(WidgetTester tester, double width) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 800);
  addTearDown(tester.view.reset);
}

FrostToolbarItem _date(DateTime? value, List<DateTime?> changes, {bool clearable = false, FrostToolbarPriority priority = FrostToolbarPriority.normal}) =>
    FrostToolbarItem.date(
      value: value,
      onChanged: changes.add,
      label: 'Date',
      placeholder: 'Latest',
      firstDate: _first,
      lastDate: _last,
      clearable: clearable,
      showsYear: true,
      priority: priority,
    );

Widget _page({required FrostToolbarItem date, List<FrostToolbarItem> more = const [], bool tabs = false}) => frostTestApp(
  FrostDefaultTabController(
    length: 3,
    child: pinnedPage(
      header: FrostPageHeader(
        leading: [FrostTitleMenu(title: 'Ranking · Daily', entries: const [])],
        actions: [date, ...more],
      ),
      tabs: tabs
          ? const FrostTabBar(
              scrollable: true,
              tabs: [
                FrostTab(label: 'Illustrations'),
                FrostTab(label: 'Manga'),
                FrostTab(label: 'Novels'),
              ],
            )
          : null,
      slivers: [SliverList.builder(itemCount: 80, itemBuilder: (_, i) => SizedBox(height: 40, child: Text('row $i')))],
    ),
  ),
);

void main() {
  testWidgets('a date choice in a header row is one control row tall and shows the placeholder or the date', (tester) async {
    _viewport(tester, 1147);
    await tester.pumpWidget(_page(date: _date(null, [])));
    await tester.pumpAndSettle();
    expect(find.text('Latest').hitTestable(), findsOneWidget);
    expect(tester.getSize(find.byType(FrostPageHeader)).height, FrostPageHeader.horizontalHeight);
    final row = tester.getSize(find.ancestor(of: find.text('Ranking · Daily').hitTestable(), matching: find.byType(FrostButtonControl)).first).height;
    expect(tester.getSize(find.ancestor(of: find.text('Latest').hitTestable(), matching: find.byType(FrostButtonControl)).first).height, row);

    await tester.pumpWidget(_page(date: _date(DateTime(2026, 11, 5), [])));
    await tester.pumpAndSettle();
    expect(find.text('Latest'), findsNothing);
    expect(find.textContaining('2026').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the date choice keeps its label for screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    _viewport(tester, 1147);
    await tester.pumpWidget(_page(date: _date(null, [])));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Date, Latest'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('the date choice opens the calendar within its bounds', (tester) async {
    _viewport(tester, 1147);
    final changes = <DateTime?>[];
    await tester.pumpWidget(_page(date: _date(DateTime(2026, 11, 5), changes)));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('2026').hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(FrostCalendar), findsOneWidget);
    // After the last date nothing can be chosen.
    await tester.tap(find.descendant(of: find.byType(FrostCalendar), matching: find.text('25')));
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
    await tester.tap(find.descendant(of: find.byType(FrostCalendar), matching: find.text('12')));
    await tester.pumpAndSettle();
    expect(changes, [DateTime(2026, 11, 12)]);
    expect(find.byType(FrostCalendar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a clearable date choice offers Clear while a date is chosen', (tester) async {
    _viewport(tester, 1147);
    final changes = <DateTime?>[];
    await tester.pumpWidget(_page(date: _date(DateTime(2026, 11, 5), changes, clearable: true)));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('2026').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('L.clear'));
    await tester.pumpAndSettle();
    expect(changes, [null]);
    expect(find.byType(FrostCalendar), findsNothing);

    await tester.pumpWidget(_page(date: _date(null, changes, clearable: true)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Latest').hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(FrostCalendar), findsOneWidget);
    expect(find.text('L.clear'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('above section tabs the date choice slides away with the header row and returns with it', (tester) async {
    _viewport(tester, 412);
    // High priority keeps it in the row while the title menu truncates.
    await tester.pumpWidget(_page(date: _date(null, [], priority: FrostToolbarPriority.high), tabs: true));
    await tester.pumpAndSettle();
    final resting = tester.getRect(find.text('Latest').hitTestable());
    final tabs = tester.getRect(find.byType(FrostTabBar));
    expect(resting.bottom, lessThanOrEqualTo(tabs.top));
    await tester.dragFrom(const Offset(200, 600), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('Latest').hitTestable(), findsNothing);
    await tester.dragFrom(const Offset(200, 600), const Offset(0, 40));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Latest').hitTestable()).top, moreOrLessEquals(resting.top, epsilon: .5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('without room the date choice goes into the overflow menu and opens the calendar from there', (tester) async {
    _viewport(tester, 320);
    final changes = <DateTime?>[];
    await tester.pumpWidget(
      _page(
        date: _date(null, changes, priority: FrostToolbarPriority.low),
        more: [
          for (final label in ['Filter', 'Share', 'Sync'])
            FrostToolbarItem.action(icon: testIcons.add, label: label, onPressed: () {}, priority: FrostToolbarPriority.high),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Latest').hitTestable(), findsNothing);
    await tester.tap(findFrostTooltip('L.more').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Date · Latest'));
    await tester.pumpAndSettle();
    expect(find.byType(FrostCalendar), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(FrostCalendar), matching: find.text('12')));
    await tester.pumpAndSettle();
    expect(changes, [DateTime(2026, 11, 12)]);
    expect(find.byType(FrostCalendar), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
