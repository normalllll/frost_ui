import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/desktop.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/media.dart';

import 'support.dart';

FrostNavDestination _destination(String label, {int badge = 0, double? progress, Widget Function(BuildContext, Widget)? builder}) =>
    FrostNavDestination(icon: testIcons.add, label: label, badge: badge, progress: progress, builder: builder);

FrostShellTabs<Object> _tabs(FrostTabsController<Object> controller) => FrostShellTabs<Object>(
  controller: controller,
  label: (_, tab) => FrostTabLabel(title: '$tab'),
  countLabel: (count) => '$count tabs',
  closeTooltip: 'Close tab',
  newTabTooltip: 'New tab',
);

class _CaptionWindow extends ChangeNotifier implements FrostWindowActions {
  @override
  FrostCaptionState get captionState => const FrostCaptionState(maximized: false, active: true, maximizeHovered: false, maximizePressed: false, failed: false);
  @override
  void updateHitRegions(List<FrostHitRegion> regions) {}
  @override
  Future<void> minimize() async {}
  @override
  Future<void> toggleMaximized() async {}
  @override
  Future<void> close() async {}
  @override
  Future<void> retry() async {}
}

Widget _shell({
  List<FrostNavDestination>? destinations,
  int? selected = 0,
  FrostShellSecondary? secondary,
  FrostShellTabs<Object>? tabs,
  ValueChanged<int>? onSelected,
  bool canGoBack = false,
  VoidCallback? onBack,
  bool expanded = false,
  FrostWindowActions? window,
  TargetPlatform platform = TargetPlatform.windows,
}) => _withTouchTargets(
  FrostWindowCaptionScope(
    window: window,
    child: FrostShell(
      destinations: destinations ?? [_destination('Home'), _destination('Library')],
      selectedIndex: selected,
      secondary: secondary,
      tabs: tabs,
      atDestinationRoot: true,
      onDestinationSelected: onSelected ?? (_) {},
      canGoBack: canGoBack,
      onBack: onBack ?? () {},
      showsMobileNavigation: true,
      initiallyExpanded: expanded,
      child: const FrostShellDestination(child: SizedBox.expand()),
    ),
  ),
  platform: platform,
);

/// [frostTestApp] under the touch-target root, as `FrostApp` mounts it.
Widget _withTouchTargets(Widget child, {TargetPlatform platform = TargetPlatform.windows}) =>
    FrostInputFeedback(child: frostTestApp(child, platform: platform));

void _window(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Finder _navItem(String label) => find.byWidgetPredicate((widget) => widget is FrostNavItem && widget.label == label);

/// Puts a finger on record, on a point that does nothing.
Future<void> _useFinger(WidgetTester tester, Offset at) async {
  await tester.tapAt(at);
  await tester.pumpAndSettle();
}

class _Mounted extends StatefulWidget {
  const _Mounted(this.onMount, this.child);
  final VoidCallback onMount;
  final Widget child;
  @override
  State<_Mounted> createState() => _MountedState();
}

class _MountedState extends State<_Mounted> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Counts the frames its own repeating animation gets.
class _Ticking extends StatefulWidget {
  const _Ticking(this.onTick);
  final VoidCallback onTick;
  @override
  State<_Ticking> createState() => _TickingState();
}

class _TickingState extends State<_Ticking> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))
    ..addListener(widget.onTick)
    ..repeat();

  @override
  void initState() {
    super.initState();
    _controller;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox(width: 20, height: 20);
}

void main() {
  group('tabs', () {
    test('replaceAll with a tab already open does not report it removed', () {
      final removed = <String>[];
      final tabs = FrostTabsController<String>(initial: 'A', onRemoved: removed.add)
        ..open('B')
        ..open('C');
      tabs.replaceAll('B');
      expect(tabs.tabs, ['B']);
      expect(removed, ['A', 'C']);
      tabs.dispose();
      expect(removed, ['A', 'C', 'B']);
    });
  });

  group('shell destinations', () {
    testWidgets('no selected destination highlights nothing on the bottom bar', (tester) async {
      _window(tester, 390, 800);
      await tester.pumpWidget(_shell(selected: null, platform: TargetPlatform.android));
      await tester.pumpAndSettle();
      final highlighted = find.descendant(
        of: find.byType(FrostShell),
        matching: find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.selected == true),
      );
      expect(highlighted, findsNothing);
    });

    testWidgets('the collapsed sidebar announces and shows what its hidden destinations report', (tester) async {
      _window(tester, 1400, 800);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _shell(
          secondary: FrostShellSecondary(destinations: [_destination('Settings', badge: 5, progress: .4), _destination('About')], onSelected: (_) {}),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('L.more, L.navigationStatus(5,40)'), findsOneWidget);
      expect(find.descendant(of: _navItem('L.more'), matching: find.byType(FrostCountBadge)), findsOneWidget);
      await tester.tap(_navItem('L.more'));
      await tester.pumpAndSettle();
      expect(find.text('L.navigationStatus(5,40)'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('a secondary destination brings the base tab forward and takes the highlight only with it', (tester) async {
      _window(tester, 1400, 800);
      final tabs = FrostTabsController<Object>.withBaseTab(baseTab: 'Home')..open('Video');
      addTearDown(tabs.dispose);
      final picked = <int>[];
      Widget app(int? selected) => _shell(
        expanded: true,
        tabs: _tabs(tabs),
        secondary: FrostShellSecondary(destinations: [_destination('Settings'), _destination('About')], selectedIndex: selected, onSelected: picked.add),
      );
      await tester.pumpWidget(app(null));
      await tester.pumpAndSettle();
      expect(tabs.isBaseTabActive, isFalse);

      await tester.tap(_navItem('Settings'));
      await tester.pumpAndSettle();
      expect(tabs.isBaseTabActive, isTrue);
      expect(picked, [0]);

      // With a content tab in front the secondary destination is not current.
      await tester.pumpWidget(app(0));
      tabs.activate(1);
      await tester.pumpAndSettle();
      expect(tester.widget<FrostNavItem>(_navItem('Settings')).selected, isFalse);

      // Returning to the same destination keeps its stack: nothing is dispatched.
      await tester.tap(_navItem('Settings'));
      await tester.pumpAndSettle();
      expect(tabs.isBaseTabActive, isTrue);
      expect(picked, [0]);
      expect(tester.widget<FrostNavItem>(_navItem('Settings')).selected, isTrue);
    });

    testWidgets('edge fades coming and going keep the destinations and their focus', (tester) async {
      _window(tester, 1600, 300);
      var mounts = 0;
      await tester.pumpWidget(
        _shell(destinations: [for (var index = 0; index < 8; index++) _destination('D$index', builder: (_, child) => _Mounted(() => mounts++, child))]),
      );
      await tester.pumpAndSettle();
      final mounted = mounts;
      for (var i = 0; i < 14 && FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<_Mounted>() == null; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      }
      final focused = FocusManager.instance.primaryFocus;
      expect(focused?.context?.findAncestorWidgetOfExactType<_Mounted>(), isNotNull);
      tester.view.physicalSize = const Size(1600, 1200);
      await tester.pumpAndSettle();
      final grown = mounts;
      expect(grown, greaterThanOrEqualTo(mounted));
      expect(identical(FocusManager.instance.primaryFocus, focused), isTrue);
      tester.view.physicalSize = const Size(1600, 300);
      await tester.pumpAndSettle();
      expect(mounts, grown);
      expect(identical(FocusManager.instance.primaryFocus, focused), isTrue);
    });
  });

  group('touch targets', () {
    testWidgets('a finger just outside a collapsed destination selects it', (tester) async {
      _window(tester, 1200, 800);
      final picked = <int>[];
      await tester.pumpWidget(_shell(selected: 1, onSelected: picked.add, platform: TargetPlatform.android));
      await tester.pumpAndSettle();
      await _useFinger(tester, const Offset(600, 400));
      final tile = tester.getRect(find.descendant(of: _navItem('Home'), matching: find.byType(FrostClickSurface)).first);
      expect(tile.size, const Size(40, 40));
      await tester.tapAt(Offset(tile.center.dx, tile.bottom + 1));
      await tester.pumpAndSettle();
      expect(picked, [0]);
      await tester.tapAt(Offset(tile.left - 1, tile.center.dy));
      await tester.pumpAndSettle();
      expect(picked, [0, 0]);
    });

    for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
      testWidgets('a finger just below the caption back button goes back (${platform.name})', (tester) async {
        _window(tester, 1200, 800);
        final window = _CaptionWindow();
        addTearDown(window.dispose);
        var backs = 0;
        await tester.pumpWidget(_shell(window: window, canGoBack: true, onBack: () => backs++, platform: platform));
        await tester.pumpAndSettle();
        await _useFinger(tester, const Offset(600, 400));
        final back = tester.getRect(find.byKey(const ValueKey('frost-shell-back')));
        expect(back.height, 40);
        await tester.tapAt(Offset(back.center.dx, back.bottom + 1));
        await tester.pumpAndSettle();
        expect(backs, 1);
      });
    }

    for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
      testWidgets('a drag starting inside the split handle\'s touch band moves it (${platform.name})', (tester) async {
        _window(tester, 1400, 900);
        final committed = <double>[];
        await tester.pumpWidget(
          _withTouchTargets(
            FrostSplitView(primary: const SizedBox.expand(), secondary: const SizedBox.expand(), onCloseSecondary: () {}, onPrimaryWidthChanged: committed.add),
            platform: platform,
          ),
        );
        await tester.pumpAndSettle();
        await _useFinger(tester, const Offset(1000, 400));
        final handle = find.descendant(
          of: find.byType(FrostSplitView),
          matching: find.byWidgetPredicate((widget) => widget is MouseRegion && widget.cursor == SystemMouseCursors.resizeLeftRight),
        );
        final rect = tester.getRect(handle);
        expect(rect.width, 8);
        final gesture = await tester.startGesture(Offset(rect.right + 16, rect.center.dy));
        await tester.pump();
        await gesture.moveBy(const Offset(30, 0));
        await tester.pump();
        await gesture.moveBy(const Offset(30, 0));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.getRect(handle).center.dx, greaterThan(rect.center.dx + 30));
        expect(committed, hasLength(1));
      });
    }

    testWidgets('the gap below a navigation column row belongs to it', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        frostTestApp(
          Center(
            child: FrostNavigationColumnRow(title: 'Row', onPressed: () => taps++),
          ),
          platform: TargetPlatform.android,
        ),
      );
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byType(FrostNavigationColumnRow));
      await tester.tapAt(Offset(rect.center.dx, rect.bottom - 1));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  });

  group('pager', () {
    Widget pager(FrostPagerController controller) => frostTestApp(
      SizedBox(
        width: 600,
        height: 400,
        child: FrostPager(
          controller: controller,
          itemCount: 6,
          showsIndicator: false,
          itemBuilder: (_, index) => Center(child: Text('page $index')),
        ),
      ),
    );

    testWidgets('clicking the next arrow twice before the page turns moves two pages', (tester) async {
      _window(tester, 800, 600);
      final controller = FrostPagerController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(pager(controller));
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(find.byType(FrostPager)));
      addTearDown(mouse.removePointer);
      await tester.pumpAndSettle();
      final next = find.byWidgetPredicate((widget) => widget is FrostButton && widget.label == 'L.next');
      final at = tester.getCenter(next.last);
      await mouse.moveTo(at);
      await tester.pump();
      await mouse.down(at);
      await mouse.up();
      await tester.pump(const Duration(milliseconds: 48));
      expect(controller.page, 0, reason: 'the first click has not passed the middle yet');
      await mouse.down(at);
      await mouse.up();
      await tester.pumpAndSettle();
      expect(controller.page, 2);
    });

    testWidgets('a finger that stops a move and stays on the page cancels where it was going', (tester) async {
      _window(tester, 800, 600);
      final controller = FrostPagerController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(pager(controller));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 32));
      final gesture = await tester.startGesture(tester.getCenter(find.byType(FrostPager)));
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.page, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(controller.page, 1);
    });
  });

  group('hidden subtrees', () {
    testWidgets('FrostLazyIndexedStack stops the hidden child\'s animations and resumes them', (tester) async {
      var ticks = 0;
      late BuildContext first;
      Widget app(int index) => frostTestApp(
        FrostLazyIndexedStack(
          index: index,
          children: [
            Builder(
              builder: (context) {
                first = context;
                return _Ticking(() => ticks++);
              },
            ),
            const SizedBox(),
          ],
        ),
      );
      await tester.pumpWidget(app(0));
      await tester.pump(const Duration(milliseconds: 16));
      expect(ticks, greaterThan(0));
      expect(TickerMode.valuesOf(first).enabled, isTrue);
      await tester.pumpWidget(app(1));
      final hidden = ticks;
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(ticks, hidden);
      await tester.pumpWidget(app(0));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(ticks, greaterThan(hidden));
    });

    testWidgets('FrostSpringReveal takes no taps while hiding and works again once shown', (tester) async {
      var taps = 0;
      late BuildContext inside;
      Widget app(bool shown) => frostTestApp(
        Center(
          child: FrostSpringReveal(
            shown: shown,
            child: Builder(
              builder: (context) {
                inside = context;
                return FrostButton(label: 'Press', onPressed: () => taps++);
              },
            ),
          ),
        ),
      );
      await tester.pumpWidget(app(true));
      await tester.pumpAndSettle();
      final where = tester.getCenter(find.text('Press'));
      await tester.pumpWidget(app(false));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.tapAt(where);
      await tester.pump();
      expect(taps, 0);
      await tester.pumpAndSettle();
      expect(TickerMode.valuesOf(inside).enabled, isFalse);
      await tester.pumpWidget(app(true));
      await tester.pumpAndSettle();
      expect(TickerMode.valuesOf(inside).enabled, isTrue);
      await tester.tapAt(where);
      await tester.pump(const Duration(milliseconds: 400));
      expect(taps, 1);
    });

    testWidgets('FrostInspector pauses a closed panel, finishes closing and resumes on reopening', (tester) async {
      _window(tester, 1400, 800);
      late BuildContext inside;
      Widget app(bool open) => frostTestApp(
        FrostInspector(
          open: open,
          onOpenChanged: (_) {},
          inspector: Builder(
            builder: (context) {
              inside = context;
              return const Text('Panel');
            },
          ),
          child: const SizedBox.expand(),
        ),
      );
      await tester.pumpWidget(app(true));
      await tester.pumpAndSettle();
      expect(TickerMode.valuesOf(inside).enabled, isTrue);
      await tester.pumpWidget(app(false));
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
      expect(TickerMode.valuesOf(inside).enabled, isFalse);
      await tester.pumpWidget(app(true));
      await tester.pumpAndSettle();
      expect(TickerMode.valuesOf(inside).enabled, isTrue);
    });
  });

  group('section tab indicator', () {
    const labels = ['One', 'Two', 'Three', 'Four'];

    Widget sections({TargetPlatform platform = TargetPlatform.windows, int count = 2}) => frostTestApp(
      DefaultTabController(
        length: count,
        child: FrostBrowseLayout.sectioned(
          header: const FrostPageHeader(),
          sections: FrostHeaderSections(
            tabs: FrostTabBar(tabs: [for (final label in labels.take(count)) FrostTab(label: label)]),
          ),
          sectionBuilder: (context, section) => FrostBrowseSection(
            slivers: [SliverList.builder(itemCount: 60, itemBuilder: (_, row) => SizedBox(height: 40, child: Text('S$section row $row')))],
          ),
        ),
      ),
      platform: platform,
    );

    TabController controller(WidgetTester tester) => DefaultTabController.of(tester.element(find.byType(FrostTabBar)));

    double indicator(WidgetTester tester) {
      final paint = tester.widget<CustomPaint>(find.descendant(of: find.byType(FrostTabBar), matching: find.byType(CustomPaint)).first);
      return ((paint.foregroundPainter! as dynamic).progress as Animation<double>).value;
    }

    /// Advances frame by frame until everything rests, and checks that both
    /// values only ever head for [target] and rest there once they arrive.
    Future<void> expectSteadyArrival(WidgetTester tester, double target) async {
      final tabs = controller(tester);
      final value = tabs.animation!.value, shown = indicator(tester);
      final direction = (target - value).sign == 0 ? (target - shown).sign : (target - value).sign;
      var lastValue = value, lastShown = shown;
      for (var frame = 0; frame < 120; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        final nextValue = tabs.animation!.value, nextShown = indicator(tester);
        expect(
          (nextValue - lastValue) * direction,
          greaterThanOrEqualTo(-1e-9),
          reason: 'tabs.animation stepped back on frame $frame: $lastValue to $nextValue',
        );
        expect(
          (nextShown - lastShown) * direction,
          greaterThanOrEqualTo(-1e-9),
          reason: 'the indicator stepped back on frame $frame: $lastShown to $nextShown',
        );
        lastValue = nextValue;
        lastShown = nextShown;
      }
      expect(lastValue, target);
      expect(lastShown, target);
      expect(tester.hasRunningAnimations, isFalse);
    }

    Future<void> pumpSections(WidgetTester tester, {int count = 2, TargetPlatform platform = TargetPlatform.windows}) async {
      _window(tester, 1400, 900);
      await tester.pumpWidget(sections(count: count, platform: platform));
      await tester.pumpAndSettle();
    }

    testWidgets('a tapped tab arrives in one direction and stays, there and back', (tester) async {
      await pumpSections(tester);
      await tester.tap(find.text('Two'));
      await expectSteadyArrival(tester, 1);
      await tester.tap(find.text('One'));
      await expectSteadyArrival(tester, 0);
    });

    testWidgets('a tab further away arrives in one direction and stays', (tester) async {
      await pumpSections(tester, count: 4);
      await tester.tap(find.text('Four'));
      await expectSteadyArrival(tester, 3);
      expect(controller(tester).index, 3);
    });

    testWidgets('quick tabs in a row arrive in one direction and stay', (tester) async {
      await pumpSections(tester, count: 4);
      await tester.tap(find.text('Two'));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(find.text('Three'));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(find.text('Four'));
      await expectSteadyArrival(tester, 3);
      expect(controller(tester).index, 3);
    });

    testWidgets('a selection made in code moves the indicator in one direction', (tester) async {
      await pumpSections(tester);
      controller(tester).animateTo(1);
      await expectSteadyArrival(tester, 1);
    });

    testWidgets('a touch drag keeps the indicator on the finger and settles on release', (tester) async {
      await pumpSections(tester, platform: TargetPlatform.android);
      final tabs = controller(tester);
      final pages = tester.getRect(find.byType(PageView));
      final gesture = await tester.startGesture(pages.center);
      await tester.pump();
      await gesture.moveBy(const Offset(-20, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-200, 0));
      await tester.pump();
      final first = tabs.offset;
      expect(first, greaterThan(0));
      expect(indicator(tester), closeTo(first, 1e-6));
      await gesture.moveBy(const Offset(-200, 0));
      await tester.pump();
      expect(tabs.offset, greaterThan(first));
      expect(indicator(tester), closeTo(tabs.offset, 1e-6));
      await gesture.moveBy(const Offset(-400, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tabs.index, 1);
      expect(tabs.offset, 0);
      expect(indicator(tester), 1);
    });

    testWidgets('a finger takes over from a slide under way', (tester) async {
      await pumpSections(tester, platform: TargetPlatform.android);
      final tabs = controller(tester);
      await tester.tap(find.text('Two'));
      await tester.pump(const Duration(milliseconds: 64));
      final gesture = await tester.startGesture(tester.getRect(find.byType(PageView)).center);
      await tester.pump();
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-1000, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tabs.index, 1);
      expect(tabs.offset, 0);
    });
  });
}
