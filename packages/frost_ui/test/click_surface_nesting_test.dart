import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/primitives/_click_feedback.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

const _inner = ValueKey('inner');

Widget _card({VoidCallback? onTap, VoidCallback? onInnerTap, bool innerEnabled = true}) => frostTestApp(
  Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 400,
      child: FrostClickSurface(
        onTap: onTap ?? () {},
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                key: _inner,
                width: 100,
                height: 100,
                child: FrostClickSurface(onTap: innerEnabled ? (onInnerTap ?? () {}) : null, child: const SizedBox.expand()),
              ),
              const FrostText('selectable text here', selectable: true),
            ],
          ),
        ),
      ),
    ),
  ),
  platform: TargetPlatform.windows,
);

Set<WidgetState> _outer(WidgetTester tester) => tester.widgetList<FrostClickFeedbackVisual>(find.byType(FrostClickFeedbackVisual)).first.states;

Future<TestGesture> _mouseAt(WidgetTester tester, Offset position) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  addTearDown(mouse.removePointer);
  await mouse.addPointer(location: Offset.zero);
  await mouse.moveTo(position);
  await tester.pump();
  return mouse;
}

void main() {
  testWidgets('the outer surface is hovered over its own blank area', (tester) async {
    await tester.pumpWidget(_card());
    await _mouseAt(tester, const Offset(10, 10));
    expect(_outer(tester), {WidgetState.hovered});
  });

  testWidgets('hovering an inner control leaves the outer surface alone', (tester) async {
    await tester.pumpWidget(_card());
    await _mouseAt(tester, tester.getCenter(find.byKey(_inner)));
    expect(_outer(tester), isEmpty);
  });

  for (final enabled in [true, false]) {
    testWidgets('pressing an inner control shows only on it (enabled: $enabled)', (tester) async {
      var outer = 0, inner = 0;
      await tester.pumpWidget(_card(onTap: () => outer++, onInnerTap: () => inner++, innerEnabled: enabled));
      final mouse = await _mouseAt(tester, tester.getCenter(find.byKey(_inner)));
      await mouse.down(tester.getCenter(find.byKey(_inner)));
      await tester.pump();
      expect(_outer(tester), isEmpty);
      await mouse.up();
      await tester.pump(const Duration(milliseconds: 400));
      expect(outer, 0);
      expect(inner, enabled ? 1 : 0);
    });
  }

  testWidgets('pressing the outer surface still shows on it', (tester) async {
    await tester.pumpWidget(_card());
    final mouse = await _mouseAt(tester, const Offset(10, 10));
    await mouse.down(const Offset(10, 10));
    await tester.pump();
    expect(_outer(tester), contains(WidgetState.pressed));
    await mouse.up();
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('selectable text keeps the outer surface hovered with a text cursor', (tester) async {
    await tester.pumpWidget(_card());
    await _mouseAt(tester, tester.getCenter(find.byType(SelectableText)));
    expect(_outer(tester), {WidgetState.hovered});
    expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.text);
  });

  testWidgets('dragging across selectable text does not tap the outer surface', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_card(onTap: () => taps++));
    final text = tester.getRect(find.byType(SelectableText));
    final mouse = await tester.startGesture(text.centerLeft + const Offset(2, 0), kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 40));
    for (var step = 1; step <= 6; step++) {
      await mouse.moveBy(const Offset(12, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await mouse.up();
    await tester.pump(const Duration(milliseconds: 400));
    expect(taps, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an editable field stays an inner control', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      frostTestApp(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            child: FrostClickSurface(
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: FrostTextField(controller: controller, placeholder: 'Name'),
              ),
            ),
          ),
        ),
        platform: TargetPlatform.windows,
      ),
    );
    await _mouseAt(tester, tester.getCenter(find.byType(EditableText)));
    expect(_outer(tester), isEmpty);
  });
}
