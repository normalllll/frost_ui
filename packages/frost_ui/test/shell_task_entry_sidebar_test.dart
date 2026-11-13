import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/desktop.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/navigation/window_caption.dart' show FrostCaptionButtons;
import 'package:material_ui/material_ui.dart';

import 'support.dart';
import 'window_caption_test.dart' show FakeWindow;

final destinations = [FrostNavDestination(icon: testIcons.image, label: 'Home'), FrostNavDestination(icon: testIcons.search, label: 'Library')];
final secondaryDestinations = [FrostNavDestination(icon: testIcons.more, label: 'Settings'), FrostNavDestination(icon: testIcons.collapse, label: 'About')];

FrostShellTaskEntry downloads({bool visible = true, VoidCallback? onPressed, Widget Function(BuildContext, FrostShellTaskEntryPlacement)? builder}) =>
    FrostShellTaskEntry(
      visible: visible,
      builder:
          builder ??
          (context, placement) => FrostShellTaskButton(icon: testIcons.image, label: 'Downloads', badge: 3, progress: .4, onPressed: onPressed ?? () {}),
    );

Widget shell({
  FrostShellTaskEntry? taskEntry,
  bool expanded = false,
  FrostSidebarAlignment alignment = FrostSidebarAlignment.automatic,
  FrostShellTabs<Object>? tabs,
}) => FrostShell(
  destinations: destinations,
  secondary: FrostShellSecondary(destinations: secondaryDestinations, onSelected: (_) {}),
  selectedIndex: 0,
  atDestinationRoot: true,
  onDestinationSelected: (_) {},
  canGoBack: false,
  onBack: () {},
  showsMobileNavigation: true,
  initiallyExpanded: expanded,
  sidebarAlignment: alignment,
  tabs: tabs,
  taskEntry: taskEntry,
  child: const FrostShellDestination(child: SizedBox.expand()),
);

void viewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Finder item(String label) => find.byWidgetPredicate((w) => w is FrostNavItem && w.label == label);
Finder get entry => item('Downloads');
Finder iconOf(Finder item) => find.descendant(of: item, matching: find.byType(FrostIcon)).first;

List<Rect> destinationRects(WidgetTester tester) => [for (final destination in destinations) tester.getRect(item(destination.label))];

void main() {
  for (final expanded in [false, true]) {
    testWidgets('sidebar entry sits below the destinations and secondary group (expanded: $expanded)', (tester) async {
      viewport(tester, const Size(1366, 900));
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        frostTestApp(
          shell(
            taskEntry: downloads(onPressed: () => taps++),
            expanded: expanded,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(entry, findsOneWidget);
      final rect = tester.getRect(entry);
      final lastAbove = expanded ? tester.getRect(item('About')) : tester.getRect(item('L.more'));
      expect(rect.top, greaterThanOrEqualTo(lastAbove.bottom));
      expect(rect.bottom, lessThanOrEqualTo(900));
      expect(tester.widget<FrostNavItem>(entry).selected, isFalse);
      if (expanded) {
        expect(find.text('Downloads'), findsOneWidget);
        expect(tester.getTopLeft(find.text('Downloads')).dx, tester.getTopLeft(find.text('Home')).dx);
      } else {
        expect(tester.getCenter(iconOf(entry)).dx, tester.getCenter(iconOf(item('Home'))).dx);
      }
      expect(find.semantics.byLabel(RegExp('^Downloads')), findsOne);
      await tester.tap(entry);
      expect(taps, 1);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  testWidgets('a top-aligned sidebar keeps its destinations with no, hidden or shown entry', (tester) async {
    viewport(tester, const Size(1366, 900));
    await tester.pumpWidget(frostTestApp(shell()));
    await tester.pumpAndSettle();
    final without = destinationRects(tester);
    await tester.pumpWidget(frostTestApp(shell(taskEntry: downloads(visible: false))));
    await tester.pumpAndSettle();
    expect(entry, findsNothing);
    expect(destinationRects(tester), without);
    await tester.pumpWidget(frostTestApp(shell(taskEntry: downloads())));
    await tester.pumpAndSettle();
    expect(entry, findsOneWidget);
    expect(destinationRects(tester), without);
  });

  testWidgets('a bottom-aligned sidebar keeps the entry room while it is hidden', (tester) async {
    viewport(tester, const Size(1366, 1024));
    final semantics = tester.ensureSemantics();
    Widget app(FrostShellTaskEntry? taskEntry) => frostTestApp(shell(taskEntry: taskEntry, alignment: FrostSidebarAlignment.bottom));
    await tester.pumpWidget(app(downloads()));
    await tester.pumpAndSettle();
    final shown = destinationRects(tester);
    expect(tester.getTopLeft(entry).dy, greaterThan(shown.last.bottom));
    await tester.pumpWidget(app(downloads(visible: false)));
    await tester.pumpAndSettle();
    expect(destinationRects(tester), shown);
    expect(find.semantics.byLabel(RegExp('^Downloads')), findsNothing);
    await tester.tap(entry, warnIfMissed: false);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(app(null));
    await tester.pumpAndSettle();
    expect(destinationRects(tester).last.bottom, greaterThan(shown.last.bottom), reason: 'no entry reserves nothing');
    semantics.dispose();
  });

  testWidgets('touch sidebar shows the entry above the tabs overview without overlap', (tester) async {
    viewport(tester, const Size(1366, 1024));
    final controller = FrostTabsController<String>(initial: 'Home')..open('Video');
    addTearDown(controller.dispose);
    final tabs = FrostShellTabs<String>(
      controller: controller,
      label: (_, tab) => FrostTabLabel(title: tab),
      countLabel: (count) => '$count tabs',
      sidebarLabel: (count) => 'Tabs $count',
      closeTooltip: 'Close tab',
      newTabTooltip: 'New tab',
      onNewTab: () {},
    );
    await tester.pumpWidget(
      frostTestApp(
        shell(taskEntry: downloads(), tabs: tabs),
        platform: TargetPlatform.android,
      ),
    );
    await tester.pumpAndSettle();
    final overview = tester.getRect(find.byKey(const ValueKey('frost-shell-tabs-overview')));
    final rect = tester.getRect(entry);
    expect(rect.overlaps(overview), isFalse);
    expect(rect.bottom, lessThanOrEqualTo(overview.top));
    expect(overview.bottom, lessThanOrEqualTo(1024));
    expect(rect.top, greaterThanOrEqualTo(tester.getRect(item('L.more')).bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a popover anchored on the entry opens clear of the title bar', (tester) async {
    viewport(tester, const Size(1147, 717));
    await tester.pumpWidget(
      frostTestApp(
        FrostWindowCaptionScope(
          window: FakeWindow(),
          child: shell(
            taskEntry: downloads(
              builder: (context, placement) => FrostPopover(
                title: 'Downloads',
                builder: (context, focusNode, toggle) => Focus(
                  focusNode: focusNode,
                  child: FrostShellTaskButton(icon: testIcons.image, label: 'Downloads', onPressed: toggle),
                ),
                contentBuilder: (context, close) => const SizedBox(height: 240, child: Text('Download panel')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.text('Download panel'), findsOneWidget);
    final panel = tester.getRect(find.ancestor(of: find.text('Download panel'), matching: find.byType(FrostSurface)).first);
    final caption = tester.getRect(find.byType(FrostCaptionButtons));
    expect(panel.top, greaterThanOrEqualTo(caption.bottom));
    expect(panel.bottom, lessThanOrEqualTo(717));
    expect(tester.takeException(), isNull);
  });

  for (final alignment in [FrostSidebarAlignment.top, FrostSidebarAlignment.bottom]) {
    testWidgets('toggling the entry keeps the tabs overview and the entry mounted ($alignment)', (tester) async {
      viewport(tester, const Size(1366, 1024));
      final controller = FrostTabsController<String>(initial: 'Home')..open('Video');
      addTearDown(controller.dispose);
      final tabs = FrostShellTabs<String>(
        controller: controller,
        label: (_, tab) => FrostTabLabel(title: tab),
        countLabel: (count) => '$count tabs',
        closeTooltip: 'Close tab',
        newTabTooltip: 'New tab',
        onNewTab: () {},
      );
      Widget app(FrostShellTaskEntry? taskEntry) => frostTestApp(
        shell(taskEntry: taskEntry, tabs: tabs, alignment: alignment),
        platform: TargetPlatform.android,
      );
      State overviewState() =>
          tester.state(find.descendant(of: find.byKey(const ValueKey('frost-shell-tabs-overview')), matching: find.byType(FrostClickSurface)));
      State entryState() => tester.state(
        find.descendant(
          of: find.byWidgetPredicate((w) => w is FrostNavItem && w.label == 'Downloads', skipOffstage: false),
          matching: find.byType(FrostClickSurface, skipOffstage: false),
          skipOffstage: false,
        ),
      );
      await tester.pumpWidget(app(null));
      await tester.pumpAndSettle();
      final overview = overviewState();
      await tester.pumpWidget(app(downloads()));
      await tester.pumpAndSettle();
      expect(overviewState(), same(overview));
      final shown = entryState();
      await tester.pumpWidget(app(downloads(visible: false)));
      await tester.pumpAndSettle();
      expect(overviewState(), same(overview));
      expect(entryState(), same(shown), reason: 'a hidden entry keeps its State');
      await tester.pumpWidget(app(downloads()));
      await tester.pumpAndSettle();
      expect(entryState(), same(shown));
      await tester.pumpWidget(app(null));
      await tester.pumpAndSettle();
      expect(overviewState(), same(overview));
      expect(tester.takeException(), isNull);
    });
  }
}
