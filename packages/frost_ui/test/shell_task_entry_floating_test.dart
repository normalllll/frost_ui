import 'package:flutter/gestures.dart' show HitTestResult;
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

final destinations = [
  FrostNavDestination(icon: testIcons.image, label: 'Home'),
  FrostNavDestination(icon: testIcons.search, label: 'Library'),
  FrostNavDestination(icon: testIcons.more, label: 'Account'),
];

const topInset = 47.0;
const bottomInset = 34.0;

final navigatorKey = GlobalKey<NavigatorState>();

Widget shell({
  bool visible = true,
  VoidCallback? onPressed,
  ValueChanged<FrostFloatingEntryPosition>? onMoved,
  FrostFloatingEntryPosition initial = const FrostFloatingEntryPosition(),
  bool withEntry = true,
  Widget page = const SizedBox.expand(),
  Widget Function(BuildContext context)? entryBuilder,
}) => FrostShell(
  destinations: destinations,
  selectedIndex: 0,
  atDestinationRoot: true,
  onDestinationSelected: (_) {},
  canGoBack: false,
  onBack: () {},
  showsMobileNavigation: true,
  taskEntry: !withEntry
      ? null
      : FrostShellTaskEntry(
          visible: visible,
          initialFloatingPosition: initial,
          onFloatingPositionChanged: onMoved,
          builder: (context, placement) =>
              entryBuilder?.call(context) ??
              FrostShellTaskButton(icon: testIcons.image, label: 'Downloads', badge: 2, progress: .5, onPressed: onPressed ?? () {}),
        ),
  child: Navigator(
    key: navigatorKey,
    onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => FrostShellDestination(child: page)),
  ),
);

void phone(WidgetTester tester, [Size size = const Size(390, 844)]) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: topInset, bottom: bottomInset);
  addTearDown(tester.view.reset);
}

Finder get button => find.byType(FrostShellTaskButton);
Finder get bar => find.byWidgetPredicate((w) => w is FrostSurface && w.role == FrostSurfaceRole.chrome);
Finder get layer => find.byKey(const ValueKey('frost-shell-floating-task'));

double opacityOf(WidgetTester tester) => tester.widget<AnimatedOpacity>(find.ancestor(of: button, matching: find.byType(AnimatedOpacity)).first).opacity;

void main() {
  testWidgets('floating entry stays clear of the bar and the header area', (tester) async {
    phone(tester);
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(frostTestApp(shell(onPressed: () => taps++), platform: TargetPlatform.android));
    await tester.pumpAndSettle();
    expect(bar, findsOneWidget);
    final rect = tester.getRect(button);
    final barRect = tester.getRect(bar);
    expect(rect.size, const Size(48, 48));
    expect(rect.bottom, lessThanOrEqualTo(barRect.top));
    expect(rect.top, greaterThanOrEqualTo(topInset + FrostPageHeader.verticalHeight));
    expect(rect.right, 390 - 16, reason: 'the default rests on the end edge');
    expect(barRect.bottom, 844);
    expect(find.semantics.byLabel(RegExp('^Downloads')), findsOne);
    await tester.tap(button);
    expect(taps, 1);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('floating entry stays above a pushed route that covers the bar', (tester) async {
    phone(tester);
    var taps = 0;
    await tester.pumpWidget(frostTestApp(shell(onPressed: () => taps++), platform: TargetPlatform.android));
    await tester.pumpAndSettle();
    final before = tester.getRect(button);
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const ColoredBox(color: Colors.black, child: SizedBox.expand()),
      ),
    );
    await tester.pumpAndSettle();
    expect(bar, findsNothing);
    expect(tester.getRect(button), before);
    await tester.tap(button);
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a drag snaps the entry to the nearer edge and reports where', (tester) async {
    phone(tester);
    final moved = <FrostFloatingEntryPosition>[];
    var taps = 0;
    await tester.pumpWidget(
      frostTestApp(
        shell(onMoved: moved.add, onPressed: () => taps++),
        platform: TargetPlatform.android,
      ),
    );
    await tester.pumpAndSettle();
    final start = tester.getRect(button);
    await tester.drag(button, const Offset(-260, -300));
    await tester.pumpAndSettle();
    expect(taps, 0, reason: 'a drag is not a tap');
    expect(moved, hasLength(1));
    expect(moved.single.edge, FrostFloatingEntryEdge.start);
    expect(moved.single.fraction, inExclusiveRange(0, 1));
    final rect = tester.getRect(button);
    expect(rect.left, 16);
    expect(rect.top, moreOrLessEquals(start.top - 300, epsilon: 1));
    // A small drag back toward the start edge stays there.
    await tester.drag(button, const Offset(80, 0));
    await tester.pumpAndSettle();
    expect(tester.getRect(button).left, 16);
    expect(moved.last.edge, FrostFloatingEntryEdge.start);
    // Dragged past the top, it clamps into the band.
    await tester.drag(button, const Offset(300, -800));
    await tester.pumpAndSettle();
    expect(moved.last, const FrostFloatingEntryPosition(edge: FrostFloatingEntryEdge.end, fraction: 0));
    expect(tester.getRect(button).top, topInset + FrostPageHeader.verticalHeight + 16);
    expect(tester.getRect(button).right, 390 - 16);
    await tester.tap(button);
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('floating entry hides while the keyboard is up', (tester) async {
    phone(tester);
    var taps = 0;
    await tester.pumpWidget(frostTestApp(shell(onPressed: () => taps++), platform: TargetPlatform.android));
    await tester.pumpAndSettle();
    expect(opacityOf(tester), 1);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(opacityOf(tester), 0);
    await tester.tap(button, warnIfMissed: false);
    expect(taps, 0);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(opacityOf(tester), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('floating entry clears a bar grown by 2x text', (tester) async {
    phone(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(frostTestApp(shell(), platform: TargetPlatform.android));
    await tester.pumpAndSettle();
    final barRect = tester.getRect(bar);
    expect(barRect.height, greaterThan(64 + bottomInset));
    expect(tester.getRect(button).bottom, lessThanOrEqualTo(barRect.top));
    navigatorKey.currentState!.push(MaterialPageRoute<void>(builder: (_) => const SizedBox.expand()));
    await tester.pumpAndSettle();
    expect(tester.getRect(button).bottom, lessThanOrEqualTo(barRect.top), reason: 'a covered bar keeps its measured height');
    expect(tester.takeException(), isNull);
  });

  testWidgets('floating entry is hidden when not visible', (tester) async {
    phone(tester);
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(frostTestApp(shell(visible: false, onPressed: () => taps++), platform: TargetPlatform.android));
    await tester.pumpAndSettle();
    expect(opacityOf(tester), 0);
    expect(find.semantics.byLabel(RegExp('^Downloads')), findsNothing);
    await tester.tap(button, warnIfMissed: false);
    expect(taps, 0);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('floating entry is absent in sidebar mode', (tester) async {
    phone(tester, const Size(1366, 1024));
    await tester.pumpWidget(frostTestApp(shell(), platform: TargetPlatform.android));
    await tester.pumpAndSettle();
    expect(layer, findsNothing);
    expect(button, findsOneWidget, reason: 'the sidebar slot shows it instead');
    expect(find.ancestor(of: button, matching: find.byType(FrostNavItem)), findsNothing);
    expect(find.descendant(of: button, matching: find.byType(FrostNavItem)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a wider entry keeps its own size inside the margins', (tester) async {
    phone(tester);
    const wide = ValueKey('wide-entry');
    final moved = <FrostFloatingEntryPosition>[];
    await tester.pumpWidget(
      frostTestApp(
        shell(
          onMoved: moved.add,
          entryBuilder: (context) => const SizedBox(
            key: wide,
            width: 120,
            height: 56,
            child: ColoredBox(color: Colors.blue),
          ),
        ),
        platform: TargetPlatform.android,
      ),
    );
    await tester.pumpAndSettle();
    final barTop = tester.getRect(bar).top;
    var rect = tester.getRect(find.byKey(wide));
    expect(rect.size, const Size(120, 56));
    expect(rect.right, 390 - 16);
    expect(rect.bottom, barTop - 16);
    await tester.drag(find.byKey(wide), const Offset(-500, -2000));
    await tester.pumpAndSettle();
    rect = tester.getRect(find.byKey(wide));
    expect(rect.left, 16);
    expect(rect.top, topInset + FrostPageHeader.verticalHeight + 16);
    expect(moved.last, const FrostFloatingEntryPosition(edge: FrostFloatingEntryEdge.start, fraction: 0));
    await tester.drag(find.byKey(wide), const Offset(500, 2000));
    await tester.pumpAndSettle();
    rect = tester.getRect(find.byKey(wide));
    expect(rect.right, 390 - 16);
    expect(rect.bottom, barTop - 16);
    expect(moved.last, const FrostFloatingEntryPosition());
    expect(tester.takeException(), isNull);
  });

  testWidgets('hiding the entry mid-drag cancels the drag', (tester) async {
    phone(tester);
    final moved = <FrostFloatingEntryPosition>[];
    await tester.pumpWidget(frostTestApp(shell(onMoved: moved.add), platform: TargetPlatform.android));
    await tester.pumpAndSettle();
    final rest = tester.getRect(button);
    final gesture = await tester.startGesture(rest.center);
    await gesture.moveBy(const Offset(-200, -200));
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    await gesture.moveBy(const Offset(-20, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(moved, isEmpty);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(tester.getRect(button), rest);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a sheet opened from the entry hides it until the sheet closes', (tester) async {
    phone(tester);
    var taps = 0;
    await tester.pumpWidget(
      frostTestApp(
        shell(
          entryBuilder: (context) => FrostShellTaskButton(
            icon: testIcons.image,
            label: 'Downloads',
            onPressed: () {
              taps++;
              showFrostSheet<void>(context: context, builder: (_) => const Text('Download panel'));
            },
          ),
        ),
        platform: TargetPlatform.android,
      ),
    );
    await tester.pumpAndSettle();
    final rest = tester.getRect(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Download panel'), findsOneWidget);
    expect(opacityOf(tester), 0);
    await tester.tapAt(rest.center);
    expect(taps, 1, reason: 'the hidden entry takes no taps');
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    expect(find.text('Download panel'), findsNothing);
    expect(opacityOf(tester), 1);
    await tester.tap(button);
    expect(taps, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a popup route in the content Navigator hides the entry', (tester) async {
    phone(tester);
    await tester.pumpWidget(frostTestApp(shell(), platform: TargetPlatform.android));
    await tester.pumpAndSettle();
    expect(opacityOf(tester), 1);
    navigatorKey.currentState!.push(RawDialogRoute<void>(pageBuilder: (_, _, _) => const Center(child: Text('Dialog body'))));
    await tester.pumpAndSettle();
    expect(opacityOf(tester), 0);
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(opacityOf(tester), 1);
    // A detail page keeps the entry; a dialog above it hides it again.
    navigatorKey.currentState!.push(MaterialPageRoute<void>(builder: (_) => const SizedBox.expand()));
    await tester.pumpAndSettle();
    expect(opacityOf(tester), 1);
    navigatorKey.currentState!.push(RawDialogRoute<void>(pageBuilder: (_, _, _) => const Center(child: Text('Dialog body'))));
    await tester.pumpAndSettle();
    expect(opacityOf(tester), 0);
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(opacityOf(tester), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('content toasts paint above the entry', (tester) async {
    phone(tester);
    const wide = ValueKey('wide-entry');
    await tester.pumpWidget(
      frostTestApp(
        shell(
          entryBuilder: (context) => const SizedBox(
            key: wide,
            width: 358,
            height: 48,
            child: ColoredBox(color: Colors.blue),
          ),
        ),
        platform: TargetPlatform.android,
      ),
    );
    await tester.pumpAndSettle();
    FrostToast.info('Saved');
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);
    final toast = tester.renderObject(find.text('Saved'));
    final entry = tester.renderObject(find.byKey(wide));
    // The entry spans the band, so the toast sits over it.
    expect(tester.getRect(find.byKey(wide)).contains(tester.getRect(find.text('Saved')).center), isTrue);
    final overlap = tester.getRect(find.text('Saved')).center;
    final result = HitTestResult();
    tester.binding.hitTestInView(result, overlap, tester.view.viewId);
    final targets = result.path.map((entry) => entry.target).toList();
    expect(targets, contains(toast));
    bool isEntry(Object target) => target is RenderObject && (target == entry || _isDescendant(target, entry));
    final firstEntry = targets.indexWhere(isEntry);
    expect(firstEntry == -1 || firstEntry > targets.indexOf(toast), isTrue, reason: 'the toast is hit first or alone');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the entry shows only once the bar height is known', (tester) async {
    phone(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    double readiness() => tester.widget<Opacity>(find.byKey(const ValueKey('frost-shell-floating-ready'))).opacity;
    await tester.pumpWidget(frostTestApp(shell(), platform: TargetPlatform.android));
    expect(readiness(), 0, reason: 'the first frame has no measured band');
    await tester.pump();
    expect(readiness(), 1);
    final first = tester.getRect(button);
    await tester.pumpAndSettle();
    expect(tester.getRect(button), first, reason: 'no jump once shown');
    expect(first.bottom, lessThanOrEqualTo(tester.getRect(bar).top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('without a bar the entry falls back to the minimum bar height', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      frostTestApp(
        FrostShell(
          destinations: destinations,
          selectedIndex: 0,
          atDestinationRoot: true,
          onDestinationSelected: (_) {},
          canGoBack: false,
          onBack: () {},
          showsMobileNavigation: true,
          taskEntry: FrostShellTaskEntry(
            builder: (context, placement) => FrostShellTaskButton(icon: testIcons.image, label: 'Downloads', onPressed: () {}),
          ),
          child: const SizedBox.expand(),
        ),
        platform: TargetPlatform.android,
      ),
    );
    await tester.pumpAndSettle();
    expect(bar, findsNothing);
    expect(tester.widget<Opacity>(find.byKey(const ValueKey('frost-shell-floating-ready'))).opacity, 1);
    expect(tester.getRect(button).bottom, 844 - bottomInset - 64 - 16);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edges follow reading direction', (tester) async {
    phone(tester);
    final moved = <FrostFloatingEntryPosition>[];
    await tester.pumpWidget(
      frostTestApp(
        Directionality(
          textDirection: TextDirection.rtl,
          child: shell(onMoved: moved.add),
        ),
        platform: TargetPlatform.android,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(button).left, 16, reason: 'the end edge is on the left in RTL');
    await tester.drag(button, const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(tester.getRect(button).right, 390 - 16);
    expect(moved.single.edge, FrostFloatingEntryEdge.start);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with reduced motion the entry lands without a snap animation', (tester) async {
    phone(tester);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(frostTestApp(shell(), platform: TargetPlatform.android));
    await tester.pumpAndSettle();
    await tester.drag(button, const Offset(-250, -100));
    await tester.pump();
    expect(tester.getRect(button).left, 16);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a drag that ends where it started reports nothing', (tester) async {
    phone(tester);
    final moved = <FrostFloatingEntryPosition>[];
    await tester.pumpWidget(frostTestApp(shell(onMoved: moved.add), platform: TargetPlatform.android));
    await tester.pumpAndSettle();
    final rest = tester.getRect(button);
    // Right and down from the bottom end corner clamp back to it.
    await tester.drag(button, const Offset(40, 80));
    await tester.pumpAndSettle();
    expect(tester.getRect(button), rest);
    expect(moved, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the position survives a rebuild, a safe-area change and a layout switch', (tester) async {
    phone(tester);
    final moved = <FrostFloatingEntryPosition>[];
    Widget app() => frostTestApp(shell(onMoved: moved.add), platform: TargetPlatform.android);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.drag(button, const Offset(-250, -200));
    await tester.pumpAndSettle();
    final position = moved.single;
    final dragged = tester.getRect(button);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(tester.getRect(button), dragged);
    tester.view.padding = const FakeViewPadding(top: 60, bottom: 20);
    await tester.pumpAndSettle();
    final barTop = tester.getRect(bar).top;
    final top = 60 + FrostPageHeader.verticalHeight + 16;
    final bottom = barTop - 16 - 48;
    final movedRect = tester.getRect(button);
    expect(movedRect.left, 16);
    expect(movedRect.top, moreOrLessEquals(top + position.fraction * (bottom - top), epsilon: .01));
    tester.view.physicalSize = const Size(1366, 1024);
    await tester.pumpAndSettle();
    expect(layer, findsNothing);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(tester.getRect(button), movedRect);
    expect(moved, [position], reason: 'nothing but the drag reports');
    expect(tester.takeException(), isNull);
  });

  testWidgets('with the keyboard up a tap where the entry was reaches the page', (tester) async {
    phone(tester);
    var pageTaps = 0;
    var entryTaps = 0;
    await tester.pumpWidget(
      frostTestApp(
        shell(
          onPressed: () => entryTaps++,
          page: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => pageTaps++, child: const SizedBox.expand()),
        ),
        platform: TargetPlatform.android,
      ),
    );
    await tester.pumpAndSettle();
    final rest = tester.getRect(button);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    await tester.tapAt(rest.center);
    expect(pageTaps, 1);
    expect(entryTaps, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('toggling the entry keeps the bar items mounted', (tester) async {
    phone(tester);
    List<State> barStates() => tester.stateList<State>(find.descendant(of: bar, matching: find.byType(FrostClickSurface))).toList();
    await tester.pumpWidget(frostTestApp(shell(withEntry: false), platform: TargetPlatform.android));
    await tester.pumpAndSettle();
    final states = barStates();
    expect(states, hasLength(destinations.length));
    for (final next in [shell(), shell(visible: false), shell(), shell(withEntry: false)]) {
      await tester.pumpWidget(frostTestApp(next, platform: TargetPlatform.android));
      await tester.pumpAndSettle();
      final now = barStates();
      for (var index = 0; index < states.length; index++) {
        expect(now[index], same(states[index]));
      }
    }
    expect(tester.takeException(), isNull);
  });
}

bool _isDescendant(RenderObject node, RenderObject ancestor) {
  for (RenderObject? parent = node.parent; parent != null; parent = parent.parent) {
    if (parent == ancestor) return true;
  }
  return false;
}
