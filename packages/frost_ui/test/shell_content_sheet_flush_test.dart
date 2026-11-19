import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/primitives/_page_outline.dart';
import 'package:material_ui/material_ui.dart';

import 'shell_test.dart' show pageKey, shell;
import 'support.dart';

final _window = GlobalKey();
const _size = Size(1147, 717);

Future<void> _pump(WidgetTester tester, {required Brightness brightness, TextDirection direction = TextDirection.ltr, Size size = _size}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _window,
      child: frostTestApp(
        Directionality(textDirection: direction, child: shell()),
        brightness: brightness,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _sheet => find.byWidgetPredicate((widget) => widget is FrostSurface && widget.role == FrostSurfaceRole.panel);

Future<Color Function(double x, double y)> _capture(WidgetTester tester) async {
  final render = _window.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = (await tester.runAsync(() => render.toImage()))!;
  final bytes = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
  final width = image.width;
  image.dispose();
  return (x, y) {
    final offset = (y.toInt() * width + x.toInt()) * 4;
    return Color.fromARGB(255, bytes.getUint8(offset), bytes.getUint8(offset + 1), bytes.getUint8(offset + 2));
  };
}

void main() {
  for (final direction in TextDirection.values) {
    for (final brightness in Brightness.values) {
      testWidgets('the content sheet meets the window end and bottom with one rounded corner, $direction, $brightness', (tester) async {
        await _pump(tester, brightness: brightness, direction: direction);
        final rtl = direction == TextDirection.rtl;
        final sheet = tester.getRect(_sheet);
        // The collapsed sidebar's rail.
        const rail = 60.0;
        expect(sheet.bottom, _size.height);
        expect(rtl ? sheet.left : sheet.right, rtl ? 0 : _size.width, reason: 'no strip between the sheet and the window end');
        expect(rtl ? sheet.right : sheet.left, rtl ? _size.width - rail : rail, reason: 'the sheet starts right beside the sidebar');

        const corner = Radius.circular(FrostRadius.lg);
        final radius = tester.widget<FrostSurface>(_sheet).borderRadius!.resolve(direction);
        expect(radius, rtl ? const BorderRadius.only(topRight: corner) : const BorderRadius.only(topLeft: corner));
        expect(FrostPageOutline.of(tester.element(find.byKey(pageKey))), radius);

        // The page's own fill runs into the channel where its scrollbar paints.
        final fill = find.descendant(of: _sheet, matching: find.byType(DecoratedBox)).first;
        expect(tester.getRect(fill), sheet);
      });
    }

    testWidgets('the dark content sheet draws its edge only on its top and start sides, $direction', (tester) async {
      await _pump(tester, brightness: Brightness.dark, direction: direction);
      final rtl = direction == TextDirection.rtl;
      final sheet = tester.getRect(_sheet);
      final pixel = await _capture(tester);
      final inner = pixel(sheet.center.dx, sheet.center.dy);
      final start = rtl ? sheet.right - 1 : sheet.left;
      final end = rtl ? sheet.left : sheet.right - 1;
      expect(pixel(start, sheet.center.dy), isNot(inner), reason: 'the start side meets the base');
      expect(pixel(sheet.center.dx, sheet.top), isNot(inner), reason: 'the top side meets the base');
      expect(pixel(end, sheet.center.dy), inner, reason: 'the end side lies on the window border');
      expect(pixel(sheet.center.dx, sheet.bottom - 1), inner, reason: 'the bottom side lies on the window border');
      expect(pixel(start, sheet.top + 1), isNot(inner), reason: 'the start corner is rounded');
      expect(pixel(end, sheet.bottom - 1), inner, reason: 'the bottom corners are square');
      expect(pixel(start + (rtl ? -1 : 1), sheet.bottom - 1), inner);
    });
  }

  testWidgets('the compact layout has no content sheet', (tester) async {
    await _pump(tester, brightness: Brightness.dark, size: const Size(390, 800));
    expect(_sheet, findsNothing);
    expect(FrostPageOutline.of(tester.element(find.byKey(pageKey))), BorderRadius.zero);
    expect(tester.getRect(find.byKey(pageKey)).bottom, lessThanOrEqualTo(800));
  });
}
