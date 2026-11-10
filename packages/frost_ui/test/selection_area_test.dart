import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'support.dart';

const _first = 'First paragraph of the chapter';
const _second = 'Second paragraph of the chapter';

void main() {
  late List<String?> copied;
  setUp(() => copied = []);

  Future<void> show(WidgetTester tester, {required TargetPlatform platform, ValueChanged<SelectedContent?>? onChanged, Key? key}) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map<Object?, Object?>)['text'] as String?);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(
      frostTestApp(
        platform: platform,
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            child: FrostSelectionArea(
              key: key,
              onSelectionChanged: onChanged,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_first, style: TextStyle(fontSize: 18)),
                  Text(_second, style: TextStyle(fontSize: 18)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('touch long press shows the Frost menu, whose copy takes text across paragraphs', (tester) async {
    await show(tester, platform: TargetPlatform.android);
    await tester.longPress(find.text(_first));
    await tester.pumpAndSettle();
    final copy = find.widgetWithText(FrostButton, 'Copy');
    expect(copy, findsOneWidget);
    await tester.tap(find.widgetWithText(FrostButton, 'Select all'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FrostButton, 'Copy'));
    await tester.pumpAndSettle();
    expect(copied.single, allOf(contains(_first), contains(_second)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('pointer drag selects across paragraphs, copies with the shortcut, reports and clears', (tester) async {
    final key = GlobalKey<FrostSelectionAreaState>();
    final changes = <SelectedContent?>[];
    await show(tester, platform: TargetPlatform.windows, onChanged: changes.add, key: key);
    Future<void> drag() async {
      final from = tester.getTopLeft(find.text(_first)) + const Offset(1, 9);
      final to = tester.getBottomRight(find.text(_second)) - const Offset(1, 9);
      final gesture = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
      await tester.pump();
      await gesture.moveTo(to);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
    }

    await drag();
    expect(changes.last?.plainText, allOf(contains(_first), contains(_second)));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(copied.single, allOf(contains(_first), contains(_second)));

    key.currentState!.clearSelection();
    await tester.pump();
    expect(changes.last, isNull);

    await drag();
    expect(changes.last, isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(changes.last, isNull);
    expect(tester.takeException(), isNull);
  });

  for (final throughAction in [true, false]) {
    testWidgets('Escape clears a selection first, then reaches the page; page uses ${throughAction ? 'a dismiss action' : 'a key handler'}', (tester) async {
      var page = 0;
      final area = FrostSelectionArea(child: const Text(_first));
      Widget host = Align(alignment: Alignment.topLeft, child: SizedBox(width: 400, child: area));
      host = throughAction
          ? Shortcuts(
              shortcuts: const {SingleActivator(LogicalKeyboardKey.escape): DismissIntent()},
              child: Actions(actions: {DismissIntent: CallbackAction<DismissIntent>(onInvoke: (_) => page++)}, child: host),
            )
          : Focus(
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.escape) return KeyEventResult.ignored;
                page++;
                return KeyEventResult.handled;
              },
              child: host,
            );
      await tester.pumpWidget(frostTestApp(platform: TargetPlatform.windows, host));
      final from = tester.getTopLeft(find.text(_first)) + const Offset(1, 9);
      final gesture = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
      await tester.pump();
      await gesture.moveTo(tester.getBottomRight(find.text(_first)) - const Offset(1, 9));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(page, 0, reason: 'the first Escape clears the selection');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(page, 1, reason: 'with nothing selected Escape reaches the page');
      expect(tester.takeException(), isNull);
    });
  }
}
