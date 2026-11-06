import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/desktop.dart';
import 'package:frost_ui/frost_ui.dart';

import 'shell_placement_layers_test.dart' show presentation, destinations, viewport;
import 'support.dart';

void main() {
  testWidgets('search suggestion group headings repeat the panel top inset', (tester) async {
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      frostTestApp(
        Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 400,
            child: FrostSearchInput.suggesting(
              controller: controller,
              focusNode: focus,
              placeholder: 'Search',
              onSubmitted: (_) {},
              content: searchContent([
                FrostSearchSection(
                  title: 'History',
                  children: [FrostSearchSuggestionRow(label: 'Flutter desktop', onSelected: () {})],
                ),
                FrostSearchSection(
                  title: 'Trending',
                  children: [FrostSearchSuggestionRow(label: 'Flutter video', onSelected: () {})],
                ),
              ]),
            ),
          ),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pumpAndSettle();
    final panel = find.byWidgetPredicate((widget) => widget is FrostSurface && widget.role == FrostSurfaceRole.overlay);
    final history = tester.getRect(find.text('History'));
    final trending = tester.getRect(find.text('Trending'));
    final previousRow = tester.getRect(find.ancestor(of: find.text('Flutter desktop'), matching: find.byType(FrostListRow)));
    expect(trending.top - previousRow.bottom, history.top - tester.getRect(panel).top);
    expect(history.top - tester.getRect(panel).top, 16);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('touch sidebar tab count uses neutral ink independently of unread badges', (tester) async {
    viewport(tester, const Size(1366, 1024));
    final tabs = FrostTabsController<String>(initial: 'A')..open('B', activate: false);
    addTearDown(tabs.dispose);
    await tester.pumpWidget(
      frostTestApp(
        FrostShell(
          destinations: destinations,
          selectedIndex: 0,
          atDestinationRoot: true,
          canGoBack: false,
          onBack: () {},
          onDestinationSelected: (_) {},
          showsMobileNavigation: true,
          tabs: presentation(tabs),
          child: const FrostShellDestination(child: SizedBox.expand()),
        ),
        platform: TargetPlatform.android,
      ),
    );
    await tester.pumpAndSettle();
    final overview = find.byKey(const ValueKey('frost-shell-tabs-overview'));
    final badge = find.descendant(of: overview, matching: find.byType(FrostCountBadge));
    expect(tester.widget<FrostCountBadge>(badge).tone, FrostCountBadgeTone.neutral);
    expect(tester.widget<FrostCountBadge>(badge).count, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
