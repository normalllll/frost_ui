import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/foundation/_focus_modality.dart';
import 'support.dart';

void main() {
  testWidgets('mouse focus keeps activation without a ring and Tab reveals keyboard focus', (tester) async {
    final previous = FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = previous);
    var calls = 0;
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FrostButton(label: 'Original', onPressed: () => calls++),
              FrostButton(label: 'Copy', onPressed: () => calls++),
            ],
          ),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(1, 1));
    final original = find.text('Original');
    await mouse.moveTo(tester.getCenter(original));
    await mouse.down(tester.getCenter(original));
    await mouse.up();
    await tester.pumpAndSettle();
    Finder rings() => find.byWidgetPredicate((w) => w is CustomPaint && w.foregroundPainter?.runtimeType.toString() == 'FrostFocusOutlinePainter');
    expect(calls, 1);
    expect(rings(), findsNothing, reason: 'Pointer-acquired focus is not a keyboard focus highlight');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(rings(), findsOneWidget);
    await mouse.down(tester.getCenter(original));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(rings(), findsNothing);
    expect(calls, 2);
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  group('after a pointer press', () {
    Finder rings() => find.byWidgetPredicate((w) => w is CustomPaint && w.foregroundPainter?.runtimeType.toString() == 'FrostFocusOutlinePainter');

    Future<TestGesture> pressed(WidgetTester tester, {Widget? extra}) async {
      final previous = FocusManager.instance.highlightStrategy;
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = previous);
      await tester.pumpWidget(
        frostTestApp(
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FrostTitleMenu(title: 'Trigger', entries: [FrostMenuAction('Item', onSelected: () {})]),
                ?extra,
              ],
            ),
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(1, 1));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('Trigger')));
      await mouse.down(tester.getCenter(find.text('Trigger')));
      await mouse.up();
      await tester.pumpAndSettle();
      return mouse;
    }

    for (final (name, key) in [
      ('Escape', LogicalKeyboardKey.escape),
      ('a letter', LogicalKeyboardKey.keyA),
      ('a modifier', LogicalKeyboardKey.shiftLeft),
      ('Alt', LogicalKeyboardKey.altLeft),
      ('Enter', LogicalKeyboardKey.enter),
    ]) {
      testWidgets('$name does not bring the ring back', (tester) async {
        await pressed(tester);
        await tester.sendKeyEvent(key);
        await tester.pumpAndSettle();
        expect(rings(), findsNothing);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
        await tester.pumpAndSettle();
        expect(rings(), findsNothing);
      });
    }

    testWidgets('a menu closed by selection or from outside leaves no ring', (tester) async {
      final mouse = await pressed(tester);
      await mouse.moveTo(tester.getCenter(find.text('Item')));
      await mouse.down(tester.getCenter(find.text('Item')));
      await mouse.up();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pumpAndSettle();
      expect(find.text('Item'), findsNothing);
      expect(rings(), findsNothing);

      await mouse.moveTo(tester.getCenter(find.text('Trigger')));
      await mouse.down(tester.getCenter(find.text('Trigger')));
      await mouse.up();
      await tester.pumpAndSettle();
      await mouse.moveTo(const Offset(2, 2));
      await mouse.down(const Offset(2, 2));
      await mouse.up();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pumpAndSettle();
      expect(find.text('Item'), findsNothing);
      expect(rings(), findsNothing);
    });

    testWidgets('Alt+Tab does not bring the ring back; Tab does', (tester) async {
      await pressed(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();
      expect(FrostInputModality.instance.keyboard, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(FrostInputModality.instance.keyboard, isTrue);
    });

    testWidgets('arrows bring the ring back unless an editor has focus', (tester) async {
      final controller = TextEditingController(text: 'text');
      addTearDown(controller.dispose);
      final mouse = await pressed(tester, extra: SizedBox(width: 200, child: FrostTextField(controller: controller)));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await mouse.moveTo(tester.getCenter(find.byType(EditableText)));
      await mouse.down(tester.getCenter(find.byType(EditableText)));
      await mouse.up();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(FrostInputModality.instance.keyboard, isFalse);
      await mouse.moveTo(tester.getCenter(find.text('Trigger')));
      await mouse.down(tester.getCenter(find.text('Trigger')));
      await mouse.up();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(FrostInputModality.instance.keyboard, isTrue);
    });
  });

  testWidgets('a menu opened from the keyboard returns a ringed focus to its trigger', (tester) async {
    final previous = FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = previous);
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: FrostTitleMenu(title: 'Trigger', entries: [FrostMenuAction('Item', onSelected: () {})]),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    final trigger = FocusManager.instance.primaryFocus!;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Item'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Item'), findsNothing);
    expect(trigger.hasPrimaryFocus, isTrue);
    expect(find.byWidgetPredicate((w) => w is CustomPaint && w.foregroundPainter?.runtimeType.toString() == 'FrostFocusOutlinePainter'), findsOneWidget);
  });
}
