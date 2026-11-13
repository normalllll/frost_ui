import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

void main() {
  late List<bool> pressed;
  late int taps;
  setUp(() {
    pressed = [];
    taps = 0;
  });

  Widget surface(int index) => SizedBox(
    height: 120,
    child: FrostClickSurface(
      onTap: () => taps++,
      onPressedChange: index == 1 ? pressed.add : null,
      child: Center(child: Text('card $index')),
    ),
  );

  testWidgets('a vertical scroll that starts on a surface clears its press at once', (tester) async {
    await tester.pumpWidget(frostTestApp(ListView(children: [for (var i = 0; i < 12; i++) surface(i)])));
    final gesture = await tester.startGesture(tester.getCenter(find.text('card 1')));
    await tester.pump(const Duration(milliseconds: 10));
    expect(pressed, [true]);
    // Faster than the press timeout, so tap-down is never sent.
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(const Offset(0, -12));
      await tester.pump(const Duration(milliseconds: 8));
    }
    expect(pressed, [true, false]);
    await gesture.moveBy(const Offset(0, -40));
    await tester.pump();
    expect(pressed, [true, false]);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(pressed, [true, false]);
    expect(taps, 0);
  });

  testWidgets('a sideways swipe that starts on a surface clears its press at once', (tester) async {
    await tester.pumpWidget(frostTestApp(PageView(children: [for (var i = 0; i < 3; i++) surface(i == 0 ? 1 : 0)])));
    final gesture = await tester.startGesture(tester.getCenter(find.text('card 1')));
    await tester.pump(const Duration(milliseconds: 10));
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump(const Duration(milliseconds: 8));
    expect(pressed, [true, false]);
    await gesture.moveBy(const Offset(-200, 0));
    await tester.pump();
    expect(pressed, [true, false]);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 0);
  });

  testWidgets('a drag after the press timeout clears the press too', (tester) async {
    await tester.pumpWidget(frostTestApp(ListView(children: [for (var i = 0; i < 12; i++) surface(i)])));
    final gesture = await tester.startGesture(tester.getCenter(find.text('card 1')));
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.moveBy(const Offset(0, -40));
    await tester.pump();
    expect(pressed, [true, false]);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 0);
  });

  testWidgets('a cancelled pointer clears the press', (tester) async {
    await tester.pumpWidget(frostTestApp(ListView(children: [for (var i = 0; i < 12; i++) surface(i)])));
    final gesture = await tester.startGesture(tester.getCenter(find.text('card 1')));
    await tester.pump(const Duration(milliseconds: 10));
    await gesture.cancel();
    await tester.pump();
    expect(pressed, [true, false]);
    expect(taps, 0);
  });

  testWidgets('a short press and release still shows the press and taps', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(frostTestApp(ListView(children: [for (var i = 0; i < 12; i++) surface(i)])));
    final gesture = await tester.startGesture(tester.getCenter(find.text('card 1')));
    await tester.pump(const Duration(milliseconds: 40));
    expect(pressed, [true]);
    await gesture.up();
    await tester.pump();
    expect(pressed, [true, false]);
    expect(taps, 1);
    expect(tester.getSemantics(find.text('card 1')), matchesSemantics(label: 'card 1', hasTapAction: true, isFocusable: true, hasFocusAction: true));
    handle.dispose();
  });
}
