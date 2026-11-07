import 'dart:math' as math;
import 'dart:ui' show CheckedState;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/lists/_table_cells.dart';
import 'support.dart';

List<FrostTableColumn<int>> columns({double? width, bool long = false}) => [
  FrostTableColumn(
    label: 'Name',
    cell: (_, i) => Text(long ? 'Long wrapped item $i repeated repeated repeated' : 'Item $i'),
    text: (i) => 'Name $i',
    width: width,
    primary: true,
    sortKey: (i) => i,
  ),
  FrostTableColumn(label: 'Bytes', cell: (_, i) => Text((i + 100).toString()), text: (i) => (i + 100).toString(), numeric: true, sortKey: (i) => i),
];
Widget view(Widget child, {double width = 800, double scale = 1, TextDirection direction = TextDirection.ltr}) => frostTestApp(
  MediaQuery(
    data: MediaQueryData(size: Size(width, 600), textScaler: TextScaler.linear(scale)),
    child: Directionality(
      textDirection: direction,
      child: Center(
        child: SizedBox(width: width, height: 300, child: child),
      ),
    ),
  ),
);
Future<void> modified(WidgetTester tester, String label, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(key);
  await tester.tap(find.text(label));
  await tester.sendKeyUpEvent(key);
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [350.0, 800.0]) {
    testWidgets('independent checkbox semantics and keyboard at width $width', (tester) async {
      final semantics = tester.ensureSemantics();
      var checked = false;
      late StateSetter update;
      final activated = <int>[];
      Widget checkbox() => FrostCheckbox(value: checked, semanticLabel: 'Select voice', onChanged: (value) => update(() => checked = value!));
      await tester.pumpWidget(
        view(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return FrostTable<int>(
                columns: [
                  FrostTableColumn(label: 'Select', text: (_) => 'Selection', cell: (_, _) => checkbox()),
                  ...columns(),
                ],
                rows: const [0, 1],
                compactRow: (_, _) => FrostTableCompactRow(leading: checkbox(), trailing: const Text('Ready'), subtitle: 'Battle · 100 B'),
                onActivate: activated.add,
              );
            },
          ),
          width: width,
        ),
      );
      final check = find.bySemanticsLabel('Select voice').first;
      final node = tester.getSemantics(check);
      expect(node.getSemanticsData().flagsCollection.isChecked, CheckedState.isFalse);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      tester.binding.performSemanticsAction(SemanticsActionEvent(type: SemanticsAction.tap, viewId: tester.view.viewId, nodeId: node.id));
      expect(checked, isTrue);
      expect(activated, isEmpty);
      await tester.pump();
      expect(tester.getSemantics(check).getSemanticsData().flagsCollection.isChecked, CheckedState.isTrue);
      await tester.tap(find.byType(FrostCheckbox).first);
      expect(checked, isFalse);
      expect(activated, isEmpty);
      final title = find.text(width < 600 ? 'Name 0' : 'Item 0');
      await tester.tap(title);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(activated, [0, 1]);
      // Focus the actual independent input surface, then use its own keys.
      final input = find.descendant(of: find.byType(FrostCheckbox).first, matching: find.byType(RawGestureDetector)).first;
      Focus.of(tester.element(input)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(checked, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(checked, isFalse);
      expect(activated, [0, 1]);
      if (width < 600) {
        expect(find.text('Battle · 100 B'), findsNWidgets(2));
        expect(find.text('Ready'), findsNWidgets(2));
        expect(find.textContaining('Selection ·'), findsNothing);
      }
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
  test('column bounds and empty columns assert', () {
    expect(() => FrostTableColumn<int>(label: 'X', cell: (_, _) => const SizedBox(), minWidth: 0), throwsAssertionError);
    expect(() => FrostTableColumn<int>(label: 'X', cell: (_, _) => const SizedBox(), width: double.infinity), throwsAssertionError);
    expect(() => FrostTable<int>(columns: const [], rows: const []), throwsAssertionError);
  });
  testWidgets('Ctrl, Shift, a plain click and the keyboard', (tester) async {
    final selection = FrostSelection<int>();
    addTearDown(selection.dispose);
    final activated = <int>[];
    await tester.pumpWidget(view(FrostTable(columns: columns(), rows: List.generate(8, (i) => i), selection: selection, onActivate: activated.add)));
    await modified(tester, 'Item 4', LogicalKeyboardKey.controlLeft);
    expect(selection.selected, {4});
    await modified(tester, 'Item 2', LogicalKeyboardKey.controlLeft);
    expect(selection.selected, {2, 4});
    await modified(tester, 'Item 5', LogicalKeyboardKey.shiftLeft);
    expect(selection.selected, {2, 3, 4, 5});
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(selection.isSelected(4), isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(activated, [4]);
    await tester.tap(find.text('Item 0'));
    await tester.pumpAndSettle();
    expect(activated, [4, 0]);
    expect(selection.selected, {2, 3, 5});
    expect(tester.takeException(), isNull);
  });
  testWidgets('ordinary activation and independent cell button retain their actions', (tester) async {
    var activated = 0, button = 0;
    final selection = FrostSelection<int>();
    addTearDown(selection.dispose);
    final cols = [
      ...columns(),
      FrostTableColumn<int>(
        label: 'Action',
        cell: (_, i) => FrostButton(label: 'Open $i', onPressed: () => button++),
      ),
    ];
    await tester.pumpWidget(view(FrostTable(columns: cols, rows: const [0, 1], selection: selection, onActivate: (_) => activated++)));
    await tester.tap(find.text('Open 1'));
    await tester.pumpAndSettle();
    expect(button, 1);
    expect(selection.selected, isEmpty);
    expect(activated, 0);
    await tester.pumpWidget(view(FrostTable(columns: columns(), rows: const [0, 1], onActivate: (_) => activated++)));
    await tester.tap(find.text('Item 0'));
    await tester.pumpAndSettle();
    expect(activated, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(activated, 2);
    expect(tester.takeException(), isNull);
  });
  testWidgets('sort caller state and same arrow rotates through intermediate frame', (tester) async {
    var ascending = true;
    (int, bool)? last;
    await tester.pumpWidget(
      view(
        StatefulBuilder(
          builder: (context, setState) => FrostTable(
            columns: columns(),
            rows: const [0],
            sortColumn: 0,
            sortAscending: ascending,
            onSort: (value) {
              last = value;
              setState(() => ascending = value.$2);
            },
          ),
        ),
      ),
    );
    final iconBefore = tester.widget<FrostIcon>(find.byType(FrostIcon).first).icon;
    await tester.tap(find.text('Name'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(last, (0, false));
    final rotation = find.descendant(of: find.byType(AnimatedRotation).first, matching: find.byType(RotationTransition));
    expect(tester.widget<RotationTransition>(rotation).turns.value, inExclusiveRange(0, .5));
    await tester.pumpAndSettle();
    expect(tester.widget<RotationTransition>(rotation).turns.value, .5);
    expect(tester.widget<FrostIcon>(find.byType(FrostIcon).first).icon, iconBefore);
  });
  for (final direction in TextDirection.values) {
    testWidgets('resize, PageStorage, reset only one column direction=$direction', (tester) async {
      final bucket = PageStorageBucket();
      Widget table() => view(
        PageStorage(
          bucket: bucket,
          child: FrostTable(key: const PageStorageKey('table'), columns: columns(), rows: const [0]),
        ),
        direction: direction,
      );
      await tester.pumpWidget(table());
      final handles = find.byWidgetPredicate((w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeColumn);
      final before = tester.getCenter(handles.first).dx;
      await tester.drag(handles.first, Offset(direction == TextDirection.ltr ? 80 : -80, 0));
      await tester.pumpAndSettle();
      final after = tester.getCenter(handles.first).dx;
      expect((after - before).abs(), greaterThan(20));
      final saved = bucket.readState(tester.element(find.byType(FrostTable<int>)), identifier: const PageStorageKey('table')) as Map<int, double>;
      expect(saved[0], greaterThan(400));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(table());
      expect(tester.getCenter(handles.first).dx, closeTo(after, .1));
      await tester.tap(handles.first);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(handles.first);
      await tester.pumpAndSettle();
      expect(tester.getCenter(handles.first).dx, closeTo(before, .1));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('explicit compact text, primary without text, first primary wins', (tester) async {
    final cols = [
      FrostTableColumn<int>(
        label: 'First',
        primary: true,
        text: (i) => 'Title $i',
        cell: (_, i) => Padding(padding: EdgeInsets.zero, child: Text('Wrapped $i')),
      ),
      FrostTableColumn<int>(label: 'Second', primary: true, text: (i) => 'Value $i', cell: (_, i) => Text('V $i')),
      FrostTableColumn<int>(label: 'Picture', cell: (_, i) => Text('Omitted $i')),
    ];
    await tester.pumpWidget(view(FrostTable(columns: cols, rows: const [1]), width: 350, scale: 2));
    expect(find.byType(FrostListRow), findsOneWidget);
    expect(find.text('Title 1'), findsOneWidget);
    expect(find.text('Value 1'), findsOneWidget);
    expect(find.text('Omitted 1'), findsNothing);
    await tester.pumpWidget(view(FrostTable(columns: [cols.last, cols[1]], rows: const [1]), width: 350));
    expect(find.text('Value 1'), findsOneWidget);
    await tester.pumpWidget(view(FrostTable(columns: [cols.last], rows: const [1]), width: 350));
    expect(find.text('Picture'), findsOneWidget);
    expect(find.text('Omitted 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('compact selection activates when inactive and toggles when active', (tester) async {
    final selection = FrostSelection<int>();
    addTearDown(selection.dispose);
    var opened = 0;
    await tester.pumpWidget(view(FrostTable(columns: columns(), rows: const [0, 1], selection: selection, onActivate: (_) => opened++), width: 350));
    await tester.tap(find.text('Name 0'));
    expect(opened, 1);
    expect(selection.active, isFalse);
    final gesture = await tester.startGesture(tester.getCenter(find.text('Name 1')), kind: PointerDeviceKind.touch);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 1));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(selection.selected, {1});
    await tester.tap(find.text('Name 0'));
    expect(selection.selected, {0, 1});
    expect(opened, 1);
  });
  testWidgets('table role tree, lazy full dimensions and explicit cell semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    var built = 0;
    final cols = [
      FrostTableColumn<int>(
        label: 'Name',
        text: (i) => 'Semantic $i',
        cell: (_, i) {
          built++;
          return Text('Visual $i');
        },
      ),
      columns()[1],
    ];
    await tester.pumpWidget(view(FrostTable(columns: cols, rows: List.generate(900, (i) => i))));
    expect(built, lessThan(40));
    final table = find.byWidgetPredicate((w) => w is Semantics && w.properties.role == SemanticsRole.table);
    final node = tester.getSemantics(table);
    expect(node.getSemanticsData().label, '900 × 2');
    final roles = <SemanticsRole>[];
    node.visitChildren((child) {
      roles.add(child.getSemanticsData().role);
      return true;
    });
    expect(roles, isNotEmpty);
    expect(roles.every((role) => role == SemanticsRole.row), isTrue);
    expect(find.bySemanticsLabel('Semantic 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
  testWidgets('numeric cell actual right edge and tabular figures; horizontal scrolling shares header', (tester) async {
    await tester.pumpWidget(view(FrostTable(columns: columns(width: 900), rows: const [0, 1])));
    final text = find.text('100');
    final paragraph = tester.renderObject<RenderParagraph>(text);
    expect(paragraph.text.style!.fontFeatures, contains(const FontFeature.tabularFigures()));
    expect(tester.getRect(text).right, closeTo(988, .1));
    final before = tester.getTopLeft(find.text('Name')).dx;
    final horizontal = tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .firstWhere((s) => axisDirectionToAxis(s.position.axisDirection) == Axis.horizontal);
    horizontal.position.jumpTo(horizontal.position.maxScrollExtent);
    await tester.pump();
    expect(tester.getTopLeft(find.text('Name')).dx, lessThan(before));
    expect(tester.getTopLeft(find.text('Item 0')).dx - tester.getTopLeft(find.text('Name')).dx, closeTo(0, .1));
  });
  for (final density in FrostDensity.values) {
    testWidgets('regular row height and role growth density=$density', (tester) async {
      double height() => tester.getSize(find.byWidgetPredicate((w) => w.runtimeType.toString() == 'FrostTableCells').at(1)).height;
      Widget app(double scale) => frostTestApp(
        MediaQuery(
          data: MediaQueryData(size: const Size(800, 600), textScaler: TextScaler.linear(scale)),
          child: FrostTable(columns: columns(), rows: const [0]),
        ),
        density: density,
      );
      await tester.pumpWidget(app(1));
      final base = height();
      expect(base, 36);
      await tester.pumpWidget(app(2));
      expect(height(), greaterThan(base));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('local narrow width does not overflow and big text wraps', (tester) async {
    Widget table(double width) => view(
      Center(
        child: SizedBox(
          width: width,
          child: FrostTable(columns: columns(long: true), rows: const [0, 1]),
        ),
      ),
      scale: 2,
      direction: TextDirection.rtl,
    );
    await tester.pumpWidget(table(120));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(table(620));
    expect(find.textContaining('Long wrapped'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets('keyboard reaches a lazy distant row and activates its actual item', (tester) async {
    int? opened;
    await tester.pumpWidget(view(FrostTable(columns: columns(), rows: List.generate(900, (i) => i), onActivate: (i) => opened = i)));
    await tester.tap(find.text('Item 0'));
    for (var i = 0; i < 25; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Item 25').hitTestable(), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(opened, 25);
    expect(tester.takeException(), isNull);
  });
  testWidgets('empty table remains valid with semantics and keys', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(view(FrostTable<int>(columns: columns(), rows: const [])));
    await tester.tap(find.text('Name'));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    expect(find.bySemanticsLabel('0 × 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
  testWidgets('sortable header exposes a semantic tap action and sort state', (tester) async {
    final semantics = tester.ensureSemantics();
    (int, bool)? sorted;
    await tester.pumpWidget(view(FrostTable(columns: columns(), rows: const [0], sortColumn: 0, sortAscending: false, onSort: (value) => sorted = value)));
    final header = tester.getSemantics(
      find.byWidgetPredicate((w) => w is Semantics && w.properties.role == SemanticsRole.columnHeader && w.properties.label == 'Name'),
    );
    expect(header.getSemanticsData().value, 'L.sortDescending');
    expect(header.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    tester.binding.performSemanticsAction(SemanticsActionEvent(type: SemanticsAction.tap, viewId: tester.view.viewId, nodeId: header.id));
    expect(sorted, (0, true));
    semantics.dispose();
  });

  for (final tabbed in [false, true]) {
    testWidgets('selection keeps arrows, Enter and Space working, entered by ${tabbed ? 'Tab' : 'click'}', (tester) async {
      final selection = FrostSelection<int>();
      addTearDown(selection.dispose);
      final activated = <int>[];
      await tester.pumpWidget(view(FrostTable<int>(columns: columns(), rows: const [0, 1, 2], selection: selection, onActivate: activated.add)));
      await tester.pumpAndSettle();
      if (tabbed) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      } else {
        await tester.tapAt(tester.getCenter(find.text('Item 0')), kind: PointerDeviceKind.mouse);
        await tester.pumpAndSettle();
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(activated, tabbed ? [1] : [0, 1]);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(selection.selected, {1});
    });
  }

  testWidgets('Enter and Space act on the first row right after Tab, with and without selection', (tester) async {
    final selection = FrostSelection<int>();
    addTearDown(selection.dispose);
    final activated = <int>[];
    for (final selectable in [false, true]) {
      activated.clear();
      await tester.pumpWidget(
        view(
          FrostTable<int>(
            key: ValueKey(selectable),
            columns: columns(),
            rows: const [0, 1],
            selection: selectable ? selection : null,
            onActivate: activated.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(activated, [0], reason: 'selectable=$selectable');
      if (selectable) {
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();
        expect(selection.selected, {0});
      }
    }
  });

  testWidgets('a narrow table with selection keeps arrows, Enter and Space after a tap', (tester) async {
    final selection = FrostSelection<int>();
    addTearDown(selection.dispose);
    final activated = <int>[];
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(350, 700);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      frostTestApp(
        SizedBox(
          height: 500,
          child: FrostTable<int>(columns: columns(), rows: const [0, 1, 2], selection: selection, onActivate: activated.add),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Name 0'));
    await tester.pumpAndSettle();
    expect(activated, [0]);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(activated, [0, 1]);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(selection.selected, {1});
  });

  testWidgets('Tab after scrolling lands on a visible row, not offscreen row 0', (tester) async {
    final activated = <int>[];
    await tester.pumpWidget(view(FrostTable<int>(columns: columns(), rows: List.generate(100, (index) => index), onActivate: activated.add)));
    await tester.pumpAndSettle();
    // The wheel, because a pointer press on a row would already focus and highlight it.
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(tester.getCenter(find.text('Item 1'))));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 1000)));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(activated, hasLength(1));
    expect(activated.single, greaterThan(0));
    expect(find.text('Item ${activated.single}').hitTestable(), findsOneWidget);
  });

  testWidgets('a touch scroll keeps the selection and moves neither focus nor highlight', (tester) async {
    final selection = FrostSelection<int>()..selectAll([1, 2, 3]);
    addTearDown(selection.dispose);
    final activated = <int>[];
    await tester.pumpWidget(view(FrostTable<int>(columns: columns(), rows: List.generate(100, (i) => i), selection: selection, onActivate: activated.add)));
    final focused = FocusManager.instance.primaryFocus;
    await tester.drag(find.text('Item 5'), const Offset(0, -120), kind: PointerDeviceKind.touch);
    await tester.pumpAndSettle();
    expect(selection.selected, {1, 2, 3});
    expect(activated, isEmpty);
    expect(FocusManager.instance.primaryFocus, focused);
  });

  testWidgets('selection takes effect when the pointer comes up', (tester) async {
    final selection = FrostSelection<int>();
    addTearDown(selection.dispose);
    await tester.pumpWidget(view(FrostTable<int>(columns: columns(), rows: const [0, 1], selection: selection)));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    final mouse = await tester.startGesture(tester.getCenter(find.text('Item 1')), kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(selection.selected, isEmpty);
    await mouse.up();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(selection.selected, {1});
  });

  testWidgets('arrow keys reveal rows without moving the horizontal offset', (tester) async {
    await tester.pumpWidget(view(FrostTable<int>(columns: columns(width: 1200), rows: List.generate(40, (i) => i), onActivate: (_) {})));
    final horizontal = tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .firstWhere((s) => axisDirectionToAxis(s.position.axisDirection) == Axis.horizontal)
        .position;
    horizontal.jumpTo(300);
    await tester.pump();
    final vertical = tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .firstWhere((s) => axisDirectionToAxis(s.position.axisDirection) == Axis.vertical)
        .position;
    await tester.tapAt(tester.getCenter(find.byType(FrostTable<int>)));
    await tester.pump();
    for (var i = 0; i < 12; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(horizontal.pixels, 300);
    }
    expect(vertical.pixels, greaterThan(0));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(horizontal.pixels, 300);
  });

  testWidgets('rows select like a list: Ctrl or Cmd toggles, a plain click opens, emptying leaves the mode', (tester) async {
    final selection = FrostSelection<int>();
    addTearDown(selection.dispose);
    final activated = <int>[];
    await tester.pumpWidget(view(FrostTable<int>(columns: columns(), rows: const [0, 1, 2], selection: selection, onActivate: activated.add)));
    await modified(tester, 'Item 0', LogicalKeyboardKey.controlLeft);
    await modified(tester, 'Item 1', LogicalKeyboardKey.metaLeft);
    expect(selection.selected, {0, 1});
    await tester.tap(find.text('Item 2'));
    await tester.pumpAndSettle();
    expect(activated, [2]);
    expect(selection.selected, {0, 1});
    await modified(tester, 'Item 0', LogicalKeyboardKey.metaLeft);
    await modified(tester, 'Item 1', LogicalKeyboardKey.controlLeft);
    expect(selection.selected, isEmpty);
    expect(selection.active, isFalse);
  });

  testWidgets('a touch long press on a row starts selecting and taps then toggle', (tester) async {
    final selection = FrostSelection<int>();
    addTearDown(selection.dispose);
    final activated = <int>[];
    await tester.pumpWidget(view(FrostTable<int>(columns: columns(), rows: const [0, 1], selection: selection, onActivate: activated.add)));
    await tester.longPress(find.text('Item 0'));
    await tester.pumpAndSettle();
    expect(selection.selected, {0});
    await tester.tap(find.text('Item 1'));
    await tester.pumpAndSettle();
    expect(selection.selected, {0, 1});
    expect(activated, isEmpty);
    final mouse = await tester.startGesture(tester.getCenter(find.text('Item 1')), kind: PointerDeviceKind.mouse);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 1));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(selection.selected, {0});
    expect(tester.takeException(), isNull);
  });
  testWidgets('a narrow table with no other text column has no empty subtitle line', (tester) async {
    await tester.pumpWidget(
      view(
        FrostTable(
          columns: [FrostTableColumn<int>(label: 'Name', cell: (_, i) => Text('Item $i'), text: (i) => 'Name $i', primary: true)],
          rows: const [0, 1],
        ),
        width: 350,
      ),
    );
    final row = find.byType(FrostListRow).first;
    expect(tester.widget<FrostListRow>(row).subtitle, isNull);
    expect(tester.getSize(row).height, 36);
  });

  group('automatic column widths', () {
    List<FrostTableColumn<int>> files({void Function(int)? measured}) => [
      FrostTableColumn(label: 'Name', primary: true, text: (i) => 'Name $i', cell: (_, i) => FrostText('Name $i')),
      FrostTableColumn(
        label: 'State',
        text: (i) {
          measured?.call(i);
          return 'Completed';
        },
        cell: (_, i) => const FrostText('Completed'),
      ),
      FrostTableColumn(label: 'Source', text: (i) => 'collection-$i', cell: (_, i) => FrostText('collection-$i')),
    ];

    double naturalWidth(WidgetTester tester, String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: FrostTypography.of(tester.element(find.byType(FrostTable<int>))).style(FrostTextRole.body)),
        textDirection: TextDirection.ltr,
      )..layout();
      addTearDown(painter.dispose);
      return painter.width;
    }

    void wide(WidgetTester tester) {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('columns take their content first and the primary column the rest', (tester) async {
      wide(tester);
      await tester.pumpWidget(view(FrostTable<int>(columns: files(), rows: const [1, 2]), width: 1200));
      final widths = tester.widget<FrostTableCells>(find.byType(FrostTableCells).at(1)).widths;
      expect(widths[1], greaterThanOrEqualTo(naturalWidth(tester, 'Completed') + FrostGap.related * 2));
      expect(widths[2], greaterThanOrEqualTo(naturalWidth(tester, 'collection-2') + FrostGap.related * 2));
      expect(widths.reduce((a, b) => a + b), 1200);
      expect(widths[0], greaterThan(widths[1] + widths[2]));
      // A whole word on one line: the cell is as tall as a one-word cell.
      expect(tester.getSize(find.text('Completed').first).height, tester.getSize(find.text('Name 1')).height);
      expect(tester.getSize(find.text('collection-1')).height, tester.getSize(find.text('Name 1')).height);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a cell without room ends in an ellipsis instead of breaking a word', (tester) async {
      await tester.pumpWidget(
        view(
          FrostTable<int>(
            columns: [
              ...files(),
              FrostTableColumn(
                label: 'Path',
                text: (i) => 'a-very-long-unbroken-path-component-$i',
                cell: (_, i) => FrostText('a-very-long-unbroken-path-component-$i'),
              ),
            ],
            rows: const [1],
          ),
          width: 620,
        ),
      );
      final widths = tester.widget<FrostTableCells>(find.byType(FrostTableCells).at(1)).widths;
      expect(widths.reduce((a, b) => a + b), 620);
      final long = tester.renderObject<RenderParagraph>(find.text('a-very-long-unbroken-path-component-1'));
      expect(long.didExceedMaxLines, isTrue);
      expect(long.size.height, tester.getSize(find.text('Name 1')).height);
      expect(tester.takeException(), isNull);
    });

    testWidgets('explicit widths stay as given', (tester) async {
      wide(tester);
      final columns = files();
      columns[1] = FrostTableColumn(label: 'State', width: 150, text: (i) => 'Completed', cell: (_, i) => const FrostText('Completed'));
      await tester.pumpWidget(view(FrostTable<int>(columns: columns, rows: const [1]), width: 1200));
      expect(tester.widget<FrostTableCells>(find.byType(FrostTableCells).at(1)).widths[1], 150);
    });

    testWidgets('a long lazy table is sized from its first rows only', (tester) async {
      wide(tester);
      var farthest = 0;
      await tester.pumpWidget(
        view(
          FrostTable<int>(
            columns: files(measured: (i) => farthest = math.max(farthest, i)),
            rows: List.generate(100000, (i) => i),
          ),
          width: 1200,
        ),
      );
      expect(farthest, lessThan(300));
      expect(tester.takeException(), isNull);
    });
  });
  for (final (width, scale) in [(800.0, 1.0), (800.0, 2.0), (400.0, 1.0), (400.0, 2.0)]) {
    testWidgets('a shrink-wrapped table runs with page text at width $width scale $scale', (tester) async {
      await tester.pumpWidget(
        view(
          CustomScrollView(
            slivers: [
              SliverList.list(
                children: [
                  const Text('Before'),
                  FrostTable<int>(columns: columns(), rows: const [0, 1, 2], shrinkWrap: true),
                  const Text('After'),
                ],
              ),
            ],
          ),
          width: width,
          scale: scale,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final table = tester.getRect(find.byType(FrostTable<int>));
      final last = tester.getRect(find.textContaining(width < 600 ? 'Name 2' : 'Item 2'));
      expect(tester.getRect(find.text('Before')).bottom, table.top);
      expect(tester.getRect(find.text('After', skipOffstage: false)).top, table.bottom);
      expect(table.bottom, greaterThanOrEqualTo(last.bottom));
      expect(table.bottom - last.bottom, lessThan(last.height + 24));
      for (final row in [0, 1]) {
        expect(find.textContaining(width < 600 ? 'Name $row' : 'Item $row'), findsOneWidget);
      }
    });
  }
}
