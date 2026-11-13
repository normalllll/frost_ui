// Right-to-left placement and large-text sizing that spans several components.
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/media.dart';
import 'package:frost_ui/src/controls/_calendar.dart';
import 'package:frost_ui/src/layout/content_viewport.dart';
import 'package:frost_ui/src/overlays/_menu_panel.dart';
import 'package:frost_ui/src/overlays/menu_anchor.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

Widget _rtl(Widget child) => Directionality(textDirection: TextDirection.rtl, child: child);

Widget _scaled(double scale, Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child,
  ),
);

void _window(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Finder _icon(FrostIconData icon) => find.byWidgetPredicate((widget) => widget is FrostIcon && widget.icon == icon);

/// The number of distinct left edges among [items], which is their column count.
int _columns(WidgetTester tester, Finder items) =>
    {for (final element in items.evaluate()) tester.getTopLeft(find.byWidget(element.widget).first).dx.round()}.length;

void main() {
  group('FrostRollingText in RTL', () {
    testWidgets('keeps digits and separators in reading order', (tester) async {
      await tester.pumpWidget(frostTestApp(_rtl(const Center(child: FrostRollingText('12:34')))));
      final lefts = [
        for (final part in ['1', '2', ':', '3', '4']) tester.getTopLeft(find.text(part)).dx,
      ];
      expect(lefts, orderedEquals([...lefts]..sort()));
    });

    testWidgets('shows right-to-left script whole, because slots cannot shape it', (tester) async {
      await tester.pumpWidget(frostTestApp(_rtl(const Center(child: FrostRollingText('٣ محددة')))));
      expect(find.text('٣ محددة'), findsOneWidget);
    });
  });

  group('previous and next arrows', () {
    testWidgets('FrostShelf points away from the middle in RTL', (tester) async {
      await tester.pumpWidget(
        frostTestApp(
          _rtl(
            Scaffold(
              body: FrostShelf(title: 'Shelf', itemCount: 30, itemExtent: 100, height: 60, itemBuilder: (context, index) => Text('$index')),
            ),
          ),
        ),
      );
      await tester.pump();
      final left = tester.getCenter(_icon(testIcons.chevronLeft).first).dx, right = tester.getCenter(_icon(testIcons.chevronRight).first).dx;
      expect(left, lessThan(right));
    });

    testWidgets('FrostCalendar points away from the middle in RTL', (tester) async {
      await tester.pumpWidget(
        frostTestApp(
          _rtl(
            Scaffold(
              body: Center(
                child: FrostCalendar(firstDate: DateTime(2026), lastDate: DateTime(2026, 12, 31), today: DateTime(2026, 10, 16), onSelected: (_) {}),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final left = tester.getCenter(_icon(testIcons.chevronLeft).first).dx, right = tester.getCenter(_icon(testIcons.chevronRight).first).dx;
      expect(left, lessThan(right));
    });

    testWidgets('FrostPager points away from the middle in RTL', (tester) async {
      await tester.pumpWidget(
        frostTestApp(_rtl(Scaffold(body: FrostPager(itemCount: 3, initialPage: 1, itemBuilder: (context, index) => Text('Page $index'))))),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: tester.getCenter(find.byType(FrostPager)));
      await tester.pumpAndSettle();
      final left = tester.getCenter(_icon(testIcons.chevronLeft).first).dx, right = tester.getCenter(_icon(testIcons.chevronRight).first).dx;
      expect(left, lessThan(right));
    });
  });

  group('anchored panels', () {
    Future<void> open(WidgetTester tester, {required TextDirection direction, required Offset at, int entries = 2}) async {
      _window(tester, const Size(800, 800));
      await tester.pumpWidget(
        frostTestApp(
          Directionality(
            textDirection: direction,
            child: Stack(
              children: [
                Positioned(
                  left: at.dx,
                  top: at.dy,
                  width: 100,
                  height: 40,
                  child: FrostMenuAnchor(
                    entries: [for (var i = 0; i < entries; i++) FrostMenuAction('A rather long entry $i', onSelected: () {})],
                    builder: (context, focus, toggle) => GestureDetector(
                      key: const ValueKey('anchor'),
                      onTap: toggle,
                      child: const ColoredBox(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('anchor')));
      await tester.pumpAndSettle();
    }

    Alignment origin(WidgetTester tester) =>
        tester.widget<Transform>(find.descendant(of: find.byType(FrostMenuReveal), matching: find.byType(Transform)).first).alignment! as Alignment;

    testWidgets('align to the leading edge of the anchor in RTL, and scale from it', (tester) async {
      await open(tester, direction: TextDirection.rtl, at: const Offset(600, 100));
      final anchor = tester.getRect(find.byKey(const ValueKey('anchor'))), panel = tester.getRect(find.byType(FrostMenuPanel));
      expect(panel.right, closeTo(anchor.right, .5));
      expect(origin(tester), Alignment.topRight);
    });

    testWidgets('stay on the leading edge of the anchor in LTR', (tester) async {
      await open(tester, direction: TextDirection.ltr, at: const Offset(100, 100));
      final anchor = tester.getRect(find.byKey(const ValueKey('anchor'))), panel = tester.getRect(find.byType(FrostMenuPanel));
      expect(panel.left, closeTo(anchor.left, .5));
      expect(origin(tester), Alignment.topLeft);
    });

    testWidgets('scale from the bottom edge when placed above the anchor', (tester) async {
      await open(tester, direction: TextDirection.ltr, at: const Offset(100, 500), entries: 12);
      final anchor = tester.getRect(find.byKey(const ValueKey('anchor'))), panel = tester.getRect(find.byType(FrostMenuPanel));
      expect(panel.bottom, lessThanOrEqualTo(anchor.top + .5));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 16));
      expect(origin(tester), Alignment.bottomLeft);
    });
  });

  group('anchored panels from a pointer or hover', () {
    Alignment origin(WidgetTester tester) =>
        tester.widget<Transform>(find.descendant(of: find.byType(FrostMenuReveal), matching: find.byType(Transform)).first).alignment! as Alignment;

    testWidgets('a pointer menu turned back at the edge scales from the pointer', (tester) async {
      _window(tester, const Size(800, 800));
      await tester.pumpWidget(frostTestApp(const Scaffold(body: SizedBox.expand(key: ValueKey('page')))));
      unawaited(
        showFrostContextMenu(
          context: tester.element(find.byKey(const ValueKey('page'))),
          globalPosition: const Offset(790, 100),
          entries: [FrostMenuAction('A rather long entry', onSelected: () {})],
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(FrostMenuPanel)).right, lessThanOrEqualTo(792));
      await tester.pump();
      expect(origin(tester).x, 1);
    });
  });

  group('FrostSwipeActions with pointer actions', () {
    final trailing = [FrostSwipeAction(label: 'Delete', icon: testIcons.delete, onPressed: () {})];
    Future<Size> lay(WidgetTester tester, Widget child) async {
      await tester.pumpWidget(
        frostTestApp(
          Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(key: const ValueKey('box'), width: 500, child: child),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      return tester.getSize(find.byKey(const ValueKey('box')));
    }

    testWidgets('takes a child that cannot answer intrinsic sizes', (tester) async {
      final size = await lay(
        tester,
        FrostSwipeActions(
          trailing: trailing,
          child: LayoutBuilder(builder: (context, constraints) => const SizedBox(height: 40)),
        ),
      );
      expect(size.height, 40);
    });

    testWidgets('gives a child that fills the bounded height it is placed in', (tester) async {
      await lay(
        tester,
        SizedBox(
          height: 60,
          child: FrostSwipeActions(
            trailing: trailing,
            child: const SizedBox.expand(key: ValueKey('fill')),
          ),
        ),
      );
      expect(tester.getSize(find.byKey(const ValueKey('fill'))).height, 60);
    });

    testWidgets('gives a column with an expanded child its bounded height', (tester) async {
      await lay(
        tester,
        SizedBox(
          height: 60,
          child: FrostSwipeActions(
            trailing: trailing,
            child: const Column(
              children: [
                Expanded(
                  child: ColoredBox(key: ValueKey('fill'), color: Colors.red),
                ),
              ],
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byKey(const ValueKey('fill'))).height, 60);
    });
  });

  group('trailing chevrons in RTL', () {
    for (final (name, child) in <(String, Widget)>[
      ('FrostDisclosure', const FrostDisclosure(title: 'More', child: SizedBox())),
      (
        'FrostSectionHeader.collapsible',
        FrostSectionHeader.collapsible(title: 'Section', expanded: false, onExpansionChanged: (_) {}, child: const SizedBox()),
      ),
      ('FrostListRow', FrostListRow(title: 'Row', accessory: FrostRowAccessory.chevron)),
    ]) {
      testWidgets('$name points the way the text reads', (tester) async {
        await tester.pumpWidget(frostTestApp(_rtl(Scaffold(body: Center(child: child)))));
        expect(_icon(testIcons.chevronLeft), findsOneWidget);
        expect(_icon(testIcons.chevronRight), findsNothing);
      });
    }
  });

  testWidgets('FrostRollingText reads a shortened count as growth', (tester) async {
    Widget text(String value) => frostTestApp(Center(child: FrostRollingText(value)));
    await tester.pumpWidget(text('9999'));
    await tester.pumpWidget(text('1.0万'));
    await tester.pump(const Duration(milliseconds: 16));
    final incoming = tester.widget<SlideTransition>(find.ancestor(of: find.text('万'), matching: find.byType(SlideTransition)).first);
    expect(incoming.position.value.dy, greaterThan(0));
  });

  testWidgets('FrostFit gives autofocus to the candidate that fits, on the first frame', (tester) async {
    final hidden = FocusNode(), shown = FocusNode();
    addTearDown(hidden.dispose);
    addTearDown(shown.dispose);
    await tester.pumpWidget(
      frostTestApp(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 150,
            child: FrostFit(
              candidates: [
                (_) => Focus(autofocus: true, focusNode: hidden, child: const SizedBox(width: 300, height: 40)),
                (_) => Focus(autofocus: true, focusNode: shown, child: const SizedBox(width: 100, height: 40)),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(hidden.hasFocus, isFalse);
    expect(shown.hasPrimaryFocus, isTrue);
  });

  group('column counts at large text', () {
    Widget tile(int index) => SizedBox(height: 40, child: Text('Tile $index'));

    Future<int> count(WidgetTester tester, double scale, Widget grid) async {
      _window(tester, const Size(1000, 800));
      await tester.pumpWidget(frostTestApp(_scaled(scale, Scaffold(body: grid))));
      await tester.pumpAndSettle();
      return _columns(tester, find.byType(Text));
    }

    for (final scale in [1.1, 1.2, 1.3, 1.5, 1.8, 2.0, 3.0]) {
      testWidgets('agree between FrostGrid, FrostSliverGrid, FrostSliverList and the waterfall at $scale', (tester) async {
        const minimum = 200.0;
        final grid = await count(
          tester,
          scale,
          SingleChildScrollView(
            child: FrostGrid(minItemWidth: minimum, children: [for (var i = 0; i < 8; i++) tile(i)]),
          ),
        );
        final sliverGrid = await count(
          tester,
          scale,
          CustomScrollView(
            slivers: [FrostSliverGrid(minItemWidth: minimum, aspectRatio: 4, itemCount: 8, itemBuilder: (context, index) => tile(index))],
          ),
        );
        final list = await count(
          tester,
          scale,
          CustomScrollView(
            slivers: [FrostSliverList.columns(itemCount: 8, minColumnWidth: minimum, itemBuilder: (context, index) => tile(index))],
          ),
        );
        final waterfall = await count(
          tester,
          scale,
          FrostWaterfallGrid<int>(
            items: const [0, 1, 2, 3, 4, 5, 6, 7],
            preferredTileWidth: minimum,
            padding: EdgeInsets.zero,
            itemBuilder: (context, value, index) => tile(value),
          ),
        );
        expect({grid, sliverGrid, list, waterfall}.length, 1, reason: 'grid $grid, sliver grid $sliverGrid, list $list, waterfall $waterfall');
      });
    }

    testWidgets('FrostSliverGrid and FrostSliverList.columns spare the width a sidebar will take', (tester) async {
      Future<int> reserved(Widget sliver) => count(tester, 1, FrostContentColumnBudget(reservedWidth: 500, child: CustomScrollView(slivers: [sliver])));
      expect(await reserved(FrostSliverGrid(minItemWidth: 200, aspectRatio: 4, itemCount: 8, itemBuilder: (context, index) => tile(index))), 2);
      expect(await reserved(FrostSliverList.columns(itemCount: 8, minColumnWidth: 200, itemBuilder: (context, index) => tile(index))), 2);
    });

    test('the waterfall follows text size gradually, with no threshold at 1.8', () {
      int at(double scale) => frostWaterfallColumnCount(width: 1000, preferredTileWidth: 200, gap: 8, textScale: scale);
      expect(at(1), 5);
      expect(at(1.5), 3);
      expect(at(1.79), at(1.81));
      expect(at(2), 2);
    });

    test('an explicit waterfall count yields to large text and stays exact at normal size', () {
      int at(double scale) => frostWaterfallColumnCount(width: 1000, preferredTileWidth: 200, gap: 8, textScale: scale, columns: 6);
      expect(at(1), 6);
      expect(at(1.01), 6);
      expect(at(2), 3);
      expect(frostWaterfallColumnCount(width: 1000, preferredTileWidth: 200, gap: 8, textScale: 1.01, columns: 2), 2);
    });

    testWidgets('a phone keeps two media columns at normal size and one at large text', (tester) async {
      int at(double scale) => frostWaterfallColumnCount(width: 400, preferredTileWidth: 220, gap: 8, textScale: scale);
      expect(at(1), 2);
      expect(at(1.01), 2);
      expect(at(1.4), 2);
      expect(at(2), 1);
    });
  });
  group('FrostRollingText width', () {
    Widget text(String value, {bool reduced = false}) => frostTestApp(
      MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Align(
          alignment: Alignment.topLeft,
          child: FrostRollingText(value, style: const TextStyle(fontSize: 20)),
        ),
      ),
    );
    double width(WidgetTester tester) => tester.getSize(find.byType(FrostRollingText)).width;

    testWidgets('eases to a new digit instead of jumping', (tester) async {
      await tester.pumpWidget(text('9'));
      await tester.pumpAndSettle();
      final before = width(tester);
      await tester.pumpWidget(text('10'));
      expect(width(tester), before);
      await tester.pump(const Duration(milliseconds: 60));
      final moving = width(tester);
      expect(moving, greaterThan(before));
      await tester.pumpAndSettle();
      expect(width(tester), greaterThan(moving));
      expect(tester.takeException(), isNull);
    });

    testWidgets('changes at once with reduced motion', (tester) async {
      await tester.pumpWidget(text('9', reduced: true));
      await tester.pumpAndSettle();
      final before = width(tester);
      await tester.pumpWidget(text('10', reduced: true));
      expect(width(tester), greaterThan(before));
    });
  });
}
