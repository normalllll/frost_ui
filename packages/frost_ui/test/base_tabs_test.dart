import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/desktop.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/media.dart';
import 'package:frost_ui/src/layout/window_caption_scope.dart' show FrostHitKind;
import 'package:frost_ui/src/lists/_row_scope.dart' show FrostRowInlineValue;

import 'support.dart';
import 'window_caption_test.dart' show FakeWindow;

FrostShellTabs<String> presentation(FrostTabsController<String> tabs, {String? destination}) => FrostShellTabs(
  controller: tabs,
  label: (_, tab) => FrostTabLabel(
    title: tab == tabs.baseTab ? destination ?? tab : tab,
    leading: tab == tabs.baseTab ? const Icon(Icons.home, key: ValueKey('base icon')) : null,
  ),
  countLabel: (count) => '$count tabs',
  closeTooltip: 'Close tab',
  newTabTooltip: 'New tab',
);

Future<void> chord(WidgetTester tester, LogicalKeyboardKey key, {bool shift = false}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

void main() {
  test('base identity survives every close, move and replacement operation', () {
    final removed = <String>[];
    final tabs = FrostTabsController<String>.withBaseTab(baseTab: 'Home', onRemoved: removed.add);
    tabs.open('Video', activate: false);
    tabs.open('Profile', activate: false);
    expect(tabs.canClose(0), isFalse);
    expect(tabs.canMove(0), isFalse);
    expect(tabs.close(0), isFalse);
    tabs.move(0, 2);
    tabs.move(2, 0);
    expect(tabs.tabs, ['Home', 'Profile', 'Video']);
    tabs.open('Home', activate: false);
    expect(tabs.length, 3);
    tabs.replaceAll('Search');
    expect(tabs.tabs, ['Home', 'Search']);
    expect(removed, ['Profile', 'Video']);
    tabs.replaceAll('Search');
    expect(removed, ['Profile', 'Video']);
    tabs.close(1);
    expect(tabs.active, 'Home');
    expect(tabs.isBaseTabActive, isTrue);
    tabs.replaceAll('Home');
    expect(tabs.tabs, ['Home']);
    expect(removed, isNot(contains('Home')));
    tabs.dispose();
    expect(removed.where((tab) => tab == 'Home'), hasLength(1));
  });

  testWidgets('base strip blocks pointer closes and drags, while content cannot cross it', (tester) async {
    final tabs = FrostTabsController<String>.withBaseTab(baseTab: 'Home')
      ..open('Video', activate: false)
      ..open('Profile', activate: false);
    addTearDown(tabs.dispose);
    await tester.pumpWidget(
      frostTestApp(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 600, height: 40, child: Builder(builder: (context) => presentation(tabs).strip(context))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final base = find.ancestor(of: find.byKey(const ValueKey('base icon')), matching: find.byType(Positioned)).first;
    final rect = tester.getRect(base);
    expect(rect.width, rect.height);
    expect(find.text('Home'), findsNothing);
    expect(findFrostTooltip('Home'), findsOneWidget);
    expect(findFrostTooltip('Close tab'), findsNWidgets(2));
    expect(findFrostTooltip('New tab'), findsNothing);
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Home'), findsWidgets);
    final middle = await tester.createGesture(kind: PointerDeviceKind.mouse, buttons: kMiddleMouseButton);
    await middle.down(rect.center);
    await middle.up();
    await tester.pumpAndSettle();
    expect(tabs.length, 3);
    await tester.dragFrom(rect.center, const Offset(350, 0));
    await tester.pumpAndSettle();
    expect(tabs.tabs.first, 'Home');
    final video = tester.getCenter(find.text('Video'));
    await tester.dragFrom(video, const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(tabs.tabs.first, 'Home');
    expect(tester.getRect(base), rect);
    final videoRect = tester.getRect(find.ancestor(of: find.text('Video'), matching: find.byType(Positioned)).first);
    expect(videoRect.left, greaterThanOrEqualTo(rect.right));
    semantics.dispose();
  });

  testWidgets('overview lists the named base first without close or new controls', (tester) async {
    final tabs = FrostTabsController<String>.withBaseTab(baseTab: 'Home')..open('Video');
    addTearDown(tabs.dispose);
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) => FrostButton(label: 'Overview', onPressed: () => presentation(tabs).showOverview(context)),
        ),
      ),
    );
    await tester.tap(find.text('Overview'));
    await tester.pumpAndSettle();
    final rows = tester.widgetList<FrostListRow>(find.byType(FrostListRow)).toList();
    expect(rows.first.title, 'Home');
    final rowFinder = find.byType(FrostListRow);
    expect(find.descendant(of: rowFinder.first, matching: find.byKey(const ValueKey('base icon'))), findsOneWidget);
    expect(find.descendant(of: rowFinder.first, matching: find.byType(FrostButton)), findsNothing);
    expect(find.descendant(of: rowFinder.last, matching: find.byType(FrostButton)), findsOneWidget);
    expect(find.ancestor(of: rowFinder.last, matching: find.byType(FrostRowInlineValue)), findsOneWidget);
    expect(find.text('New tab'), findsNothing);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(tabs.isBaseTabActive, isTrue);
  });

  for (final base in [false, true]) {
    testWidgets('the host binds no tab keys and leaves them to the app base=$base', (tester) async {
      final tabs = base ? FrostTabsController<String>.withBaseTab(baseTab: 'Home') : FrostTabsController<String>(initial: 'Home');
      tabs.open('Video', activate: false);
      addTearDown(tabs.dispose);
      var outerNew = 0, hostNew = 0, reopened = 0;
      await tester.pumpWidget(
        frostTestApp(
          CallbackShortcuts(
            bindings: {const SingleActivator(LogicalKeyboardKey.keyT, control: true): () => outerNew++},
            child: FrostTabHost<String>(
              controller: tabs,
              onNewTab: () => hostNew++,
              onReopen: () => reopened++,
              builder: (_, tab) => TextButton(onPressed: () {}, child: Text('Page $tab')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await chord(tester, LogicalKeyboardKey.keyT);
      expect(outerNew, 1);
      expect(hostNew, 0);
      await chord(tester, LogicalKeyboardKey.keyT, shift: true);
      expect(reopened, 0);
      for (final key in [LogicalKeyboardKey.tab, LogicalKeyboardKey.pageDown, LogicalKeyboardKey.digit9, LogicalKeyboardKey.keyW, LogicalKeyboardKey.f4]) {
        await chord(tester, key);
      }
      expect(tabs.active, 'Home');
      expect(tabs.length, 2);
    });
  }

  testWidgets('sidebar returns to the base stack before applying destination/reselection', (tester) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = GlobalKey<_ShellFixtureState>();
    await tester.pumpWidget(frostTestApp(_ShellFixture(key: state)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open detail'));
    await tester.pumpAndSettle();
    state.currentState!.tabs.activate(1);
    await tester.pumpAndSettle();
    final nav = find.byWidgetPredicate((widget) => widget is FrostNavItem && widget.label == 'Home');
    expect(tester.widget<FrostNavItem>(nav).selected, isFalse);
    await tester.tap(nav);
    await tester.pumpAndSettle();
    expect(find.text('Retained detail'), findsOneWidget);
    expect(state.currentState!.selections, 0);
    // The retained detail is a pushed page: the sidebar stays without a highlight.
    expect(tester.widget<FrostNavItem>(nav).selected, isFalse);
    await tester.tap(nav);
    await tester.pumpAndSettle();
    expect(find.text('Open detail'), findsOneWidget);
    expect(state.currentState!.selections, 1);
    state.currentState!.tabs.activate(1);
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate((widget) => widget is FrostNavItem && widget.label == 'Messages'));
    await tester.pumpAndSettle();
    expect(state.currentState!.tabs.isBaseTabActive, isTrue);
    expect(state.currentState!.destination, 1);
    expect(state.currentState!.selections, 2);
  });

  testWidgets('background link gestures preserve primary click and cancelled middle drags', (tester) async {
    var ordinary = 0, background = 0, foreground = 0;
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: FrostClickSurface(
            onTap: () => ordinary++,
            onOpenInBackground: () => background++,
            onOpenInNewTab: () => foreground++,
            child: const SizedBox(width: 200, height: 100, child: Text('Link')),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Link'));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(find.text('Link'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.tap(find.text('Link'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse, buttons: kMiddleMouseButton);
    await mouse.down(tester.getCenter(find.text('Link')));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(ordinary, 1);
    expect(background, 1);
    expect(foreground, 2);
    await mouse.down(tester.getCenter(find.text('Link')));
    await mouse.moveBy(const Offset(200, 200));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(background, 1);
  });

  for (final row in [false, true]) {
    testWidgets('media link forwards background gestures and its touch menu row=$row', (tester) async {
      var ordinary = 0, background = 0, foreground = 0;
      final menu = [FrostMenuAction('Open in background', onSelected: () => background++)];
      final link = row
          ? FrostMediaRow(
              media: const ColoredBox(color: Colors.grey),
              title: 'Media link',
              onPressed: () => ordinary++,
              onOpenInBackground: () => background++,
              onOpenInNewTab: () => foreground++,
              contextMenu: menu,
            )
          : FrostMediaCard(
              media: const ColoredBox(color: Colors.grey),
              aspectRatio: 16 / 9,
              footer: const Text('Media link'),
              onPressed: () => ordinary++,
              onOpenInBackground: () => background++,
              onOpenInNewTab: () => foreground++,
              contextMenu: menu,
            );
      await tester.pumpWidget(
        frostTestApp(
          Center(child: SizedBox(width: 300, child: link)),
          platform: TargetPlatform.android,
        ),
      );
      await tester.tap(find.text('Media link'));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(find.text('Media link'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.longPress(find.text('Media link'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open in background'));
      await tester.pumpAndSettle();
      expect(ordinary, 1);
      expect(background, 1);
      expect(foreground, 1);
    });
  }

  testWidgets('bottom mode hides the strip and keeps content tabs across navigation', (tester) async {
    tester.view.physicalSize = const Size(411, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = GlobalKey<_ShellFixtureState>();
    await tester.pumpWidget(frostTestApp(_ShellFixture(key: state, bottom: true), platform: TargetPlatform.android));
    await tester.pumpAndSettle();
    state.currentState!.tabs.activate(1);
    await tester.pumpAndSettle();
    expect(find.byType(FrostTabStrip<String>), findsNothing);
    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();
    expect(state.currentState!.tabs.tabs, ['Home', 'Video']);
    expect(state.currentState!.tabs.isBaseTabActive, isTrue);
    state.currentState!.tabs.activate(1);
    await tester.pumpAndSettle();
    expect(find.text('Video content'), findsOneWidget);
  });

  testWidgets('folded caption retains App base and lists only content, then keeps a lone base visible', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = GlobalKey<_ShellFixtureState>();
    await tester.pumpWidget(frostTestApp(_ShellFixture(key: state)));
    await tester.pumpAndSettle();
    final baseRect = tester.getRect(find.byKey(const ValueKey('app icon')));
    expect(findFrostTooltip('Frost App · Home'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('frost-shell-tabs-collapsed')));
    await tester.pumpAndSettle();
    final rows = tester.widgetList<FrostListRow>(find.byType(FrostListRow)).toList();
    expect(rows.map((row) => row.title), ['Video']);
    expect(find.descendant(of: find.byType(FrostListRow).first, matching: find.byType(FrostButton)), findsOneWidget);
    expect(find.text('1 tabs'), findsWidgets);
    await tester.tap(find.text('Video').last);
    await tester.pumpAndSettle();
    expect(state.currentState!.tabs.active, 'Video');
    await tester.tap(find.byKey(const ValueKey('app icon')));
    await tester.pumpAndSettle();
    expect(state.currentState!.tabs.isBaseTabActive, isTrue);
    expect(tester.getRect(find.byKey(const ValueKey('app icon'))), baseRect);
    state.currentState!.tabs.close(1);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('app icon')), findsOneWidget);
    expect(find.byKey(const ValueKey('frost-shell-tabs-collapsed')), findsNothing);
    expect(findFrostTooltip('New tab'), findsNothing);
  });

  testWidgets('App base is the first client button with live destination semantics and shared selection', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final window = FakeWindow();
    final state = GlobalKey<_ShellFixtureState>();
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      frostTestApp(
        FrostWindowCaptionScope(
          window: window,
          child: _ShellFixture(key: state),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final icon = find.byKey(const ValueKey('app icon'));
    final base = find.ancestor(of: icon, matching: find.byType(Positioned)).first;
    final rect = tester.getRect(base);
    expect(find.byKey(const ValueKey('base icon')), findsNothing);
    expect(icon, findsOneWidget);
    expect(tester.getSize(icon), const Size(24, 24));
    final back = tester.getRect(find.byKey(const ValueKey('frost-shell-back')));
    expect(rect.left - back.right, FrostGap.related);
    expect(rect.width, rect.height);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Frost App · Home').first),
      matchesSemantics(label: 'Frost App · Home', isButton: true, isSelected: true, hasSelectedState: true, hasTapAction: true),
    );
    expect(window.calls.last.any((r) => r.kind == FrostHitKind.client && r.rect.contains(rect.center)), isTrue);
    final videoRect = tester.getRect(find.ancestor(of: find.text('Video'), matching: find.byType(Positioned)).first);
    expect(window.calls.last.any((r) => r.kind == FrostHitKind.caption && r.rect.contains(Offset(videoRect.right + 20, rect.center.dy))), isTrue);
    state.currentState!.tabs.activate(1);
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.bySemanticsLabel('Frost App · Home').first),
      matchesSemantics(label: 'Frost App · Home', isButton: true, hasSelectedState: true, hasTapAction: true),
    );
    await tester.dragFrom(rect.center, const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(state.currentState!.tabs.isBaseTabActive, isTrue);
    expect(tester.getRect(base), rect);
    await tester.tap(find.byWidgetPredicate((w) => w is FrostNavItem && w.label == 'Messages'));
    await tester.pumpAndSettle();
    expect(findFrostTooltip('Frost App · Messages'), findsOneWidget);
    expect(find.bySemanticsLabel('Frost App · Messages'), findsOneWidget);
    expect(tester.getRect(base), rect);
    final baseFill = tester.widgetList<AnimatedContainer>(find.descendant(of: base, matching: find.byType(AnimatedContainer))).first.decoration;
    state.currentState!.tabs.activate(1);
    await tester.pumpAndSettle();
    final video = find.ancestor(of: find.text('Video'), matching: find.byType(Positioned)).first;
    final videoFill = tester.widgetList<AnimatedContainer>(find.descendant(of: video, matching: find.byType(AnimatedContainer))).first.decoration;
    // The base tab keeps the accent wash; a selected content tab is neutral raised.
    expect((baseFill! as ShapeDecoration).color, FrostThemeTokens.of(tester.element(base)).selectionFill);
    expect((videoFill! as ShapeDecoration).color, FrostThemeTokens.of(tester.element(base)).surfaceRaised);
    semantics.dispose();
  });

  for (final tabsEnabled in [false, true]) {
    testWidgets('ordinary App branding is retained tabs=$tabsEnabled', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final tabs = FrostTabsController<String>(initial: 'Home')..open('Video', activate: false);
      addTearDown(tabs.dispose);
      await tester.pumpWidget(
        frostTestApp(
          FrostWindowCaptionScope(
            window: FakeWindow(),
            child: FrostShell(
              tabs: tabsEnabled ? presentation(tabs) : null,
              brand: const FrostShellBrand(
                expanded: Row(
                  children: [
                    Icon(Icons.apps, key: ValueKey('full app icon')),
                    Text('Frost App'),
                  ],
                ),
                icon: Icon(Icons.apps, key: ValueKey('standalone brand icon')),
                label: 'Frost App',
              ),
              destinations: [FrostNavDestination(icon: testIcons.image, label: 'Home')],
              selectedIndex: 0,
              atDestinationRoot: true,
              showsMobileNavigation: true,
              onDestinationSelected: (_) {},
              canGoBack: false,
              onBack: () {},
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Frost App'), tabsEnabled ? findsNothing : findsOneWidget);
      expect(find.byKey(const ValueKey('full app icon')), tabsEnabled ? findsNothing : findsOneWidget);
      expect(find.byKey(const ValueKey('standalone brand icon')), tabsEnabled ? findsOneWidget : findsNothing);
      expect(findFrostTooltip('Frost App · Home'), findsNothing);
    });
  }

  testWidgets('touch overview keeps App icon and destination with no base close control', (tester) async {
    tester.view.physicalSize = const Size(1366, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = GlobalKey<_ShellFixtureState>();
    await tester.pumpWidget(frostTestApp(_ShellFixture(key: state), platform: TargetPlatform.android));
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate((w) => w is FrostNavItem && w.label == 'Messages'));
    await tester.pumpAndSettle();
    await tester.tap(findFrostTooltip('2 tabs'));
    await tester.pumpAndSettle();
    final rows = tester.widgetList<FrostListRow>(find.byType(FrostListRow)).toList();
    expect(rows.map((r) => r.title), ['Messages', 'Video']);
    final rowFinder = find.byType(FrostListRow);
    expect(find.descendant(of: rowFinder.first, matching: find.byKey(const ValueKey('app icon'))), findsOneWidget);
    expect(find.descendant(of: rowFinder.first, matching: find.byType(FrostButton)), findsNothing);
    expect(rows.first.selected, isTrue);
    expect(find.descendant(of: rowFinder.last, matching: find.byType(FrostButton)), findsOneWidget);
    expect(find.byKey(const ValueKey('base icon')), findsNothing);
  });
}

class _ShellFixture extends StatefulWidget {
  const _ShellFixture({this.bottom = false, super.key});
  final bool bottom;
  @override
  State<_ShellFixture> createState() => _ShellFixtureState();
}

class _ShellFixtureState extends State<_ShellFixture> {
  final tabs = FrostTabsController<String>.withBaseTab(baseTab: 'Home')..open('Video', activate: false);
  final navigator = GlobalKey<NavigatorState>();
  int destination = 0, depth = 0, selections = 0;
  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: tabs,
    builder: (context, _) => FrostShell(
      tabs: presentation(tabs, destination: destination == 0 ? 'Home' : 'Messages'),
      brand: const FrostShellBrand(
        icon: Icon(Icons.apps, key: ValueKey('app icon')),
        label: 'Frost App',
      ),
      navigationPlacement: widget.bottom ? FrostNavigationPlacement.bottom : FrostNavigationPlacement.sidebar,
      titleBarContent: const Text('Search'),
      showsMobileNavigation: true,
      destinations: [
        FrostNavDestination(icon: testIcons.image, label: 'Home'),
        FrostNavDestination(icon: testIcons.search, label: 'Messages'),
      ],
      selectedIndex: destination,
      atDestinationRoot: depth == 0,
      canGoBack: depth > 0,
      onBack: () => navigator.currentState?.maybePop(),
      onDestinationSelected: (index) {
        selections++;
        navigator.currentState?.popUntil((route) => route.isFirst);
        setState(() {
          destination = index;
          depth = 0;
        });
      },
      child: FrostTabHost<String>(
        controller: tabs,
        builder: (context, tab) => tab == 'Video'
            ? const FrostShellDestination(child: Text('Video content'))
            : Navigator(
                key: navigator,
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (context) => FrostShellDestination(
                    child: TextButton(
                      onPressed: () {
                        setState(() => depth = 1);
                        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const Text('Retained detail')));
                      },
                      child: const Text('Open detail'),
                    ),
                  ),
                ),
              ),
      ),
    ),
  );
}
