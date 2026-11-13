import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/overlays/_anchored_panel_layout.dart';
import 'package:frost_ui/src/overlays/_popover_surface.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

/// App content: a text row above a grid of cards whose column count follows
/// the width the dropdown gives it.
Widget _content(List<String> calls, {int cards = 6, bool keepsOpen = false}) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  mainAxisSize: MainAxisSize.min,
  children: [
    FrostSearchSection(
      title: 'History',
      children: [FrostSearchSuggestionRow(label: 'history', onSelected: () => calls.add('history'))],
    ),
    FrostSearchSection(
      title: 'Tags',
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = math.max(1, constraints.maxWidth ~/ 100);
            final width = constraints.maxWidth / columns;
            return Wrap(
              children: [
                for (var i = 0; i < cards; i++)
                  SizedBox(
                    key: ValueKey('card $i'),
                    width: width,
                    height: 60,
                    child: FrostSearchOption(
                      semanticLabel: 'tag $i',
                      keepsOpen: keepsOpen,
                      onSelected: () => calls.add('tag $i'),
                      child: Center(child: Text('tag $i')),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  ],
);

Finder _card(int i) => find.byKey(ValueKey('card $i'));
Finder _panel() => find.byType(FrostPopoverSurface);

void main() {
  late TextEditingController controller;
  late FocusNode focus;
  late List<String> calls, submitted;
  setUp(() {
    controller = TextEditingController(text: 'ab');
    focus = FocusNode();
    calls = [];
    submitted = [];
  });
  tearDown(() {
    controller.dispose();
    focus.dispose();
  });

  for (final caption in [false, true]) {
    final name = caption ? 'FrostCaptionSearch' : 'FrostSearchInput.suggesting';

    Widget search(Widget? content, double width) => SizedBox(
      width: width,
      height: caption ? 32 : null,
      child: caption
          ? FrostCaptionSearch(controller: controller, focusNode: focus, placeholder: 'Search', onSubmitted: submitted.add, content: content)
          : FrostSearchInput.suggesting(
              controller: controller,
              focusNode: focus,
              placeholder: 'Search',
              onSubmitted: submitted.add,
              placement: FrostSuggestionPlacement.overlay,
              content: content,
            ),
    );

    late StateSetter update;
    var width = 360.0;
    var hidden = false;
    Widget? content;

    Future<void> pump(WidgetTester tester, Widget? initial, {double initialWidth = 360}) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 600);
      addTearDown(tester.view.reset);
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      width = initialWidth;
      hidden = false;
      content = initial;
      await tester.pumpWidget(
        frostTestApp(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Align(
                alignment: Alignment.topCenter,
                child: TickerMode(enabled: !hidden, child: search(content, width)),
              );
            },
          ),
        ),
      );
      focus.requestFocus();
      await tester.pumpAndSettle();
    }

    String hint(WidgetTester tester) => tester.getSemantics(find.byType(EditableText)).getSemanticsData().hint;

    Future<void> key(WidgetTester tester, LogicalKeyboardKey key) async {
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
    }

    testWidgets('$name: App content keeps its layout and its grid reflows with the width', (tester) async {
      await pump(tester, _content(calls));
      expect(_panel(), findsOneWidget);
      final panel = tester.getRect(_panel());
      final row = tester.getRect(find.byType(FrostListRow));
      expect(row.bottom, lessThanOrEqualTo(tester.getRect(_card(0)).top), reason: 'the text row sits above the grid');
      int columns() => [for (var i = 0; i < 6; i++) tester.getRect(_card(i)).top].where((top) => top == tester.getRect(_card(0)).top).length;
      expect(columns(), 3);
      for (var i = 0; i < 6; i++) {
        final card = tester.getRect(_card(i));
        expect(card.left, greaterThanOrEqualTo(panel.left));
        expect(card.right, lessThanOrEqualTo(panel.right));
      }

      update(() => width = 520);
      await tester.pumpAndSettle();
      expect(columns(), 4, reason: 'the content gets the new panel width');
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name: content taller than the dropdown scrolls inside it and the highlight scrolls into view', (tester) async {
      await pump(tester, _content(calls, cards: 60));
      final panel = tester.getRect(_panel());
      expect(panel.bottom, 600 - frostAnchoredPanelMargin);
      expect(tester.getRect(_card(59)).top, greaterThan(panel.bottom));
      await key(tester, LogicalKeyboardKey.arrowUp);
      expect(hint(tester), contains('tag 59'));
      final last = tester.getRect(_card(59));
      expect(last.bottom, lessThanOrEqualTo(panel.bottom));
      expect(last.top, greaterThanOrEqualTo(panel.top));
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name: arrows move by position, Enter selects, and Left or Right with nothing that way move the caret', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, _content(calls));
      controller.selection = const TextSelection.collapsed(offset: 1);
      await tester.pump();

      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(hint(tester), contains('history 1 / 7'));
      // A single column: nothing beside the row, so the caret moves.
      await key(tester, LogicalKeyboardKey.arrowRight);
      expect(controller.selection, const TextSelection.collapsed(offset: 2));
      expect(hint(tester), contains('history'));
      await key(tester, LogicalKeyboardKey.arrowLeft);
      expect(controller.selection, const TextSelection.collapsed(offset: 1));

      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(hint(tester), contains('tag 0 2 / 7'), reason: 'a full-width row goes down to the first card');
      await key(tester, LogicalKeyboardKey.arrowRight);
      expect(hint(tester), contains('tag 1 3 / 7'));
      expect(controller.selection, const TextSelection.collapsed(offset: 1), reason: 'the grid took Right');
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(hint(tester), contains('tag 4 6 / 7'), reason: 'down keeps the column');
      await key(tester, LogicalKeyboardKey.arrowLeft);
      expect(hint(tester), contains('tag 3'));
      await key(tester, LogicalKeyboardKey.arrowLeft);
      expect(hint(tester), contains('tag 3'), reason: 'nothing lies left of the first column');
      expect(controller.selection, const TextSelection.collapsed(offset: 0));
      await key(tester, LogicalKeyboardKey.arrowUp);
      expect(hint(tester), contains('tag 0'));
      await key(tester, LogicalKeyboardKey.arrowUp);
      expect(hint(tester), contains('history'));
      await key(tester, LogicalKeyboardKey.arrowUp);
      expect(hint(tester), isNot(contains('history')), reason: 'up from the top clears the highlight');
      expect(_panel(), findsOneWidget);

      await key(tester, LogicalKeyboardKey.arrowDown);
      await key(tester, LogicalKeyboardKey.arrowDown);
      await key(tester, LogicalKeyboardKey.arrowRight);
      await key(tester, LogicalKeyboardKey.enter);
      expect(calls, ['tag 1']);
      expect(submitted, isEmpty);
      expect(_panel(), findsNothing, reason: 'an ordinary option closes the dropdown');
      expect(focus.hasFocus, isTrue);
      semantics.dispose();
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name: arrows and Enter stay with the editor while composing', (tester) async {
      await pump(tester, _content(calls));
      controller.value = const TextEditingValue(text: 'ab', selection: TextSelection.collapsed(offset: 2), composing: TextRange(start: 0, end: 2));
      await tester.pump();
      for (final arrow in [LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.arrowUp]) {
        await tester.sendKeyEvent(arrow);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      expect(submitted, isEmpty);
      expect(controller.value.composing, const TextRange(start: 0, end: 2));
      expect(_panel(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name: a keep-open option keeps the text, the caret and focus; Enter then submits and closes', (tester) async {
      await pump(tester, _content(calls, keepsOpen: true));
      controller.selection = const TextSelection.collapsed(offset: 1);
      await tester.pump();
      final value = controller.value;
      await tester.tap(_card(2));
      await tester.pumpAndSettle();
      expect(calls, ['tag 2']);
      expect(controller.value, value);
      expect(focus.hasFocus, isTrue);
      expect(_panel(), findsOneWidget);

      await key(tester, LogicalKeyboardKey.arrowDown);
      await key(tester, LogicalKeyboardKey.arrowDown);
      await key(tester, LogicalKeyboardKey.enter);
      expect(calls, ['tag 2', 'tag 0']);
      expect(controller.value, value);
      expect(_panel(), findsOneWidget);

      await tester.tap(_card(1));
      await tester.pumpAndSettle();
      await key(tester, LogicalKeyboardKey.enter);
      expect(submitted, ['ab']);
      expect(_panel(), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name: Esc and a tap outside close it, null content shows none, hidden content hides it', (tester) async {
      await pump(tester, _content(calls));
      expect(_panel(), findsOneWidget);
      await key(tester, LogicalKeyboardKey.escape);
      expect(_panel(), findsNothing);

      focus.requestFocus();
      controller.text = 'abc';
      await tester.pumpAndSettle();
      expect(_panel(), findsOneWidget);
      await tester.tapAt(const Offset(4, 590));
      await tester.pumpAndSettle();
      expect(_panel(), findsNothing);

      focus.requestFocus();
      await tester.pumpAndSettle();
      expect(_panel(), findsOneWidget);
      update(() => content = null);
      await tester.pumpAndSettle();
      expect(_panel(), findsNothing);
      expect(focus.hasFocus, isTrue);

      update(() => content = _content(calls));
      await tester.pumpAndSettle();
      expect(_panel(), findsOneWidget);
      update(() => hidden = true);
      await tester.pumpAndSettle();
      expect(_panel(), findsNothing);
      expect(controller.text, 'abc');
      update(() => hidden = false);
      await tester.pumpAndSettle();
      expect(_panel(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name: a resting pointer is not a keyboard highlight for the arrows', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, _content(calls));
      controller.selection = const TextSelection.collapsed(offset: 1);
      await tester.pump();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(_card(1)));
      await tester.pumpAndSettle();
      expect(hint(tester), contains('tag 1'));
      await key(tester, LogicalKeyboardKey.arrowRight);
      expect(controller.selection, const TextSelection.collapsed(offset: 2), reason: 'Right goes to the caret');
      await key(tester, LogicalKeyboardKey.arrowLeft);
      expect(controller.selection, const TextSelection.collapsed(offset: 1));
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(hint(tester), contains('history 1 / 7'), reason: 'Down starts at the first option');

      await mouse.moveTo(tester.getCenter(_card(1)) + const Offset(1, 0));
      await tester.pumpAndSettle();
      await key(tester, LogicalKeyboardKey.escape);
      focus.requestFocus();
      controller.text = 'reopen';
      await tester.pumpAndSettle();
      await mouse.moveTo(tester.getCenter(_card(2)));
      await tester.pumpAndSettle();
      expect(hint(tester), contains('tag 2'));
      await key(tester, LogicalKeyboardKey.arrowUp);
      expect(hint(tester), contains('tag 5 7 / 7'), reason: 'Up starts at the last option');
      await mouse.removePointer();
      semantics.dispose();
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name: the announcement follows content that changes in place', (tester) async {
      final semantics = tester.ensureSemantics();
      Widget rows(List<String> labels) => FrostSearchSection(
        children: [for (final label in labels) FrostSearchSuggestionRow(label: label, onSelected: () => calls.add(label))],
      );
      await pump(tester, rows(['a', 'b']));
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(hint(tester), contains('a 1 / 2'));
      // Async results replace the rows without keys: the same options now hold
      // other rows.
      update(() => content = rows(['x', 'y', 'z']));
      await tester.pumpAndSettle();
      expect(hint(tester), contains('x 1 / 3'));
      await key(tester, LogicalKeyboardKey.enter);
      expect(calls, ['x']);
      semantics.dispose();
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name: rows reserve the icon column on the first frame the dropdown shows', (tester) async {
      final row = FrostSearchSection(
        children: [
          FrostSearchSuggestionRow(label: 'plain', onSelected: () {}),
          FrostSearchSuggestionRow(label: 'iconic', icon: const FrostIconData.glyph(Icons.history), onSelected: () {}),
        ],
      );
      await pump(tester, null);
      update(() => content = row);
      await tester.pump();
      expect(_panel(), findsOneWidget);
      expect(tester.getRect(find.text('plain')).left, tester.getRect(find.text('iconic')).left, reason: 'the first frame has the column');
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('plain')).left, tester.getRect(find.text('iconic')).left);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name: Left and Right with a modifier stay with the editor', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, _content(calls));
      controller.selection = const TextSelection.collapsed(offset: 1);
      await tester.pump();
      await key(tester, LogicalKeyboardKey.arrowDown);
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(hint(tester), contains('tag 0'));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await key(tester, LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(hint(tester), contains('tag 0'), reason: 'the highlight stays');
      expect(controller.selection, const TextSelection(baseOffset: 1, extentOffset: 2), reason: 'Shift+Right extends the selection');
      semantics.dispose();
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name: centred options of different heights read as one line', (tester) async {
      final semantics = tester.ensureSemantics();
      Widget option(String label, double height) => FrostSearchOption(
        semanticLabel: label,
        onSelected: () => calls.add(label),
        child: SizedBox(width: 60, height: height),
      );
      await pump(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [option('a', 40), option('b', 20), option('c', 60)]),
            Row(children: [option('d', 30)]),
          ],
        ),
      );
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(hint(tester), contains('a 1 / 4'), reason: 'the first line starts at its start edge, not at its tallest option');
      await key(tester, LogicalKeyboardKey.arrowRight);
      expect(hint(tester), contains('b 2 / 4'));
      await key(tester, LogicalKeyboardKey.arrowRight);
      expect(hint(tester), contains('c 3 / 4'));
      await key(tester, LogicalKeyboardKey.escape);
      focus.requestFocus();
      controller.text = 'reopen';
      await tester.pumpAndSettle();
      await key(tester, LogicalKeyboardKey.arrowUp);
      expect(hint(tester), contains('d 4 / 4'), reason: 'Up without a highlight goes to the last line');
      semantics.dispose();
      expect(tester.takeException(), isNull);
    });
  }
}
