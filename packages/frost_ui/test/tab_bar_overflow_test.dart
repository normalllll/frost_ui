import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/primitives/_scroll_edge_fade.dart';
import 'package:material_ui/material_ui.dart' show Material;

import 'support.dart';

Widget _bar(int count, {TargetPlatform platform = TargetPlatform.windows, double width = 420}) => frostTestApp(
  Material(
    child: Center(
      child: SizedBox(
        width: width,
        child: FrostDefaultTabController(
          length: count,
          child: FrostTabBar(
            scrollable: true,
            tabs: [for (var i = 0; i < count; i++) FrostTab(label: 'Tab $i', secondaryLabel: '4')],
          ),
        ),
      ),
    ),
  ),
  platform: platform,
);

Finder _step(String label) => find.descendant(of: find.byType(FrostTabBar), matching: find.bySemanticsLabel(label));
bool _enabled(WidgetTester tester, String label) =>
    tester.widget<FrostButton>(find.ancestor(of: _step(label), matching: find.byType(FrostButton)).first).onPressed != null;
bool _fades(WidgetTester tester) => tester.widget<FrostScrollEdgeFade>(find.byType(FrostScrollEdgeFade)).active;
ScrollPosition _position(WidgetTester tester) => tester.widget<FrostScrollEdgeFade>(find.byType(FrostScrollEdgeFade)).controller.position;

void main() {
  testWidgets('an overflowing bar fades and offers a step towards each side that hides tabs, and a mouse reaches the last tab', (tester) async {
    await tester.pumpWidget(_bar(17));
    await tester.pumpAndSettle();
    expect(_fades(tester), isTrue);
    expect(_position(tester).extentBefore, 0);
    expect(_position(tester).extentAfter, greaterThan(0));
    expect(_enabled(tester, 'L.previous'), isFalse, reason: 'nothing lies before the start');
    expect(_enabled(tester, 'L.next'), isTrue);

    await tester.tap(_step('L.next'), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(_position(tester).extentBefore, greaterThan(0));
    expect(_position(tester).extentAfter, greaterThan(0));
    expect(_enabled(tester, 'L.previous'), isTrue);
    expect(_enabled(tester, 'L.next'), isTrue);

    for (var i = 0; i < 20 && _enabled(tester, 'L.next'); i++) {
      await tester.tap(_step('L.next'), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
    }
    expect(_position(tester).extentAfter, 0);
    expect(_enabled(tester, 'L.previous'), isTrue);
    expect(_enabled(tester, 'L.next'), isFalse, reason: 'nothing lies past the end');

    await tester.tap(find.text('Tab 16'), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(FrostDefaultTabController.of(tester.element(find.text('Tab 16'))).index, 16);
    expect(tester.takeException(), isNull);
  });

  testWidgets('without a mouse an overflowing bar fades its edges and adds no buttons', (tester) async {
    await tester.pumpWidget(_bar(17, platform: TargetPlatform.android));
    await tester.pumpAndSettle();
    expect(_fades(tester), isTrue);
    expect(find.descendant(of: find.byType(FrostTabBar), matching: find.byType(FrostButton)), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a touch after paging by mouse drops the buttons and keeps the strip where it was', (tester) async {
    await tester.pumpWidget(_bar(17));
    await tester.pumpAndSettle();
    await tester.tap(_step('L.next'), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    final offset = _position(tester).pixels;
    expect(offset, greaterThan(0));
    await tester.tap(find.text('Tab 6'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.descendant(of: find.byType(FrostTabBar), matching: find.byType(FrostButton)), findsNothing);
    expect(_position(tester).pixels, offset);
    await tester.pumpAndSettle();
  });

  testWidgets('a scrollable bar whose tabs fit shows no overflow cue', (tester) async {
    await tester.pumpWidget(_bar(3));
    await tester.pumpAndSettle();
    expect(_fades(tester), isFalse);
    expect(find.descendant(of: find.byType(FrostTabBar), matching: find.byType(FrostButton)), findsNothing);
  });
}
