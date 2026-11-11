import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/overlays/_popover_surface.dart';

import 'support.dart';
import 'window_caption_test.dart' show FakeWindow;

Widget? _content() => searchContent([
  FrostSearchSection(
    title: 'Recent',
    actionLabel: 'All history',
    onAction: () {},
    children: [for (var i = 0; i < 40; i++) FrostSearchSuggestionRow(label: 'Row $i', onSelected: () {}, onRemove: () {})],
  ),
]);

void _window(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1147, 717);
  addTearDown(tester.view.reset);
}

// The scrollbar's thumb ends at the scroll view's edge (no cross-axis margin).
void _expectEdgeScrollbar(WidgetTester tester) {
  final panel = tester.getRect(find.byType(FrostPopoverSurface));
  final scroll = tester.getRect(find.descendant(of: find.byType(FrostPopoverSurface), matching: find.byType(Scrollable)).first);
  expect(scroll.right, moreOrLessEquals(panel.right, epsilon: 2), reason: 'the scrollbar runs along the panel edge');
  expect(scroll.top, greaterThanOrEqualTo(panel.top + frostPopoverContentInset - .5), reason: 'inside the panel corners');
  expect(scroll.bottom, lessThanOrEqualTo(panel.bottom - frostPopoverContentInset + .5));
  final row = tester.getRect(find.byType(FrostListRow).first);
  expect(row.left, moreOrLessEquals(panel.left + frostPopoverContentInset, epsilon: .5));
  expect(row.right, moreOrLessEquals(panel.right - frostPopoverContentInset, epsilon: .5), reason: 'content keeps its inset, clear of the scrollbar');
  expect(tester.getRect(find.text('All history')).right, lessThanOrEqualTo(panel.right - frostPopoverContentInset + .5));
  final remove = find.descendant(of: find.byType(FrostListRow).first, matching: find.byType(FrostButton)).first;
  expect(tester.getRect(remove).right, lessThanOrEqualTo(panel.right - frostPopoverContentInset + .5));
}

void main() {
  testWidgets('a caption search dropdown that scrolls keeps its scrollbar at the panel edge and its content inset', (tester) async {
    _window(tester);
    final controller = TextEditingController(), focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      frostTestApp(
        FrostWindowCaptionScope(
          window: FakeWindow(),
          child: FrostShell(
            destinations: const [FrostNavDestination(icon: FrostIconData.glyph(Icons.home), label: 'Home')],
            selectedIndex: 0,
            atDestinationRoot: true,
            onDestinationSelected: (_) {},
            canGoBack: false,
            onBack: () {},
            showsMobileNavigation: true,
            brand: const FrostShellBrand(expanded: Text('Application')),
            titleBarSearch: FrostCaptionSearch(controller: controller, focusNode: focus, placeholder: 'Search', onSubmitted: (_) {}, content: _content()),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pumpAndSettle();
    _expectEdgeScrollbar(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a suggesting search input dropdown keeps its scrollbar at the panel edge and its content inset', (tester) async {
    _window(tester);
    final controller = TextEditingController(), focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      frostTestApp(
        Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 520,
            child: FrostSearchInput.suggesting(controller: controller, focusNode: focus, placeholder: 'Search', onSubmitted: (_) {}, content: _content()),
          ),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pumpAndSettle();
    _expectEdgeScrollbar(tester);
    expect(tester.takeException(), isNull);
  });
}
