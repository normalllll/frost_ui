import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:go_router/go_router.dart';

import 'support.dart';

final destinations = [
  FrostNavDestination(icon: testIcons.image, label: 'Home'),
  FrostNavDestination(icon: testIcons.search, label: 'Library'),
  FrostNavDestination(icon: testIcons.more, label: 'Account'),
];

const topInset = 47.0;
const bottomInset = 34.0;
const phoneSize = Size(390, 844);
const panelTitle = 'Transfers';

final navigatorKey = GlobalKey<NavigatorState>();

final panel = FrostShellTaskPanel(
  title: panelTitle,
  builder: (context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const FrostText('Two downloads running'),
      const FrostText('cover.png'),
      const FrostText('chapter-12.zip'),
      FrostButton(
        label: 'Details',
        onPressed: () => showFrostDialog<void>(context: context, builder: (_) => const FrostText('Dialog body')),
      ),
    ],
  ),
);

/// A destination page with a real page header, so the band is checked
/// against the header's rendered hit area.
const headerPage = Column(
  children: [
    FrostPageHeader(title: FrostText('Library')),
    Expanded(child: SizedBox.expand()),
  ],
);

FrostShellTaskEntry entry({
  VoidCallback? onPressed,
  FrostShellTaskPanel? taskPanel,
  ValueChanged<FrostFloatingEntryPosition>? onMoved,
  bool visible = true,
  bool withPanel = true,
}) => FrostShellTaskEntry(
  visible: visible,
  onFloatingPositionChanged: onMoved,
  panel: withPanel ? taskPanel ?? panel : null,
  builder: (context, placement) => FrostShellTaskButton(icon: testIcons.image, label: 'Downloads', badge: 2, progress: .5, onPressed: onPressed),
);

Widget shell({
  VoidCallback? onPressed,
  FrostShellTaskPanel? taskPanel,
  ValueChanged<FrostFloatingEntryPosition>? onMoved,
  bool visible = true,
  bool withPanel = true,
  Widget? child,
}) => FrostShell(
  destinations: destinations,
  selectedIndex: 0,
  atDestinationRoot: true,
  onDestinationSelected: (_) {},
  canGoBack: false,
  onBack: () {},
  showsMobileNavigation: true,
  taskEntry: entry(onPressed: onPressed, onMoved: onMoved, visible: visible, withPanel: withPanel, taskPanel: taskPanel),
  child:
      child ??
      Navigator(
        key: navigatorKey,
        onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const FrostShellDestination(child: headerPage)),
      ),
);

void phone(WidgetTester tester, [Size size = phoneSize]) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: topInset, bottom: bottomInset);
  addTearDown(tester.view.reset);
}

Finder get button => find.byType(FrostShellTaskButton);
Finder get dimmed => find.descendant(of: button, matching: find.byWidgetPredicate((w) => w is Opacity && w.opacity < 1));
Finder get bar => find.byWidgetPredicate((w) => w is FrostSurface && w.role == FrostSurfaceRole.chrome);
Finder get header => find.byType(FrostPageHeader);
Finder get titleBar => find.byKey(const ValueKey('frost-shell-task-panel-title'));
Finder get panelSurface => find.ancestor(of: titleBar, matching: find.byWidgetPredicate((w) => w is FrostSurface && w.role == FrostSurfaceRole.overlay)).first;
Finder get panelScope => find.ancestor(of: titleBar, matching: find.byType(FocusScope)).first;
Finder get sidebarEntry => find.byWidgetPredicate((w) => w is FrostNavItem && w.label == 'Downloads');

/// The shell layer's own fade, which hides the entry and the panel together.
double layerOpacity(WidgetTester tester) => tester.widget<AnimatedOpacity>(find.ancestor(of: titleBar, matching: find.byType(AnimatedOpacity)).first).opacity;

bool focusWithin(Finder finder) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return false;
  final target = finder.evaluate().single;
  if (focused == target) return true;
  var found = false;
  focused.visitAncestorElements((element) {
    found = element == target;
    return !found;
  });
  return found;
}

/// The panel lies inside the window and the safe area, below the rendered page
/// header and above the bottom bar.
void expectInBand(WidgetTester tester, Rect rect, [Size view = phoneSize]) {
  final headerRect = tester.getRect(header);
  final barRect = tester.getRect(bar);
  expect(rect.left, greaterThanOrEqualTo(0));
  expect(rect.right, lessThanOrEqualTo(view.width));
  expect(rect.top, greaterThanOrEqualTo(topInset));
  expect(rect.top, greaterThanOrEqualTo(headerRect.bottom), reason: 'clear of the header hit area');
  expect(rect.bottom, lessThanOrEqualTo(barRect.top), reason: 'clear of the bottom bar');
}

Future<void> openPanel(WidgetTester tester) async {
  await tester.tap(button);
  await tester.pumpAndSettle();
  expect(titleBar, findsOneWidget);
}

Future<void> pumpPhone(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(frostTestApp(widget, platform: TargetPlatform.android));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the entry opens its panel beside itself, inside the band, with focus inside', (tester) async {
    phone(tester);
    await pumpPhone(tester, shell());
    final entryRect = tester.getRect(button);
    expect(dimmed, findsNothing, reason: 'a panel makes the entry enabled');
    await openPanel(tester);
    final rect = tester.getRect(panelSurface);
    expectInBand(tester, rect);
    expect(rect.width, lessThan(390 - 2 * 16), reason: 'it does not span the window');
    // It opens at the entry's corner: the default entry rests at the bottom end.
    expect(rect.right, moreOrLessEquals(entryRect.right, epsilon: 1));
    expect(rect.bottom, moreOrLessEquals(entryRect.bottom, epsilon: 1));
    expect(find.text(panelTitle), findsOneWidget);
    expect(find.text('cover.png'), findsOneWidget);
    expect(focusWithin(panelScope), isTrue);
    // The panel stands in for the entry.
    expect(tester.widget<Opacity>(find.ancestor(of: button, matching: find.byType(Opacity)).first).opacity, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the title bar drags the panel, which stays clear of the bar and the header', (tester) async {
    phone(tester);
    final moved = <FrostFloatingEntryPosition>[];
    await pumpPhone(tester, shell(onMoved: moved.add));
    await openPanel(tester);
    final before = tester.getRect(panelSurface);
    await tester.drag(titleBar, const Offset(-10, -150));
    await tester.pumpAndSettle();
    final after = tester.getRect(panelSurface);
    expect(after.top, moreOrLessEquals(before.top - 150, epsilon: 1), reason: 'it follows the pointer');
    expect(after.left, moreOrLessEquals(before.left - 10, epsilon: 1));
    // Far past the top and the start edge, it stops inside the band.
    await tester.drag(titleBar, const Offset(-500, -900));
    await tester.pumpAndSettle();
    final top = tester.getRect(panelSurface);
    expectInBand(tester, top);
    expect(top.left, 16);
    // Far past the bottom, it stops above the bar.
    await tester.drag(titleBar, const Offset(0, 2000));
    await tester.pumpAndSettle();
    final bottom = tester.getRect(panelSurface);
    expectInBand(tester, bottom);
    expect(bottom.bottom, tester.getRect(bar).top - 16);
    expect(moved, isEmpty, reason: 'the entry moves only when the panel closes');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a press outside closes a moved panel; the entry rests by it and has focus', (tester) async {
    phone(tester);
    final moved = <FrostFloatingEntryPosition>[];
    await pumpPhone(tester, shell(onMoved: moved.add));
    await openPanel(tester);
    await tester.drag(titleBar, const Offset(-500, -900));
    await tester.pumpAndSettle();
    final panelRect = tester.getRect(panelSurface);
    await tester.tapAt(const Offset(380, 500));
    await tester.pumpAndSettle();
    expect(titleBar, findsNothing);
    expect(moved, hasLength(1));
    expect(moved.single.edge, FrostFloatingEntryEdge.start, reason: 'the panel ended nearer the start edge');
    final entryRect = tester.getRect(button);
    expect(entryRect.left, 16);
    expect(entryRect.top, moreOrLessEquals(panelRect.top, epsilon: 1), reason: 'at the corner the panel grows from');
    expect(focusWithin(button), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening and closing without a drag keeps the entry exactly where it was', (tester) async {
    phone(tester);
    final moved = <FrostFloatingEntryPosition>[];
    await pumpPhone(tester, shell(onMoved: moved.add));
    final start = tester.getRect(button);
    for (var i = 0; i < 3; i++) {
      await openPanel(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(tester.getRect(button), start);
    }
    expect(moved, isEmpty, reason: 'nothing to save');
  });

  testWidgets('after a drag, opening and closing again at the new place is stable', (tester) async {
    phone(tester);
    final moved = <FrostFloatingEntryPosition>[];
    await pumpPhone(tester, shell(onMoved: moved.add));
    for (final drag in [const Offset(-200, -250), const Offset(-150, 80), const Offset(0, -500)]) {
      await openPanel(tester);
      await tester.drag(titleBar, drag);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      final count = moved.length;
      final rest = tester.getRect(button);
      for (var i = 0; i < 2; i++) {
        await openPanel(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(tester.getRect(button), rest);
      }
      expect(moved, hasLength(count));
    }
    expect(moved, hasLength(3));
  });

  testWidgets('Escape and the close button close the panel and return focus to the entry', (tester) async {
    phone(tester);
    await pumpPhone(tester, shell());
    await openPanel(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(titleBar, findsNothing);
    expect(focusWithin(button), isTrue);
    await openPanel(tester);
    await tester.tap(find.descendant(of: titleBar, matching: find.byType(FrostButton)));
    await tester.pumpAndSettle();
    expect(titleBar, findsNothing);
    expect(focusWithin(button), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Back closes the panel over a pushed full-screen route and leaves the route', (tester) async {
    phone(tester);
    await pumpPhone(tester, shell());
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const ColoredBox(key: ValueKey('viewer'), color: Colors.black, child: SizedBox.expand()),
      ),
    );
    await tester.pumpAndSettle();
    expect(bar, findsNothing);
    expect(button.hitTestable(), findsOneWidget, reason: 'the entry stays above a pushed route');
    await openPanel(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(titleBar, findsNothing);
    expect(find.byKey(const ValueKey('viewer')), findsOneWidget, reason: 'Back closed only the panel');
    expect(focusWithin(button), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Back on a root page closes the panel only', (tester) async {
    phone(tester);
    await pumpPhone(tester, shell());
    await openPanel(tester);
    expect(await tester.binding.handlePopRoute(), isTrue, reason: 'the panel takes Back');
    await tester.pumpAndSettle();
    expect(titleBar, findsNothing);
    expect(button, findsOneWidget);
    expect(await tester.binding.handlePopRoute(), isFalse, reason: 'closed, it gives Back up again');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Back through a nested Navigator reaches neither its pop handler nor the page PopScope', (tester) async {
    phone(tester);
    final nested = GlobalKey<NavigatorState>();
    var handled = 0, invoked = 0;
    await pumpPhone(
      tester,
      shell(
        child: NavigatorPopHandler<Object?>(
          onPopWithResult: (_) {
            handled++;
            nested.currentState!.maybePop();
          },
          child: Navigator(
            key: nested,
            onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const FrostShellDestination(child: headerPage)),
          ),
        ),
      ),
    );
    nested.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => PopScope<Object?>(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) => invoked++,
          child: const ColoredBox(key: ValueKey('viewer'), color: Colors.black, child: SizedBox.expand()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await openPanel(tester);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(titleBar, findsNothing);
    expect(find.byKey(const ValueKey('viewer')), findsOneWidget);
    expect(handled, 0, reason: 'the pop handler never heard of the Back that closed the panel');
    expect(invoked, 0, reason: 'nor did the page PopScope');
    // Closed, the panel lets Back through to the page again.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(handled, 1);
    expect(invoked, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('under a go_router ShellRoute, Back over a pushed page closes only the panel', (tester) async {
    phone(tester);
    var invoked = 0;
    final router = GoRouter(
      routes: [
        ShellRoute(
          builder: (context, state, child) => shell(child: child),
          routes: [
            GoRoute(path: '/', builder: (context, state) => const FrostShellDestination(child: headerPage)),
            GoRoute(
              path: '/viewer',
              builder: (context, state) => PopScope<Object?>(
                canPop: false,
                onPopInvokedWithResult: (didPop, _) => invoked++,
                child: const ColoredBox(key: ValueKey('viewer'), color: Colors.black, child: SizedBox.expand()),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    final config = testConfig;
    await tester.pumpWidget(
      FrostScope(
        config: config,
        child: MaterialApp.router(
          theme: FrostTheme.build(config: config, brightness: Brightness.light, platform: TargetPlatform.android, locale: const Locale('en')),
          builder: (context, child) => FrostToastHost(child: child!),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    router.push('/viewer');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('viewer')), findsOneWidget);
    await openPanel(tester);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(titleBar, findsNothing);
    expect(find.byKey(const ValueKey('viewer')), findsOneWidget, reason: 'the pushed page stays');
    expect(invoked, 0, reason: 'the page PopScope never heard of it');
    expect(focusWithin(button), isTrue);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(invoked, 1, reason: 'closed, the panel lets Back reach the page');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the keyboard of a field in the panel lifts the panel above it', (tester) async {
    phone(tester);
    await pumpPhone(tester, shell());
    await openPanel(tester);
    const keyboard = 320.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
    await tester.pumpAndSettle();
    expect(titleBar, findsOneWidget);
    expect(layerOpacity(tester), 1, reason: 'the panel stays up while it holds focus');
    expect(tester.getRect(panelSurface).bottom, lessThanOrEqualTo(844 - keyboard));
    expect(tester.getRect(panelSurface).top, greaterThanOrEqualTo(tester.getRect(header).bottom));
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(tester.getRect(panelSurface).bottom, moreOrLessEquals(tester.getRect(button).bottom, epsilon: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a dialog opened from the panel keeps the panel up beneath it', (tester) async {
    phone(tester);
    await pumpPhone(tester, shell());
    await openPanel(tester);
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(find.text('Dialog body'), findsOneWidget);
    expect(titleBar, findsOneWidget);
    expect(layerOpacity(tester), 1);
    // Back belongs to the dialog first, then to the panel.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Dialog body'), findsNothing);
    expect(titleBar, findsOneWidget);
    expect(layerOpacity(tester), 1);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(titleBar, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hiding the entry closes its panel; it does not come back on its own', (tester) async {
    phone(tester);
    final moved = <FrostFloatingEntryPosition>[];
    await pumpPhone(tester, shell(onMoved: moved.add));
    final start = tester.getRect(button);
    await openPanel(tester);
    await tester.pumpWidget(frostTestApp(shell(onMoved: moved.add, visible: false), platform: TargetPlatform.android));
    await tester.pumpAndSettle();
    expect(titleBar, findsNothing);
    expect(FocusManager.instance.primaryFocus, isNotNull);
    expect(focusWithin(button), isFalse);
    await tester.pumpWidget(frostTestApp(shell(onMoved: moved.add), platform: TargetPlatform.android));
    await tester.pumpAndSettle();
    expect(titleBar, findsNothing, reason: 'no panel reappears without focus');
    expect(tester.getRect(button), start);
    expect(moved, isEmpty);
    await openPanel(tester);
    expect(focusWithin(panelScope), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('losing the panel closes it and returns focus to the entry, which now runs its own action', (tester) async {
    phone(tester);
    final moved = <FrostFloatingEntryPosition>[];
    await pumpPhone(tester, shell(onMoved: moved.add));
    await openPanel(tester);
    await tester.drag(titleBar, const Offset(-200, -200));
    await tester.pumpAndSettle();
    await tester.pumpWidget(frostTestApp(shell(onMoved: moved.add, withPanel: false, onPressed: () {}), platform: TargetPlatform.android));
    await tester.pumpAndSettle();
    expect(titleBar, findsNothing);
    expect(moved, hasLength(1), reason: 'the drag still moves the entry');
    expect(moved.single.edge, FrostFloatingEntryEdge.start);
    expect(focusWithin(button), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching to the sidebar layout closes the floating panel cleanly', (tester) async {
    phone(tester);
    final moved = <FrostFloatingEntryPosition>[];
    await pumpPhone(tester, shell(onMoved: moved.add));
    await openPanel(tester);
    tester.view.physicalSize = const Size(1366, 900);
    tester.view.padding = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(titleBar, findsNothing);
    expect(sidebarEntry, findsOneWidget);
    expect(moved, isEmpty, reason: 'an undragged panel keeps the position');
    final focus = FocusManager.instance.primaryFocus;
    expect(focus, isNotNull);
    expect(focus!.context?.mounted, isTrue, reason: 'focus did not stay on a removed node');
    // Back to the phone layout, the entry is where it was and opens again.
    tester.view.physicalSize = phoneSize;
    tester.view.padding = const FakeViewPadding(top: topInset, bottom: bottomInset);
    await tester.pumpAndSettle();
    await openPanel(tester);
    expect(tester.takeException(), isNull);
  });

  for (final (name, size, scale) in [('double text', phoneSize, 2.0), ('a 320-wide window', const Size(320, 640), 1.0)]) {
    testWidgets('at $name the panel opens as a sheet and nothing overflows', (tester) async {
      phone(tester, size);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpPhone(tester, shell());
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(titleBar, findsNothing);
      expect(find.text(panelTitle), findsOneWidget);
      final content = tester.getRect(find.text('chapter-12.zip'));
      expect(content.left, greaterThanOrEqualTo(0));
      expect(content.right, lessThanOrEqualTo(size.width));
      expect(content.bottom, lessThanOrEqualTo(size.height));
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(panelTitle), findsNothing);
      expect(focusWithin(button), isTrue);
    });
  }

  testWidgets('an entry with its own action runs it and opens nothing', (tester) async {
    phone(tester);
    var taps = 0;
    await pumpPhone(tester, shell(onPressed: () => taps++));
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(titleBar, findsNothing);
    expect(find.text(panelTitle), findsNothing);
  });

  testWidgets('without a panel or an action the entry stays disabled', (tester) async {
    phone(tester);
    await pumpPhone(tester, shell(withPanel: false));
    expect(tester.widget<Opacity>(dimmed).opacity, .38);
    await tester.tap(button, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text(panelTitle), findsNothing);
  });

  testWidgets('in the sidebar the panel opens as a popover anchored to the entry', (tester) async {
    tester.view.physicalSize = const Size(1366, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(frostTestApp(shell()));
    await tester.pumpAndSettle();
    final entryRect = tester.getRect(sidebarEntry);
    await tester.tap(sidebarEntry);
    await tester.pumpAndSettle();
    expect(titleBar, findsNothing);
    expect(find.text(panelTitle), findsOneWidget);
    final content = tester.getRect(find.text('cover.png'));
    expect((content.center - entryRect.center).distance, lessThan(400), reason: 'the popover sits by the entry');
    expect(content.right, lessThanOrEqualTo(1366));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text(panelTitle), findsNothing);
    // Focus is back on the entry: on its row or on the trigger wrapping it.
    final focused = FocusManager.instance.primaryFocus?.context;
    expect(focused, isNotNull);
    expect(focusWithin(button), isTrue);
    expect(find.descendant(of: find.byElementPredicate((element) => element == focused), matching: sidebarEntry).evaluate().isNotEmpty || focusWithin(sidebarEntry), isTrue);
    expect(tester.takeException(), isNull);
  });

  group('panel content closes the panel before its action', () {
    late List<bool> ran;
    FrostShellTaskPanel viewAll() => FrostShellTaskPanel(
      title: panelTitle,
      builder: (context) => FrostButton(
        label: 'View all',
        onPressed: () => closeFrostPanelThen(context, (origin) {
          // Runs once the panel has gone, with a context that outlives it.
          ran.add(origin.mounted && find.text(panelTitle).hitTestable().evaluate().isEmpty);
        }),
      ),
    );
    setUp(() => ran = []);

    testWidgets('in the floating panel', (tester) async {
      phone(tester);
      await pumpPhone(tester, shell(taskPanel: viewAll()));
      await openPanel(tester);
      await tester.tap(find.text('View all'));
      await tester.tap(find.text('View all'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(ran, [true]);
      expect(titleBar, findsNothing);
      expect(focusWithin(button), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('in the sheet', (tester) async {
      phone(tester, const Size(320, 640));
      await pumpPhone(tester, shell(taskPanel: viewAll()));
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('View all'));
      await tester.pumpAndSettle();
      expect(ran, [true]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('in the sidebar popover', (tester) async {
      tester.view.physicalSize = const Size(1366, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(frostTestApp(shell(taskPanel: viewAll())));
      await tester.pumpAndSettle();
      await tester.tap(sidebarEntry);
      await tester.pumpAndSettle();
      await tester.tap(find.text('View all'));
      await tester.pumpAndSettle();
      expect(ran, [true]);
      expect(tester.takeException(), isNull);
    });
  });
}
