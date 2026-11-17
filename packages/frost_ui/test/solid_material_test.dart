import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/overlays/_popover_surface.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

final _root = GlobalKey();

Widget _page({required Color beneath, required bool solid, required TargetPlatform platform}) {
  Widget page = Stack(
    children: [
      Positioned.fill(child: ColoredBox(color: beneath)),
      Align(
        alignment: Alignment.topCenter,
        child: FrostPopover(
          title: 'Reading settings',
          builder: (context, focus, toggle) => FrostButton(label: 'Settings', onPressed: toggle),
          contentBuilder: (context, close) => const SizedBox(width: 240, height: 160),
        ),
      ),
    ],
  );
  if (solid) page = FrostSolidMaterial(child: page);
  return RepaintBoundary(
    key: _root,
    child: frostTestApp(
      FrostAmbientBackdropHost(image: null, intensity: 1, child: page),
      brightness: Brightness.dark,
      platform: platform,
    ),
  );
}

Future<Color> _pixel(WidgetTester tester, Offset at) async => (await tester.runAsync(() async {
  final image = await tester.renderObject<RenderRepaintBoundary>(find.byKey(_root)).toImage(pixelRatio: 1);
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final index = (at.dy.round() * image.width + at.dx.round()) * 4;
  final color = Color.fromARGB(bytes.getUint8(index + 3), bytes.getUint8(index), bytes.getUint8(index + 1), bytes.getUint8(index + 2));
  image.dispose();
  return color;
}))!;

/// The panel's colour at a point inside it with nothing of its own drawn
/// there, over two different backgrounds.
Future<(Color, Color)> _overBoth(WidgetTester tester, {required bool solid, required TargetPlatform platform, required Finder panel}) async {
  await tester.pumpWidget(_page(beneath: const Color(0xFFFF0000), solid: solid, platform: platform));
  await tester.tap(find.text('Settings'));
  await tester.pumpAndSettle();
  final rect = tester.getRect(panel);
  final point = rect.bottomLeft + const Offset(12, -12);
  final first = await _pixel(tester, point);
  await tester.pumpWidget(_page(beneath: const Color(0xFF0000FF), solid: solid, platform: platform));
  await tester.pumpAndSettle();
  final second = await _pixel(tester, point);
  return (first, second);
}

void main() {
  for (final (name, size, platform, panel) in [
    ('anchored panel', const Size(1200, 800), TargetPlatform.windows, find.byType(FrostPopoverSurface)),
    ('compact sheet', const Size(390, 844), TargetPlatform.android, find.byWidgetPredicate((w) => w is FrostSurface && w.role == FrostSurfaceRole.sheet)),
  ]) {
    testWidgets('under solid material the $name hides what lies beneath it', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (red, blue) = await _overBoth(tester, solid: true, platform: platform, panel: panel);
      expect(red, blue);
      expect(red.a, 1);
    });

    // A sheet is opaque by default; only glass panels need the scope.
    if (platform == TargetPlatform.windows) {
      testWidgets('a default $name shows what lies beneath it', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final (red, blue) = await _overBoth(tester, solid: false, platform: platform, panel: panel);
        expect(red, isNot(blue));
      });
    }
  }
}
