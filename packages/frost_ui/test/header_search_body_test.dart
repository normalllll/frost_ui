import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/overlays/_popover_surface.dart' show frostPopoverContentInset;

import 'page_support.dart';
import 'support.dart';

Finder get _header => find.byType(FrostPageHeader);
Finder _row(int index) => find.text('row $index');

void main() {
  late TextEditingController query;
  late FocusNode focus;
  late FrostPageHeaderSearchController search;
  late List<String> calls;
  setUp(() {
    query = TextEditingController();
    focus = FocusNode(debugLabel: 'search');
    search = FrostPageHeaderSearchController();
    calls = [];
  });
  tearDown(() {
    query.dispose();
    focus.dispose();
    search.dispose();
  });

  void viewport(WidgetTester tester, double width, {double keyboard = 0}) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 800);
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.reset);
  }

  Widget page({bool suggestions = true}) => frostTestApp(
    FrostDefaultTabController(
      length: 2,
      child: pinnedPage(
        header: FrostPageHeader(
          leading: [
            FrostTitleMenu(
              title: 'yande',
              entries: [FrostMenuAction('konachan', onSelected: () {})],
            ),
          ],
          searchController: search,
          middle: FrostSearchInput.suggesting(
            controller: query,
            focusNode: focus,
            placeholder: 'Search',
            onSubmitted: calls.add,
            content: searchContent([
              if (suggestions) ...[
                FrostSearchSection(
                  title: 'Recent',
                  actionLabel: 'Clear',
                  onAction: () => calls.add('clear'),
                  children: [
                    for (final tag in ['catgirl', 'landscape']) FrostSearchSuggestionRow(label: tag, onSelected: () => calls.add(tag)),
                  ],
                ),
                FrostSearchSection(
                  title: 'Tags',
                  children: [for (var i = 0; i < 30; i++) FrostSearchSuggestionRow(label: 'tag $i', onSelected: () => calls.add('tag $i'))],
                ),
              ],
            ]),
          ),
          actions: [FrostToolbarItem.action(icon: testIcons.filter, label: 'Filter', onPressed: () {})],
        ),
        tabs: const FrostTabBar(
          scrollable: true,
          tabs: [
            FrostTab(label: 'New'),
            FrostTab(label: 'Hot'),
          ],
        ),
        slivers: [SliverList.builder(itemCount: 80, itemBuilder: (_, i) => SizedBox(height: 40, child: Text('row $i')))],
      ),
    ),
    platform: TargetPlatform.android,
  );

  ScrollPosition content(WidgetTester tester) => tester
      .stateList<ScrollableState>(find.byType(Scrollable))
      .firstWhere((state) => state.position.axis == Axis.vertical && state.context.findAncestorWidgetOfExactType<FrostPageHeader>() == null)
      .position;

  testWidgets('a narrow header search lists its suggestions over the page body', (tester) async {
    viewport(tester, 412);
    await tester.pumpWidget(page());
    expect(_row(0).hitTestable(), findsOneWidget);
    focus.requestFocus();
    await tester.pumpAndSettle();
    expect(search.expanded, isTrue);

    final header = tester.getRect(_header);
    final title = tester.getRect(find.text('Recent'));
    expect(title.top, greaterThanOrEqualTo(header.bottom));
    // The rows share the header's content column; the list's viewport keeps
    // the page width, so its scrollbar is at the page edge.
    expect(title.left, tester.getRect(find.byType(FrostTextField)).left + FrostGap.hitInset);
    final viewportRect = tester.getRect(find.ancestor(of: find.text('catgirl'), matching: find.byType(Scrollable)).first);
    expect(viewportRect.left, 0);
    expect(viewportRect.right, 412);
    expect(viewportRect.top, header.bottom);
    expect(viewportRect.bottom, 800);

    // The page body and the tab row are hidden underneath.
    expect(_row(0).hitTestable(), findsNothing);
    expect(_row(0), findsOneWidget);
    expect(find.text('New').hitTestable(), findsNothing);
    expect(find.byType(FrostTabBar).hitTestable(), findsNothing);

    // The group action and the rows act as in the anchored panel.
    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(calls, ['clear']);
    expect(focus.hasFocus, isTrue);
    await tester.tap(find.text('landscape'));
    await tester.pumpAndSettle();
    expect(calls, ['clear', 'landscape']);
    // Choosing closes the list; the page comes back under the open search.
    expect(find.text('catgirl'), findsNothing);
    expect(_row(0).hitTestable(), findsOneWidget);
    expect(search.expanded, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the list scrolls inside the body and the keyboard ends it', (tester) async {
    viewport(tester, 412, keyboard: 300);
    await tester.pumpWidget(page());
    focus.requestFocus();
    await tester.pumpAndSettle();
    final list = find.ancestor(of: find.text('catgirl'), matching: find.byType(Scrollable)).first;
    expect(tester.getRect(list).bottom, 500);
    expect(find.text('tag 29').hitTestable(), findsNothing);
    await tester.dragFrom(tester.getCenter(list), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(find.text('tag 29').hitTestable(), findsOneWidget);
    expect(tester.getRect(find.text('tag 29')).bottom, lessThanOrEqualTo(500));
    expect(focus.hasFocus, isTrue);
  });

  testWidgets('collapsing restores the page body at its scroll position', (tester) async {
    viewport(tester, 412);
    await tester.pumpWidget(page());
    final position = content(tester);
    position.jumpTo(600);
    await tester.pumpAndSettle();
    // A row below the header, where nothing covers it.
    final chromeBottom = tester.getRect(find.byType(FrostPageHeader)).bottom;
    final shown = [
      for (var i = 0; i < 80; i++)
        if (_row(i).evaluate().isNotEmpty && tester.getRect(_row(i)).top >= chromeBottom) i,
    ].first;
    final before = tester.getRect(_row(shown + 2));

    focus.requestFocus();
    await tester.pumpAndSettle();
    expect(find.text('catgirl'), findsOneWidget);
    expect(_row(shown + 2).hitTestable(), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(search.expanded, isFalse);
    expect(find.text('catgirl'), findsNothing);
    expect(position.pixels, 600);
    expect(tester.getRect(_row(shown + 2)), before);
    expect(_row(shown + 2).hitTestable(), findsOneWidget);
    expect(find.text('New').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an expanded search without suggestions keeps the page body', (tester) async {
    viewport(tester, 412);
    await tester.pumpWidget(page(suggestions: false));
    focus.requestFocus();
    await tester.pumpAndSettle();
    expect(search.expanded, isTrue);
    expect(_row(0).hitTestable(), findsOneWidget);
    expect(find.text('New').hitTestable(), findsOneWidget);
  });

  testWidgets('wide windows keep the anchored panel over the page', (tester) async {
    viewport(tester, 1147);
    await tester.pumpWidget(page());
    focus.requestFocus();
    await tester.pumpAndSettle();
    expect(find.text('catgirl'), findsOneWidget);
    // A floating panel under the field; the page stays visible around it.
    // The content, inset inside the scroll view that runs to the panel edges.
    final view = tester.getRect(find.ancestor(of: find.text('catgirl'), matching: find.byType(Scrollable)).first);
    final panel = Rect.fromLTRB(view.left + frostPopoverContentInset, view.top, view.right - frostPopoverContentInset, view.bottom);
    final field = tester.getRect(find.byType(FrostTextField));
    expect(panel.left, greaterThanOrEqualTo(field.left - 1));
    expect(panel.right, lessThanOrEqualTo(field.right + 1));
    expect(panel.top, greaterThan(field.bottom));
    expect(find.text('New').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard highlight and Enter reach the group action and rows in the body', (tester) async {
    viewport(tester, 412);
    await tester.pumpWidget(page());
    focus.requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(calls, ['clear']);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(calls, ['clear', 'catgirl']);
  });
}
