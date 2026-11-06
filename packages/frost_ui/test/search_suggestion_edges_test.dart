import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/overlays/_popover_surface.dart';

import 'page_support.dart';
import 'support.dart';

Widget _groups({int each = 1}) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  mainAxisSize: MainAxisSize.min,
  children: [
    FrostSearchSection(
      title: 'Recent',
      actionLabel: 'Clear',
      onAction: () {},
      children: [for (var i = 0; i < each; i++) FrostSearchSuggestionRow(label: 'cat $i', onSelected: () {}, onRemove: () {})],
    ),
    FrostSearchSection(
      title: 'Common',
      actionLabel: 'All',
      onAction: () {},
      children: [for (var i = 0; i < each; i++) FrostSearchSuggestionRow(label: 'sky $i', value: '940k', onSelected: () {})],
    ),
  ],
);

// The remove button's glyph, which is what lines up with the text edge.
Rect _removeGlyph(WidgetTester tester) => tester.getRect(find.descendant(of: find.byType(FrostListRow).first, matching: find.byType(FrostIcon)).first);

// The remove button's whole target, which stays inside its list row.
Rect _removeTarget(WidgetTester tester) => tester.getRect(
  find
      .ancestor(
        of: find.descendant(of: find.byType(FrostListRow).first, matching: find.byType(FrostIcon)).first,
        matching: find.byType(FrostButton),
      )
      .first,
);

void main() {
  late TextEditingController controller;
  late FocusNode focus;
  setUp(() {
    controller = TextEditingController();
    focus = FocusNode();
  });
  tearDown(() {
    controller.dispose();
    focus.dispose();
  });

  void viewport(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
  }

  testWidgets('dropdown values and remove buttons end on the group actions\' edge', (tester) async {
    viewport(tester, const Size(1147, 717));
    await tester.pumpWidget(
      frostTestApp(
        Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 520,
            child: FrostSearchInput.suggesting(controller: controller, focusNode: focus, placeholder: 'Search', onSubmitted: (_) {}, content: _groups()),
          ),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pumpAndSettle();
    final edge = tester.getRect(find.byType(FrostPopoverSurface)).right - frostPopoverContentInset;
    expect(tester.getRect(find.text('Clear')).right, edge);
    expect(tester.getRect(find.text('940k')).right, edge);
    // Its whole target ends on the edge; bleeding it out of the list would
    // leave part of it untappable outside the list viewport.
    expect(_removeTarget(tester).right, edge);
    expect(_removeGlyph(tester).center.dx, _removeTarget(tester).center.dx);
    // Titles and row text still start on the opposite content edge.
    final start = tester.getRect(find.byType(FrostPopoverSurface)).left + frostPopoverContentInset;
    expect(tester.getRect(find.text('Recent')).left, start);
    expect(tester.getRect(find.text('cat 0')).left, start);
    expect(tester.takeException(), isNull);
  });

  testWidgets('page suggestions end values and remove targets on the content edge', (tester) async {
    viewport(tester, const Size(412, 800));
    await tester.pumpWidget(
      frostTestApp(
        FrostSearchInput.suggesting(
          controller: controller,
          focusNode: focus,
          placeholder: 'Search',
          onSubmitted: (_) {},
          content: _groups(),
          placement: FrostSuggestionPlacement.inline,
        ),
        platform: TargetPlatform.android,
      ),
    );
    focus.requestFocus();
    await tester.pumpAndSettle();
    final edge = tester.getRect(find.text('Clear')).right;
    expect(edge, 412 - tester.getRect(find.text('Recent')).left, reason: 'the content edge mirrors the start edge');
    expect(tester.getRect(find.text('940k')).right, edge);
    // Its whole target ends on the edge; bleeding it out of the list would
    // leave part of it untappable outside the list viewport.
    expect(_removeTarget(tester).right, edge);
    expect(_removeGlyph(tester).center.dx, _removeTarget(tester).center.dx);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inline suggestions inside a pinned page share the page edges with the field', (tester) async {
    viewport(tester, const Size(412, 915));
    await tester.pumpWidget(
      frostTestApp(
        pinnedPage(
          header: const FrostPageHeader(title: FrostText('Search')),
          slivers: [
            SliverFillRemaining(
              child: FrostSearchInput.suggesting(
                controller: controller,
                focusNode: focus,
                placeholder: 'Search',
                onSubmitted: (_) {},
                content: _groups(),
                placement: FrostSuggestionPlacement.inline,
              ),
            ),
          ],
        ),
        platform: TargetPlatform.android,
      ),
    );
    focus.requestFocus();
    await tester.pumpAndSettle();
    final start = tester.getRect(find.byType(FrostTextField)).left;
    final end = 412 - start;
    // One column: the page's own, not a second one inside it.
    expect(tester.getRect(find.text('Recent')).left, start);
    expect(tester.getRect(find.text('cat 0')).left, start);
    expect(tester.getRect(find.text('Clear')).right, end);
    expect(tester.getRect(find.text('940k')).right, end);
    expect(_removeTarget(tester).right, end);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a list that selects still reserves its check column on every row', (tester) async {
    viewport(tester, const Size(400, 400));
    await tester.pumpWidget(
      frostTestApp(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            height: 200,
            child: FrostList<String>(
              items: const ['one', 'two'],
              selected: 'one',
              onSelected: (_) {},
              itemBuilder: (context, item, _) => FrostListRow(title: item, value: 'v'),
            ),
          ),
        ),
      ),
    );
    final values = find.text('v');
    final selected = tester.getRect(values.first), other = tester.getRect(values.last);
    expect(other.right, selected.right, reason: 'unselected rows keep the same check column');
    expect(selected.right, lessThan(300));
    expect(tester.takeException(), isNull);
  });
}
