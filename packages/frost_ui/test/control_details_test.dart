import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_calendar.dart';
import 'package:frost_ui/src/controls/_field_frame.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';

import 'support.dart';

Future<void> _click(WidgetTester tester, Offset at) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: at);
  await gesture.down(at);
  await gesture.up();
  await gesture.removePointer();
}

Widget _app(Widget child, {bool use24Hours = false}) => frostTestApp(
  Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: use24Hours),
      child: Material(
        child: Center(child: SizedBox(width: 400, child: child)),
      ),
    ),
  ),
);

String _segment(WidgetTester tester, int index) => tester.widget<EditableText>(find.byType(EditableText).at(index)).controller.text;

void main() {
  group('number field', () {
    Finder editor() => find.byType(EditableText);
    Finder step(String label) => find.bySemanticsLabel(label);

    Future<List<num>> pumpField(WidgetTester tester, {required num value, int decimals = 0, bool accepts = true, num max = 100}) async {
      final changes = <num>[];
      var current = value;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) => FrostNumberField(
              value: current,
              max: max,
              decimals: decimals,
              label: 'Amount',
              onChanged: (next) {
                changes.add(next);
                if (accepts) setState(() => current = next);
              },
            ),
          ),
        ),
      );
      return changes;
    }

    for (final (label, expected) in [('L.increment', 51), ('L.decrement', 49)]) {
      testWidgets('the $label button steps from the number just typed', (tester) async {
        final semantics = tester.ensureSemantics();
        final changes = await pumpField(tester, value: 10);
        await tester.tap(editor());
        await tester.pump();
        await tester.enterText(editor(), '50');
        await tester.pump();
        await _click(tester, tester.getCenter(step(label)));
        await tester.pump();
        expect(changes, [expected]);
        expect(_segment(tester, 0), '$expected');
        semantics.dispose();
      });
    }

    testWidgets('focusing and leaving without typing does not change the value', (tester) async {
      final changes = await pumpField(tester, value: 7.5);
      await tester.tap(editor());
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(changes, isEmpty);
      expect(_segment(tester, 0), '7.5');
    });

    testWidgets('a typed value the caller refuses goes back to the caller value', (tester) async {
      final changes = await pumpField(tester, value: 10, accepts: false);
      await tester.tap(editor());
      await tester.pump();
      await tester.enterText(editor(), '50');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(changes, [50]);
      expect(_segment(tester, 0), '10');
    });

    testWidgets('a typed value the caller takes stays', (tester) async {
      final changes = await pumpField(tester, value: 10);
      await tester.tap(editor());
      await tester.pump();
      await tester.enterText(editor(), '50');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(changes, [50]);
      expect(_segment(tester, 0), '50');
    });
  });

  group('time picker', () {
    Future<List<TimeOfDay?>> pumpPicker(WidgetTester tester, {TimeOfDay? value, bool accepts = true, int minuteStep = 1, bool use24Hours = false}) async {
      final changes = <TimeOfDay?>[];
      var current = value;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) => FrostTimePicker(
              value: current,
              label: 'Time',
              minuteStep: minuteStep,
              onChanged: (next) {
                changes.add(next);
                if (accepts) setState(() => current = next);
              },
            ),
          ),
          use24Hours: use24Hours,
        ),
      );
      return changes;
    }

    testWidgets('a time the caller refuses goes back to the caller value', (tester) async {
      final changes = await pumpPicker(tester, value: const TimeOfDay(hour: 9, minute: 30), accepts: false, use24Hours: true);
      await tester.tap(find.byType(EditableText).first);
      await tester.pump();
      await tester.enterText(find.byType(EditableText).first, '10');
      await tester.pumpAndSettle();
      expect(changes, [const TimeOfDay(hour: 10, minute: 30)]);
      expect(_segment(tester, 0), '09');
    });

    testWidgets('a time the caller takes stays', (tester) async {
      await pumpPicker(tester, value: const TimeOfDay(hour: 9, minute: 30), use24Hours: true);
      await tester.tap(find.byType(EditableText).first);
      await tester.pump();
      await tester.enterText(find.byType(EditableText).first, '10');
      await tester.pumpAndSettle();
      expect(_segment(tester, 0), '10');
    });

    testWidgets('an hour outside a 12-hour clock marks the field invalid', (tester) async {
      final changes = await pumpPicker(tester, value: const TimeOfDay(hour: 9, minute: 30));
      FrostFieldFrame frame() => tester.widget<FrostFieldFrame>(find.byType(FrostFieldFrame));
      expect(frame().invalid, isFalse);
      await tester.tap(find.byType(EditableText).first);
      await tester.pump();
      await tester.enterText(find.byType(EditableText).first, '0');
      await tester.pumpAndSettle();
      expect(changes, isEmpty);
      expect(_segment(tester, 0), '0');
      expect(frame().invalid, isTrue);
      await tester.enterText(find.byType(EditableText).first, '10');
      await tester.pumpAndSettle();
      expect(frame().invalid, isFalse);
      expect(changes, [const TimeOfDay(hour: 10, minute: 30)]);
    });

    for (final (key, expected) in [
      (LogicalKeyboardKey.arrowDown, ['45', '30', '15', '00']),
      (LogicalKeyboardKey.arrowUp, ['00', '15', '30', '45']),
    ]) {
      testWidgets('minute steps from empty stay on the grid with ${key.keyLabel}', (tester) async {
        await pumpPicker(tester, minuteStep: 15, use24Hours: true);
        await tester.tap(find.byType(EditableText).at(1));
        await tester.pump();
        final seen = <String>[];
        for (var i = 0; i < 4; i++) {
          await tester.sendKeyEvent(key);
          await tester.pump();
          seen.add(_segment(tester, 1));
        }
        expect(seen, expected);
      });
    }
  });

  testWidgets('a second date before the first ends the range and enables Apply', (tester) async {
    DateTimeRange? applied;
    await tester.pumpWidget(
      FrostDateClock(
        today: DateTime(2026, 11, 20),
        child: _app(
          FrostDateRangePicker(
            value: null,
            label: 'Range',
            firstDate: DateTime(2026, 11),
            lastDate: DateTime(2026, 11, 30),
            onChanged: (range) => applied = range,
          ),
        ),
      ),
    );
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pump();
    await tester.tap(find.byType(FrostDateRangePicker));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15').first);
    await tester.pump();
    await tester.tap(find.text('10').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('L.apply'));
    await tester.pumpAndSettle();
    expect(applied, DateTimeRange(start: DateTime(2026, 11, 10), end: DateTime(2026, 11, 15)));
  });

  testWidgets('the date picker clear button grows in like the shared button', (tester) async {
    late StateSetter update;
    DateTime? value;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return FrostDatePicker(value: value, label: 'Date', clearable: true, onChanged: (_) {});
          },
        ),
      ),
    );
    final icon = find.descendant(of: find.byType(FrostDatePicker), matching: find.byType(FrostPresence));
    expect(tester.getSize(icon).width, 0);
    update(() => value = DateTime(2026, 11, 2));
    await tester.pump();
    final width = tester.getSize(icon).width;
    expect(width, lessThan(8));
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.getSize(icon).width, greaterThan(width));
    await tester.pumpAndSettle();
    expect(tester.getSize(icon).width, greaterThanOrEqualTo(28));
  });

  group('cancellable button', () {
    Future<({List<int> counts, Finder button})> pumpButton(WidgetTester tester) async {
      final counts = [0, 0];
      FrostActionState state = FrostActionState.idle;
      await tester.pumpWidget(
        frostTestApp(
          Center(
            child: StatefulBuilder(
              builder: (context, setState) => FrostButton(
                label: 'Save',
                state: state,
                onPressed: () {
                  counts[0]++;
                  setState(
                    () => state = FrostActionState.running(
                      onCancel: () {
                        counts[1]++;
                        setState(() => state = FrostActionState.idle);
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      return (counts: counts, button: find.byType(FrostButton));
    }

    testWidgets('starting keeps the width from the first frame on', (tester) async {
      final (:counts, :button) = await pumpButton(tester);
      final width = tester.getSize(button).width;
      await _click(tester, tester.getCenter(button));
      await tester.pump();
      expect(counts, [1, 0]);
      for (var i = 0; i < 40; i++) {
        expect(tester.getSize(button).width, width);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    });

    for (final gap in [40, 120, 300]) {
      testWidgets('a double click $gap ms apart starts and does not cancel', (tester) async {
        final (:counts, :button) = await pumpButton(tester);
        final at = tester.getCenter(button);
        await _click(tester, at);
        await tester.pump();
        await tester.pump(Duration(milliseconds: gap));
        await _click(tester, at);
        await tester.pump();
        expect(counts, [1, 0]);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 2));
      });
    }

    testWidgets('a later press cancels and the button then reads as cancel', (tester) async {
      final semantics = tester.ensureSemantics();
      final (:counts, :button) = await pumpButton(tester);
      final at = tester.getCenter(button);
      await _click(tester, at);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.getSemantics(button).label, 'L.cancel');
      await _click(tester, at);
      await tester.pump();
      expect(counts, [1, 1]);
      await tester.pump(const Duration(seconds: 2));
      semantics.dispose();
    });
  });

  for (final (key, expected) in [(LogicalKeyboardKey.pageUp, .75), (LogicalKeyboardKey.pageDown, .25)]) {
    testWidgets('${key.keyLabel} moves a slider whose divisions are wider than a page', (tester) async {
      final changes = <double>[];
      await tester.pumpWidget(_app(FrostSlider(value: .5, divisions: 4, semanticLabel: 'Level', onChanged: changes.add)));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(key);
      await tester.pump();
      expect(changes, [expected]);
    });
  }

  group('reduced motion', () {
    Future<void> pumpReduced(WidgetTester tester, Widget child) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await tester.pumpWidget(_app(child));
    }

    testWidgets('a popover is at its end on the frame it opens', (tester) async {
      await pumpReduced(tester, FrostDatePicker(value: DateTime(2026, 11, 2), label: 'Date', onChanged: (_) {}));
      await tester.tap(find.byType(FrostDatePicker));
      await tester.pump();
      final reveals = tester.widgetList<FrostMaterialReveal>(find.ancestor(of: find.text('November 2026'), matching: find.byType(FrostMaterialReveal)));
      expect(reveals, isNotEmpty);
      expect(reveals.map((reveal) => reveal.opacity), everyElement(1));
    });

    testWidgets('a menu is at its end on the frame it opens', (tester) async {
      await pumpReduced(
        tester,
        FrostPicker<String>.menu(
          options: const [FrostPickerOption(value: 'a', label: 'Alpha')],
          value: 'a',
          label: 'Pick',
          onChanged: (_) {},
        ),
      );
      await tester.tap(find.byType(FrostPicker<String>));
      await tester.pump();
      final reveals = tester.widgetList<FrostMaterialReveal>(find.ancestor(of: find.text('Alpha').last, matching: find.byType(FrostMaterialReveal)));
      expect(reveals, isNotEmpty);
      expect(reveals.map((reveal) => reveal.opacity), everyElement(1));
    });
  });
}
