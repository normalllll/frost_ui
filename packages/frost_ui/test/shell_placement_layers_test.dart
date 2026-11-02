import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/desktop.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_button_control.dart';
import 'package:frost_ui/src/navigation/back_to_first_button.dart' show FrostBackToFirstButton;
import 'package:frost_ui/src/navigation/window_caption.dart' show FrostCaptionButtons;
import 'package:frost_ui/src/overlays/_menu_panel.dart';
import 'package:frost_ui/src/primitives/_on_media_chrome_scope.dart' show FrostOnMediaChromeScope;

import 'support.dart';
import 'window_caption_test.dart' show FakeWindow;

final destinations = [
  FrostNavDestination(icon: testIcons.image, label: 'Home', badge: 7),
  FrostNavDestination(icon: testIcons.search, label: 'Library'),
  FrostNavDestination(icon: testIcons.more, label: 'Account', badge: 2),
];

FrostShellTabs<String> presentation(FrostTabsController<String> controller) => FrostShellTabs(
  controller: controller,
  label: (_, tab) => FrostTabLabel(title: tab),
  countLabel: (count) => '$count tabs',
  sidebarLabel: (count) => 'Tabs $count',
  closeTooltip: 'Close tab',
  newTabTooltip: 'New tab',
  onNewTab: () => controller.open('Added ${controller.length}'),
);

Widget shell({
  Widget child = const FrostShellDestination(child: SizedBox.expand()),
  FrostNavigationPlacement? placement,
  FrostShellTabs<Object>? tabs,
  int depth = 0,
  VoidCallback? first,
  ValueChanged<int>? select,
  FrostSidebarAlignment alignment = FrostSidebarAlignment.automatic,
}) => FrostShell(
  navigationPlacement: placement,
  sidebarAlignment: alignment,
  tabs: tabs,
  brand: const FrostShellBrand(
    expanded: Text('Frost Family', key: ValueKey('full-brand'), maxLines: 1, overflow: TextOverflow.ellipsis),
    icon: SizedBox(width: 24, height: 24, key: ValueKey('brand-icon')),
  ),
  titleBarContent: FrostSearchEntry(placeholder: 'Search everything', shortcutLabel: 'Ctrl K', onPressed: () {}),
  destinations: destinations,
  selectedIndex: 0,
  atDestinationRoot: depth == 0,
  onDestinationSelected: select ?? (_) {},
  canGoBack: depth > 0,
  onBack: () {},
  routeDepth: depth,
  backToFirst: first == null ? null : FrostShellBackToFirst(label: 'Back to first', icon: testIcons.collapse, onPressed: first),
  showsMobileNavigation: true,
  child: child,
);

void viewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  test('automatic navigation uses a content minimum and the window shape', () {
    for (final (size, sidebar, pointerSidebar) in [
      (const Size(411, 960), false, false),
      (const Size(500, 1400), false, false),
      (const Size(750, 832), false, false),
      (const Size(800, 1400), false, false),
      (const Size(832, 750), false, true),
      (const Size(1100, 900), false, true),
      (const Size(1366, 1024), true, true),
      (const Size(1400, 900), true, true),
      (const Size(479, 300), false, false),
      (const Size(480, 369), true, true),
      (const Size(600, 462), false, true),
      (const Size(600, 461), true, true),
    ]) {
      expect(isHorizontalSize(size), sidebar, reason: '$size');
      expect(isHorizontalSize(size, pointer: true), pointerSidebar, reason: '$size with a pointer');
    }
  });

  testWidgets('Shell overrides and inherits the placement above the router', (tester) async {
    viewport(tester, const Size(750, 832));
    bool? horizontal;
    Widget probe(FrostNavigationPlacement? placement) => shell(
      placement: placement,
      child: Builder(
        builder: (context) {
          horizontal = FrostAutoScaffold.usesHorizontalLayoutOf(context);
          return const SizedBox();
        },
      ),
    );
    await tester.pumpWidget(
      frostTestApp(
        FrostLayoutScope(navigationPlacement: FrostNavigationPlacement.sidebar, child: probe(null)),
        platform: TargetPlatform.android,
      ),
    );
    expect(horizontal, isTrue);
    await tester.pumpWidget(
      frostTestApp(
        FrostLayoutScope(navigationPlacement: FrostNavigationPlacement.sidebar, child: probe(FrostNavigationPlacement.bottom)),
        platform: TargetPlatform.android,
      ),
    );
    expect(horizontal, isFalse);
    await tester.pumpWidget(frostTestApp(probe(null)));
    await tester.pumpAndSettle();
    expect(horizontal, isFalse, reason: 'a portrait pointer window has phone-like pages');
  });

  testWidgets('caption keeps an icon-only brand and collapses tabs before search while retaining native controls', (tester) async {
    viewport(tester, const Size(1147, 717));
    final controller = FrostTabsController<String>(initial: 'Home')
      ..open('Video')
      ..open('Library');
    addTearDown(controller.dispose);
    final window = FakeWindow();
    await tester.pumpWidget(
      frostTestApp(
        FrostWindowCaptionScope(
          window: window,
          child: shell(tabs: presentation(controller)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FrostTabStrip<String>), findsNothing);
    for (final width in [960.0, 650.0, 480.0]) {
      tester.view.physicalSize = Size(width, 400);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('frost-shell-tabs-collapsed')), findsOneWidget);
      expect(find.text('Search everything'), width >= 960 ? findsOneWidget : findsNothing);
      expect(find.byKey(const ValueKey('brand-icon')), width >= 650 ? findsOneWidget : findsNothing);
      expect(find.byKey(const ValueKey('full-brand')), findsNothing);
      expect(find.byKey(const ValueKey('frost-shell-back')), findsOneWidget);
      expect(find.byType(FrostCaptionButtons), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    final back = tester.widget<FrostButtonControl>(find.byKey(const ValueKey('frost-shell-back')));
    expect(back.onPressed, isNull);
  });

  testWidgets('tab caption respects native-controls clearance without changing native ownership', (tester) async {
    viewport(tester, const Size(1100, 700));
    final controller = FrostTabsController<String>(initial: 'Home')..open('Video');
    addTearDown(controller.dispose);
    final window = FakeWindow();
    window.current = const FrostCaptionState(
      maximized: false,
      active: true,
      maximizeHovered: false,
      maximizePressed: false,
      failed: false,
      mode: FrostCaptionMode.nativeControls,
      nativeControls: Rect.fromLTWH(8, 8, 72, 28),
    );
    await tester.pumpWidget(
      frostTestApp(
        FrostWindowCaptionScope(
          window: window,
          child: shell(tabs: presentation(controller)),
        ),
        platform: TargetPlatform.macOS,
      ),
    );
    await tester.pumpAndSettle();
    final back = tester.getRect(find.byKey(const ValueKey('frost-shell-back')));
    expect(back.left, greaterThanOrEqualTo(80));
    expect(find.byType(FrostTabStrip<String>), findsNothing);
    expect(window.operations, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('touch sidebar defaults low, can move up, and opens an actionable tab overview', (tester) async {
    final semantics = tester.ensureSemantics();
    viewport(tester, const Size(1366, 1024));
    final controller = FrostTabsController<String>(initial: 'Home')
      ..open('Video')
      ..open('Library');
    addTearDown(controller.dispose);
    Widget app(FrostSidebarAlignment alignment) => frostTestApp(
      shell(tabs: presentation(controller), alignment: alignment),
      platform: TargetPlatform.android,
    );
    await tester.pumpWidget(app(FrostSidebarAlignment.automatic));
    await tester.pumpAndSettle();
    final low = tester.getTopLeft(find.byType(FrostNavItem).first).dy;
    expect(low, greaterThan(700));
    final overview = find.byKey(const ValueKey('frost-shell-tabs-overview'));
    expect(tester.getSemantics(overview), matchesSemantics(label: 'Tabs 3', isButton: true, hasTapAction: true));
    final overviewItem = tester.widget<FrostNavItem>(find.descendant(of: overview, matching: find.byType(FrostNavItem)));
    expect(overviewItem.icon, testIcons.multiPage);
    expect(overviewItem.selected, false);
    expect(tester.getTopLeft(overview).dy, greaterThan(tester.getBottomRight(find.byType(FrostNavItem).at(destinations.length - 1)).dy));
    await tester.tap(overview);
    await tester.pumpAndSettle();
    expect(find.text('3 tabs'), findsWidgets);
    final panel = tester.getRect(find.byWidgetPredicate((w) => w is FrostSurface && w.role == FrostSurfaceRole.sheet));
    expect(panel.left, greaterThanOrEqualTo(80));
    expect(panel.top, greaterThanOrEqualTo(44));
    final library = find.byWidgetPredicate((w) => w is FrostListRow && w.title == 'Library');
    await tester.tap(find.descendant(of: library, matching: find.byType(FrostButton)).last);
    await tester.pumpAndSettle();
    expect(controller.length, 2);
    expect(find.text('3 tabs'), findsNothing);
    expect(find.text('2 tabs'), findsWidgets);
    await tester.tap(find.byWidgetPredicate((w) => w is FrostListRow && w.title == 'Home'));
    await tester.pumpAndSettle();
    expect(controller.active, 'Home');
    await tester.pumpWidget(app(FrostSidebarAlignment.top));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(FrostNavItem).first).dy, lessThan(100));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    testWidgets('caption shares spare width with tabs and mirrors edge clearance without window buttons $platform', (tester) async {
      viewport(tester, const Size(1366, 1024));
      final controller = FrostTabsController<String>(initial: 'Home')
        ..open('Video')
        ..open('Library');
      addTearDown(controller.dispose);
      await tester.pumpWidget(frostTestApp(shell(tabs: presentation(controller)), platform: platform));
      await tester.pumpAndSettle();
      Rect tabRect() => tester.getRect(find.ancestor(of: find.text('Video'), matching: find.byType(Positioned)).first);
      expect(tabRect().width, inInclusiveRange(112, 220));
      final back = find.byKey(const ValueKey('frost-shell-back'));
      final visual = tester.getRect(find.descendant(of: back, matching: find.byType(CustomPaint)).first);
      final search = tester.getRect(find.byType(FrostSearchEntry));
      final clearance = platform == TargetPlatform.android ? 10.0 : 8.0;
      expect(visual.left, closeTo(clearance, .01));
      expect(search.center.dx, closeTo(1366 / 2, .01));
      for (final width in [960.0, 950.0]) {
        tester.view.physicalSize = Size(width, 717);
        await tester.pumpAndSettle();
        final entry = tester.getRect(find.byType(FrostSearchEntry));
        expect(find.byKey(const ValueKey('frost-shell-tabs-collapsed')), findsOneWidget);
        expect(entry.center.dx, closeTo(width / 2, .01));
        expect(tester.takeException(), isNull);
      }
      tester.view.physicalSize = const Size(650, 450);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('frost-shell-tabs-collapsed')), findsOneWidget);
      expect(controller.length, 3);
    });
  }

  for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
    testWidgets('sheet autofocus has no ring after $kind opening and keeps keyboard navigation', (tester) async {
      viewport(tester, const Size(750, 832));
      final previous = FocusManager.instance.highlightStrategy;
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = previous);
      final entryFocus = FocusNode();
      addTearDown(entryFocus.dispose);
      await tester.pumpWidget(
        frostTestApp(
          FrostInputFeedback(
            child: Builder(
              builder: (context) => Center(
                child: FrostButtonControl(
                  label: 'Open replies',
                  focusNode: entryFocus,
                  onPressed: () => showFrostSheet<void>(
                    context: context,
                    title: 'Replies',
                    presentation: FrostSheetPresentation.bottom,
                    detents: const [FrostSheetDetent.fitted],
                    builder: (_) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Reply content'),
                        FrostButton(label: 'Reply action', onPressed: () {}),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          platform: kind == PointerDeviceKind.touch ? TargetPlatform.android : TargetPlatform.windows,
        ),
      );
      await tester.pumpAndSettle();
      final gesture = await tester.createGesture(kind: kind);
      await gesture.addPointer(location: Offset.zero);
      await gesture.down(tester.getCenter(find.text('Open replies')));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('Reply content'), findsOneWidget);
      expect(frostFocusRings(), findsNothing, reason: 'modal focus ownership must not imply keyboard use');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(frostFocusRings(), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Reply content'), findsNothing);
      entryFocus.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Reply content'), findsOneWidget);
      expect(frostFocusRings(), findsNothing, reason: 'the sheet itself holds focus');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(frostFocusRings(), findsOneWidget, reason: 'Tab reaches the first control with a visible ring');
      await gesture.removePointer();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('programmatic Android-theme sheets still use the global highlight strategy', (tester) async {
    viewport(tester, const Size(411, 960));
    final previous = FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = previous);
    late BuildContext source;
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) {
            source = context;
            return const SizedBox.expand();
          },
        ),
        platform: TargetPlatform.android,
      ),
    );
    showFrostSheet<void>(context: source, title: 'Replies', builder: (_) => const Text('No pointer event'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(frostFocusRings(), findsOneWidget, reason: 'a local Theme is not a simulated touch input');
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
    await tester.pumpAndSettle();
    expect(frostFocusRings(), findsNothing);
    expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue, reason: 'keep focus ownership for accessibility and later Tab');
  });

  testWidgets('resizing preserves tabs, navigator, draft, scroll and the mounted media owner', (tester) async {
    viewport(tester, const Size(1366, 1024));
    final controller = FrostTabsController<String>(initial: 'Home')..open('Other', activate: false);
    addTearDown(controller.dispose);
    final navigator = GlobalKey<NavigatorState>();
    final draft = TextEditingController();
    final scroll = ScrollController();
    addTearDown(draft.dispose);
    addTearDown(scroll.dispose);
    var mediaBuilds = 0;
    final mediaKey = GlobalKey();
    final content = FrostTabHost<String>(
      controller: controller,
      builder: (context, tab) => tab != 'Home'
          ? const Text('Other tab')
          : Navigator(
              key: navigator,
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => FrostShellDestination(
                  child: Column(
                    children: [
                      _RetainedMedia(key: mediaKey, onInit: () => mediaBuilds++),
                      FrostTextField(controller: draft),
                      Expanded(
                        child: ListView(
                          controller: scroll,
                          children: List.generate(60, (i) => SizedBox(height: 40, child: Text('Item $i'))),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
    await tester.pumpWidget(
      frostTestApp(
        shell(tabs: presentation(controller), child: content),
        platform: TargetPlatform.android,
      ),
    );
    await tester.pumpAndSettle();
    draft.text = 'unsent draft';
    scroll.jumpTo(300);
    navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Text('Retained detail')));
    await tester.pumpAndSettle();
    final nav = navigator.currentState, media = mediaKey.currentState;
    for (final size in [const Size(750, 832), const Size(832, 750), const Size(1366, 1024)]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(navigator.currentState, same(nav));
      expect(navigator.currentState!.canPop(), isTrue);
      expect(mediaKey.currentState, same(media));
      expect(mediaBuilds, 1);
      expect(draft.text, 'unsent draft');
      expect(scroll.offset, 300);
      expect(controller.length, 2);
    }
    tester.view.physicalSize = const Size(750, 832);
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(controller.active, 'Home', reason: 'bottom mode keeps other tabs in the background');
    expect(tester.takeException(), isNull);
  });

  testWidgets('page and media first-page buttons share the App depth and callback', (tester) async {
    viewport(tester, const Size(411, 960));
    var calls = 0;
    await tester.pumpWidget(
      frostTestApp(
        shell(
          depth: 2,
          first: () => calls++,
          child: const Column(
            children: [
              FrostPageHeader(title: Text('Detail')),
              FrostOnMediaChromeScope(child: FrostBackToFirstButton()),
            ],
          ),
        ),
        platform: TargetPlatform.android,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FrostBackToFirstButton), findsNWidgets(2));
    await tester.tap(find.byType(FrostBackToFirstButton).first);
    await tester.tap(find.byType(FrostBackToFirstButton).last);
    expect(calls, 2);
  });

  for (final scale in [2.0, 3.0]) {
    testWidgets('tab caption keeps all controls in bounds at large text $scale', (tester) async {
      viewport(tester, const Size(650, 600));
      final tabs = FrostTabsController<String>(initial: 'Home')
        ..open('Video')
        ..open('Library');
      addTearDown(tabs.dispose);
      await tester.pumpWidget(
        frostTestApp(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: FrostWindowCaptionScope(
                window: FakeWindow(),
                child: shell(tabs: presentation(tabs)),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('frost-shell-tabs-collapsed')), findsOneWidget);
      expect(find.byType(FrostCaptionButtons), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('selection sheets inherit nested region bounds under a scaled preview', (tester) async {
    viewport(tester, const Size(800, 800));
    var selected = 1;
    await tester.pumpWidget(
      frostTestApp(
        Align(
          alignment: Alignment.topLeft,
          child: Transform.scale(
            scale: .75,
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 500,
              height: 700,
              child: Column(
                children: [
                  const SizedBox(height: 200),
                  Expanded(
                    child: TestOverlayRegion(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: FrostPicker<int>.menu(
                          options: const [
                            FrostPickerOption(value: 1, label: 'First option'),
                            FrostPickerOption(value: 2, label: 'Second option'),
                          ],
                          value: selected,
                          label: 'Choice',
                          onChanged: (value) => selected = value,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FrostPicker<int>));
    await tester.pumpAndSettle();
    final barrier = tester.getRect(find.byWidgetPredicate((w) => w is ModalBarrier && w.dismissible));
    expect(barrier, const Rect.fromLTWH(0, 150, 375, 375));
    final option = find.byWidgetPredicate((w) => w is FrostListRow && w.title == 'Second option');
    expect(tester.getRect(option).top, greaterThanOrEqualTo(150));
    expect(tester.getRect(option).right, lessThanOrEqualTo(375));
    await tester.tap(option);
    await tester.pumpAndSettle();
    expect(selected, 2);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 2.0, 3.0]) {
    testWidgets('scoped sheets and menus stay below media through live resize scale=$scale', (tester) async {
      viewport(tester, const Size(700, 900));
      final region = GlobalKey();
      var mediaTaps = 0;
      late BuildContext source;
      await tester.pumpWidget(
        frostTestApp(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: Column(
                children: [
                  SizedBox(
                    height: 160,
                    child: GestureDetector(
                      key: const ValueKey('media'),
                      onTap: () => mediaTaps++,
                      behavior: HitTestBehavior.opaque,
                      child: const SizedBox.expand(),
                    ),
                  ),
                  Expanded(
                    child: TestOverlayRegion(
                      key: region,
                      child: Builder(
                        builder: (context) {
                          source = context;
                          return FrostButton(
                            label: 'Open sheet',
                            onPressed: () => showFrostSheet<void>(
                              context: context,
                              title: 'Replies',
                              presentation: FrostSheetPresentation.bottom,
                              detents: const [FrostSheetDetent.fitted],
                              builder: (_) => const Text('Reply text'),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open sheet'));
      await tester.pumpAndSettle();
      final surface = find.byWidgetPredicate((w) => w is FrostSurface && w.role == FrostSurfaceRole.sheet);
      final boundary = tester.getRect(find.byKey(region));
      expect(tester.getRect(surface).top, greaterThanOrEqualTo(boundary.top));
      expect(tester.getRect(surface).bottom, lessThanOrEqualTo(boundary.bottom));
      expect(tester.getRect(find.byWidgetPredicate((w) => w is ModalBarrier && w.dismissible)).top, boundary.top);
      tester.view.physicalSize = const Size(411, 760);
      await tester.pumpAndSettle();
      expect(tester.getRect(surface).top, greaterThanOrEqualTo(160));
      expect(tester.getRect(surface).right, lessThanOrEqualTo(411));
      await tester.tap(find.byKey(const ValueKey('media')));
      expect(mediaTaps, 1, reason: 'barrier does not intercept the media above the region');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      showFrostContextMenu(
        context: source,
        globalPosition: const Offset(690, 880),
        entries: [FrostMenuAction('Queue this', onSelected: () {})],
      );
      await tester.pumpAndSettle();
      final panel = tester.getRect(find.byType(FrostMenuPanel));
      expect(panel.top, greaterThanOrEqualTo(boundary.top));
      expect(panel.right, lessThanOrEqualTo(boundary.right));
      expect(panel.bottom, lessThanOrEqualTo(boundary.bottom));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(411, 760);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open sheet'));
      await tester.pumpAndSettle();
      expect(tester.getRect(surface).top, greaterThanOrEqualTo(160));
      expect(tester.takeException(), isNull);
    });
  }
}

class _RetainedMedia extends StatefulWidget {
  const _RetainedMedia({required this.onInit, super.key});
  final VoidCallback onInit;
  @override
  State<_RetainedMedia> createState() => _MediaState();
}

class _MediaState extends State<_RetainedMedia> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => const SizedBox(height: 80);
}
