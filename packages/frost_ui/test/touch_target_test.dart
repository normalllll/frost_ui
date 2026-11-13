import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/foundation/_touch_targets.dart';
import 'package:material_ui/material_ui.dart';

import 'app_router_test.dart' show TestRouter;
import 'support.dart';

const _settle = Duration(milliseconds: 400);

/// Hosts [home] the way `FrostApp` does: the touch-target root sits above the
/// Navigator, so every route is under it.
Widget _app(Widget home) => FrostScope(
  config: testConfig,
  child: MaterialApp(
    theme: FrostTheme.build(config: testConfig, brightness: Brightness.light, platform: TargetPlatform.windows, locale: const Locale('en')),
    builder: (context, child) => FrostInputFeedback(child: child!),
    home: home,
  ),
);

Widget _small(VoidCallback? onPressed) => FrostButton.icon(icon: testIcons.add, label: 'Add', size: FrostControlSize.small, onPressed: onPressed);

/// Puts a finger on record, away from every control.
Future<void> _useFinger(WidgetTester tester) async {
  await tester.tapAt(const Offset(2, 2));
  await tester.pump(_settle);
}

Rect _plate(WidgetTester tester, [Finder? within]) =>
    tester.getRect(find.descendant(of: within ?? find.byType(FrostButton), matching: find.byType(FrostClickSurface)).first);

Offset _below(Rect rect) => Offset(rect.center.dx, rect.bottom + 2);

void main() {
  testWidgets('a touch just outside a button on empty space reaches the button', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(Center(child: _small(() => taps++))));
    await _useFinger(tester);
    await tester.tapAt(_below(tester.getRect(find.byType(FrostButton))));
    await tester.pump(_settle);
    expect(taps, 1);
  });

  testWidgets('a touch on a dismissible barrier beside a button in the route closes the route', (tester) async {
    var taps = 0;
    late BuildContext source;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            source = context;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    await _useFinger(tester);
    showGeneralDialog<void>(
      context: source,
      barrierDismissible: true,
      barrierLabel: 'Close',
      transitionDuration: Duration.zero,
      pageBuilder: (_, _, _) => Center(child: _small(() => taps++)),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(_below(tester.getRect(find.byType(FrostButton))));
    await tester.pumpAndSettle();
    expect(taps, 0);
    expect(find.byType(FrostButton), findsNothing);
  });

  testWidgets('a mouse near a button keeps the visual size', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(Center(child: _small(() => taps++))));
    await tester.tapAt(_below(tester.getRect(find.byType(FrostButton))), kind: PointerDeviceKind.mouse);
    await tester.pump(_settle);
    expect(taps, 0);
  });

  Widget column(List<Widget> children) => Center(
    child: SizedBox(
      width: 200,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    ),
  );

  testWidgets('an adjacent app row keeps its own touch', (tester) async {
    var button = 0, row = 0;
    await tester.pumpWidget(
      _app(
        column([_small(() => button++), GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => row++, child: const SizedBox(width: 200, height: 40))]),
      ),
    );
    await _useFinger(tester);
    await tester.tapAt(_below(tester.getRect(find.byType(FrostButton))));
    await tester.pump(_settle);
    expect((button, row), (0, 1));
  });

  testWidgets('an adjacent text field still takes focus', (tester) async {
    var button = 0;
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(_app(column([_small(() => button++), Material(child: TextField(focusNode: focus))])));
    await _useFinger(tester);
    await tester.tapAt(_below(tester.getRect(find.byType(FrostButton))));
    await tester.pump(_settle);
    expect(button, 0);
    expect(focus.hasFocus, isTrue);
  });

  testWidgets('a disabled button does not take its neighbour\'s touch', (tester) async {
    var row = 0;
    await tester.pumpWidget(
      _app(column([_small(null), GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => row++, child: const SizedBox(width: 200, height: 40))])),
    );
    await _useFinger(tester);
    await tester.tapAt(_below(tester.getRect(find.byType(FrostButton))));
    await tester.pump(_settle);
    expect(row, 1);
  });

  testWidgets('a disabled button does not make an enabled neighbour\'s edge dead', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(
        Center(
          child: Row(mainAxisSize: MainAxisSize.min, spacing: 8, children: [_small(null), _small(() => taps++)]),
        ),
      ),
    );
    await _useFinger(tester);
    final enabled = _plate(tester, find.byType(FrostButton).last);
    await tester.tapAt(_below(enabled));
    await tester.pump(_settle);
    expect(taps, 1);
  });

  testWidgets('a list drag that starts just outside a button scrolls the list', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            _small(() {}),
            Expanded(
              child: ListView(controller: controller, children: const [SizedBox(height: 3000)]),
            ),
          ],
        ),
      ),
    );
    await _useFinger(tester);
    final gesture = await tester.startGesture(_below(tester.getRect(find.byType(FrostButton))));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(0, -30));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump(_settle);
    expect(controller.position.pixels, greaterThan(100));
  });

  testWidgets('a button inside a list still gets its target, and the list still drags from it', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(
        ListView(
          children: [
            Center(child: _small(() => taps++)),
            const SizedBox(height: 3000),
          ],
        ),
      ),
    );
    await _useFinger(tester);
    await tester.tapAt(_below(_plate(tester)));
    await tester.pump(_settle);
    expect(taps, 1);
  });

  for (final opaque in [false, true]) {
    testWidgets('a button on a covered route does not take the touch (opaque cover: $opaque)', (tester) async {
      var page = 0, top = 0, bottom = 0;
      late BuildContext source;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) {
              source = context;
              return Center(child: _small(() => page++));
            },
          ),
        ),
      );
      await _useFinger(tester);
      final rect = tester.getRect(find.byType(FrostButton));
      Navigator.of(source).push(
        PageRouteBuilder<void>(
          opaque: opaque,
          transitionDuration: Duration.zero,
          pageBuilder: (_, _, _) => Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: rect.bottom,
                child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => top++),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: rect.bottom,
                bottom: 0,
                child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => bottom++),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(_below(rect));
      await tester.pump(_settle);
      expect((page, top, bottom), (0, 0, 1));
    });
  }

  testWidgets('a button on a route below a transparent cover that takes no touches does not answer', (tester) async {
    var page = 0;
    late BuildContext source;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            source = context;
            return Center(child: _small(() => page++));
          },
        ),
      ),
    );
    await _useFinger(tester);
    final rect = _plate(tester);
    Navigator.of(source).push(
      PageRouteBuilder<void>(
        opaque: false,
        transitionDuration: Duration.zero,
        pageBuilder: (_, _, _) => const IgnorePointer(child: SizedBox.expand()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(_below(rect));
    await tester.pump(_settle);
    expect(page, 0);
  });

  testWidgets('between two buttons the nearer one takes the touch', (tester) async {
    var first = 0, second = 0;
    await tester.pumpWidget(
      _app(
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, spacing: 6, children: [_small(() => first++), _small(() => second++)]),
        ),
      ),
    );
    await _useFinger(tester);
    final upper = _plate(tester, find.byType(FrostButton).first), lower = _plate(tester, find.byType(FrostButton).last);
    await tester.tapAt(Offset(upper.center.dx, upper.bottom + 1));
    await tester.pump(_settle);
    expect((first, second), (1, 0));
    await tester.tapAt(Offset(lower.center.dx, lower.top - 1));
    await tester.pump(_settle);
    expect((first, second), (1, 1));
  });

  testWidgets('a target in another view does not disturb hit testing', (tester) async {
    await tester.pumpWidget(_app(Center(child: _small(() {}))));
    await _useFinger(tester);
    final other = RenderFrostTouchTarget(true);
    other.attach(PipelineOwner());
    other.layout(const BoxConstraints.tightFor(width: 10, height: 10));
    addTearDown(other.detach);
    final root = tester.renderObject<RenderFrostTouchTargetRoot>(find.byType(FrostTouchTargetRoot));
    expect(root.hitTest(BoxHitTestResult(), position: const Offset(5, 5)), isA<bool>());
  });

  testWidgets('every small control built on the shared surface gets the target', (tester) async {
    var checks = 0;
    await tester.pumpWidget(
      _app(
        Center(
          child: FrostCheckbox(value: false, semanticLabel: 'Check', onChanged: (_) => checks++),
        ),
      ),
    );
    await _useFinger(tester);
    final rect = tester.getRect(find.byType(FrostCheckbox));
    expect(rect.height, lessThan(44));
    await tester.tapAt(Offset(rect.center.dx, rect.bottom + 2));
    await tester.pump(_settle);
    expect(checks, 1);
  });
  testWidgets('a toast action under FrostApp takes a finger just outside it', (tester) async {
    final delegate = TestRouter(const SizedBox.expand());
    addTearDown(delegate.dispose);
    var taps = 0;
    await tester.pumpWidget(
      FrostApp.router(
        config: testConfig,
        title: 'Test',
        routerConfig: RouterConfig<Object>(routerDelegate: delegate),
        locale: const Locale('en', 'US'),
      ),
    );
    await _useFinger(tester);
    FrostToast.actionableInfo('Deleted', actionLabel: 'Undo', onAction: () => taps++);
    await tester.pump(_settle);
    final rect = tester.getRect(find.ancestor(of: find.text('Undo'), matching: find.byType(FrostButton)).first);
    expect(rect.height, lessThan(44));
    await tester.tapAt(_below(rect));
    await tester.pump(_settle);
    expect(taps, 1);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
