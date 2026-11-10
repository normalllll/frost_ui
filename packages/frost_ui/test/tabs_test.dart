import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/desktop.dart';
import 'package:frost_ui/frost_ui.dart';

import 'support.dart';

class _Tab {
  _Tab(this.name);
  final String name;
  @override
  String toString() => name;
}

class _Counter extends StatefulWidget {
  const _Counter(this.name);
  final String name;
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int taps = 0;
  @override
  Widget build(BuildContext context) => TextButton(onPressed: () => setState(() => taps++), child: Text('${widget.name}:$taps'));
}

List<String> _names(FrostTabsController<_Tab> controller) => [for (final tab in controller.tabs) tab.name];

Widget _host(
  FrostTabsController<_Tab> controller, {
  VoidCallback? onNewTab,
  FrostDensity density = FrostDensity.comfortable,
  double stripHeight = 40,
  TargetPlatform platform = TargetPlatform.windows,
}) => frostTestApp(
  Scaffold(
    body: Column(
      children: [
        SizedBox(
          height: stripHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FrostTabStrip<_Tab>(
              controller: controller,
              label: (context, tab) => FrostTabLabel(title: 'T.${tab.name}'),
              closeTooltip: 'L.close',
              newTabTooltip: 'L.newTab',
              newTabIcon: const FrostIconData.glyph(IconData(0xe001)),
              onNewTab: onNewTab ?? () {},
            ),
          ),
        ),
        Expanded(
          child: FrostTabHost<_Tab>(controller: controller, onNewTab: onNewTab, builder: (context, tab) => _Counter(tab.name)),
        ),
      ],
    ),
  ),
  density: density,
  platform: platform,
);

Rect _tabRect(WidgetTester tester, String name) => tester.getRect(find.ancestor(of: find.text('T.$name'), matching: find.byType(Positioned)).first);

void main() {
  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    testWidgets('embedded close padding closes without activating the tab $platform', (tester) async {
      final controller = FrostTabsController<_Tab>(initial: _Tab('a'));
      addTearDown(controller.dispose);
      controller.open(_Tab('b'), activate: false);
      final touch = platform == TargetPlatform.android;
      await tester.pumpWidget(_host(controller, platform: platform, stripHeight: touch ? 44 : 40));
      await tester.pumpAndSettle();
      final close = findFrostTooltip('L.close').last;
      expect(tester.getSize(close), Size(touch ? 44 : 24, touch ? 44 : 40));
      final surface = find.descendant(of: close, matching: find.byType(FrostClickSurface));
      expect(tester.getSize(surface), const Size(20, 20));
      await tester.tapAt(tester.getRect(close).topCenter + const Offset(0, 1));
      await tester.pumpAndSettle();
      expect(_names(controller), ['a']);
      expect(controller.active.name, 'a');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('selected strip keeps 20px close visuals inside a narrow full-height pointer target', (tester) async {
    final controller = FrostTabsController<_Tab>(initial: _Tab('a'));
    addTearDown(controller.dispose);
    controller.open(_Tab('b'), activate: false);
    await tester.pumpWidget(_host(controller));
    await tester.pumpAndSettle();
    final tokens = FrostThemeTokens.of(tester.element(find.byType(FrostTabStrip<_Tab>)));
    final background = find.ancestor(of: find.text('T.a'), matching: find.byType(AnimatedContainer)).first;
    final decorated = find.descendant(of: background, matching: find.byType(DecoratedBox)).first;
    expect((tester.renderObject<RenderDecoratedBox>(decorated).decoration as ShapeDecoration).color, tokens.surfaceRaised);
    expect(tester.renderObject<RenderParagraph>(find.text('T.a')).text.style!.color, tokens.textPrimary);
    final close = findFrostTooltip('L.close').first;
    final surface = find.descendant(of: close, matching: find.byType(FrostClickSurface));
    expect(tester.getSize(surface), const Size(20, 20));
    final shape =
        (tester.renderObject<RenderDecoratedBox>(find.descendant(of: surface, matching: find.byType(DecoratedBox)).first).decoration as ShapeDecoration).shape
            as RoundedSuperellipseBorder;
    expect(shape.borderRadius.resolve(TextDirection.ltr).topLeft.x, FrostRadius.forHeight(20));
    expect(tester.widget<FrostIcon>(find.descendant(of: surface, matching: find.byType(FrostIcon))).size, 14);
    expect(tester.getSize(close), const Size(24, 40));
    expect(_tabRect(tester, 'a').height, 40);
    controller.activate(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    final middle = tester.renderObject<RenderParagraph>(find.text('T.b')).text.style!.color;
    expect(middle, isNot(tokens.textPrimary));
    expect(middle, isNot(tokens.textSecondary));
    await tester.pumpAndSettle();
    expect(tester.renderObject<RenderParagraph>(find.text('T.b')).text.style!.color, tokens.textPrimary);
    expect(tester.takeException(), isNull);
  });
  testWidgets('tab selection radius follows its actual background height', (tester) async {
    final controller = FrostTabsController<_Tab>(initial: _Tab('a'));
    addTearDown(controller.dispose);
    for (final density in FrostDensity.values) {
      for (final height in [36.0, 40.0, 48.0]) {
        await tester.pumpWidget(_host(controller, density: density, stripHeight: height));
        await tester.pumpAndSettle();
        final background = find.ancestor(of: find.text('T.a'), matching: find.byType(AnimatedContainer)).first;
        final container = tester.widget<AnimatedContainer>(background);
        final margin = container.margin!.resolve(TextDirection.ltr);
        final actualHeight = tester.getSize(background).height - margin.vertical;
        expect(actualHeight, height - 8);
        final shape = (container.decoration! as ShapeDecoration).shape;
        final borderRadius = switch (shape) {
          RoundedSuperellipseBorder(:final borderRadius) => borderRadius,
          RoundedRectangleBorder(:final borderRadius) => borderRadius,
          _ => throw StateError('Unexpected tab selection shape: $shape'),
        }.resolve(TextDirection.ltr);
        expect(borderRadius, BorderRadius.circular(FrostRadius.forHeight(actualHeight)));
        for (final radius in [borderRadius.topLeft, borderRadius.topRight, borderRadius.bottomLeft, borderRadius.bottomRight]) {
          expect(radius.x, lessThanOrEqualTo(actualHeight * .30), reason: '$density strip height $height');
          expect(radius.y, lessThanOrEqualTo(actualHeight * .30), reason: '$density strip height $height');
        }
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('background tab separators keep their fixed geometry in both densities', (tester) async {
    final controller = FrostTabsController<_Tab>(initial: _Tab('a'));
    addTearDown(controller.dispose);
    controller.open(_Tab('b'), activate: false);
    controller.open(_Tab('c'), activate: false);
    for (final density in FrostDensity.values) {
      await tester.pumpWidget(_host(controller, density: density));
      await tester.pumpAndSettle();
      final tokens = FrostThemeTokens.of(tester.element(find.byType(FrostTabStrip<_Tab>)));
      final separator = find.descendant(
        of: find.byType(FrostTabStrip<_Tab>),
        matching: find.byWidgetPredicate((widget) => widget is ColoredBox && widget.color == tokens.separator),
      );
      expect(separator, findsOneWidget);
      expect(tester.getSize(separator), const Size(1, 16));
      expect(tester.takeException(), isNull);
    }
  });

  test('background tabs open in order after the front tab; closing picks a neighbour', () {
    final removed = <String>[];
    final a = _Tab('a');
    final controller = FrostTabsController<_Tab>(initial: a, onRemoved: (tab) => removed.add(tab.name));
    controller.open(_Tab('b'), activate: false);
    controller.open(_Tab('c'), activate: false);
    expect(_names(controller), ['a', 'b', 'c']);
    expect(controller.active, a);
    controller.open(_Tab('d'));
    expect(_names(controller), ['a', 'b', 'c', 'd']);
    expect(controller.active.name, 'd');
    expect(controller.close(3), isTrue);
    expect(controller.active.name, 'c');
    controller.activate(1);
    expect(controller.close(2), isTrue);
    expect(controller.active.name, 'b');
    expect(_names(controller), ['a', 'b']);
    controller.move(1, 0);
    expect(_names(controller), ['b', 'a']);
    expect(controller.active.name, 'b');
    expect(controller.close(0), isTrue);
    expect(controller.close(0), isFalse);
    expect(removed, ['d', 'c', 'b']);
    controller.dispose();
    expect(removed, ['d', 'c', 'b', 'a']);
  });

  testWidgets('hidden tabs keep their state and only the front one takes input', (tester) async {
    final controller = FrostTabsController<_Tab>(initial: _Tab('a'));
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller));
    await tester.tap(find.text('a:0'));
    await tester.pump();
    controller.open(_Tab('b'));
    await tester.pumpAndSettle();
    expect(find.text('b:0'), findsOneWidget);
    expect(find.text('a:1', skipOffstage: false), findsOneWidget);
    expect(find.text('a:1'), findsNothing);
    controller.activate(0);
    await tester.pumpAndSettle();
    expect(find.text('a:1'), findsOneWidget);
    controller.close(1);
    await tester.pumpAndSettle();
    expect(find.text('b:0', skipOffstage: false), findsNothing);
  });

  testWidgets('a background tab is built when it is first shown', (tester) async {
    final controller = FrostTabsController<_Tab>(initial: _Tab('a'));
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller));
    controller.open(_Tab('b'), activate: false);
    await tester.pumpAndSettle();
    expect(find.text('T.b'), findsOneWidget);
    expect(find.text('b:0', skipOffstage: false), findsNothing);
    await tester.tap(find.text('T.b'));
    await tester.pumpAndSettle();
    expect(find.text('b:0'), findsOneWidget);
  });

  testWidgets('tabs grow in, shrink out and slide instead of jumping', (tester) async {
    final controller = FrostTabsController<_Tab>(initial: _Tab('a'));
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller));
    final full = _tabRect(tester, 'a').width;
    controller.open(_Tab('b'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final growing = _tabRect(tester, 'b').width;
    expect(growing, greaterThan(0));
    expect(growing, lessThan(full));
    await tester.pumpAndSettle();
    expect(_tabRect(tester, 'b').width, full);
    expect(_tabRect(tester, 'b').left, _tabRect(tester, 'a').right);

    controller.close(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final shrinking = _tabRect(tester, 'a').width;
    expect(shrinking, lessThan(full));
    final sliding = _tabRect(tester, 'b').left;
    expect(sliding, greaterThan(0));
    await tester.pumpAndSettle();
    expect(find.text('T.a'), findsNothing);
    expect(_tabRect(tester, 'b').left, 0);
  });

  testWidgets('dragging a tab along the row reorders it', (tester) async {
    final controller = FrostTabsController<_Tab>(initial: _Tab('a'));
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller));
    controller.open(_Tab('b'), activate: false);
    controller.open(_Tab('c'), activate: false);
    await tester.pumpAndSettle();
    final width = _tabRect(tester, 'a').width;
    final gesture = await tester.startGesture(_tabRect(tester, 'a').center);
    for (var step = 0; step < 10; step++) {
      await gesture.moveBy(Offset(width / 10, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(_names(controller), ['b', 'a', 'c']);
    // The tab passed over slides into the freed place rather than jumping.
    expect(_tabRect(tester, 'b').left, greaterThan(0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(_tabRect(tester, 'b').left, 0);
    expect(_tabRect(tester, 'a').left, width);
    expect(controller.active.name, 'a');
  });

  testWidgets('middle click closes and the widths hold until the pointer leaves', (tester) async {
    final controller = FrostTabsController<_Tab>(initial: _Tab('a'));
    addTearDown(controller.dispose);
    await tester.binding.setSurfaceSize(const Size(500, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_host(controller));
    for (final name in ['b', 'c', 'd']) {
      controller.open(_Tab(name), activate: false);
    }
    await tester.pumpAndSettle();
    final width = _tabRect(tester, 'a').width;
    expect(width, lessThan(220));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse, buttons: kMiddleMouseButton);
    await mouse.addPointer(location: _tabRect(tester, 'b').center);
    await mouse.down(_tabRect(tester, 'b').center);
    await mouse.up();
    await tester.pumpAndSettle();
    expect(_names(controller), ['a', 'c', 'd']);
    expect(_tabRect(tester, 'c').width, width);
    await mouse.moveTo(const Offset(250, 300));
    await tester.pumpAndSettle();
    expect(_tabRect(tester, 'c').width, greaterThan(width));
  });

  testWidgets('tab keys from inside a tab are left to the app', (tester) async {
    final controller = FrostTabsController<_Tab>(initial: _Tab('a'));
    addTearDown(controller.dispose);
    controller.open(_Tab('b'), activate: false);
    var created = 0;
    await tester.pumpWidget(_host(controller, onNewTab: () => created++));
    await tester.tap(find.text('a:0'));
    await tester.pump();
    for (final modifier in [LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.metaLeft]) {
      await tester.sendKeyDownEvent(modifier);
      for (final key in [LogicalKeyboardKey.keyT, LogicalKeyboardKey.tab, LogicalKeyboardKey.digit2, LogicalKeyboardKey.digit9, LogicalKeyboardKey.keyW]) {
        await tester.sendKeyEvent(key);
      }
      await tester.sendKeyUpEvent(modifier);
      await tester.pumpAndSettle();
    }
    expect(created, 0);
    expect(_names(controller), ['a', 'b']);
    expect(controller.active.name, 'a');
  });
}
