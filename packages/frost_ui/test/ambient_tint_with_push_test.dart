import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/foundation/_ambient_material.dart';

import 'ambient_material_test.dart' show settleGlow;
import 'ambient_transition_test.dart' show complete;
import 'media_frame_test.dart' show ControlledImage;
import 'support.dart';

FrostAmbientGlowBakes get _bakes => FrostAmbientGlowBakes.instance;

/// RGB inside the panel, beside the moving card.
Future<List<int>> _probe(WidgetTester tester, GlobalKey key) async {
  var render = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  if (render.debugNeedsPaint) {
    await tester.pump(Duration.zero);
    render = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  }
  final image = (await tester.runAsync(() => render.toImage()))!;
  final bytes = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
  const point = Offset(140, 60);
  final offset = (point.dy.toInt() * image.width + point.dx.toInt()) * 4;
  final result = [for (var channel = 0; channel < 3; channel++) bytes.getUint8(offset + channel)];
  image.dispose();
  return result;
}

void main() {
  setUp(() => _bakes.debugReset());
  tearDown(() => _bakes.debugReset());

  testWidgets('dark art tints the window while the page moves in; the glow bakes after and fades in', (tester) async {
    tester.view.physicalSize = const Size(180, 120);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final art = ControlledImage();
    ImageProvider? image;
    double top = 90;
    final key = GlobalKey();
    late StateSetter update;
    await tester.pumpWidget(
      frostTestApp(
        brightness: Brightness.dark,
        StatefulBuilder(
          builder: (_, set) {
            update = set;
            return RepaintBoundary(
              key: key,
              child: FrostAmbientBackdropHost(
                image: image,
                child: FrostSurface(
                  role: FrostSurfaceRole.base,
                  child: Stack(
                    children: [
                      const Positioned(
                        left: 100,
                        top: 20,
                        width: 70,
                        height: 80,
                        child: FrostSurface(role: FrostSurfaceRole.panel, child: SizedBox.expand()),
                      ),
                      Positioned(
                        left: 10,
                        top: top,
                        width: 40,
                        height: 20,
                        child: const FrostSurface(role: FrostSurfaceRole.module, child: SizedBox.expand()),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await settleGlow(tester);
    final canvas = await _probe(tester, key);

    update(() => image = art);
    await tester.pump();
    await complete(tester, art, Colors.purple);
    final frames = [canvas];
    // The page slides in: its card moves every frame for a third of a second.
    for (var frame = 1; frame <= 20; frame++) {
      update(() => top = 90 - 3.0 * frame);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump(const Duration(milliseconds: 16));
      frames.add(await _probe(tester, key));
      expect(_bakes.debugStarted, 0, reason: 'no glow bake while the page moves (frame $frame)');
    }
    expect(frames.last, isNot(canvas), reason: 'the window colour follows the page in before layout rests');

    // At rest the glow bakes once and fades in over the tint.
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 16));
      frames.add(await _probe(tester, key));
    }
    await settleGlow(tester);
    frames.add(await _probe(tester, key));
    expect(_bakes.debugStarted, 1);
    for (var channel = 0; channel < 3; channel++) {
      final total = (frames.last[channel] - canvas[channel]).abs();
      if (total < 12) continue;
      final steps = [for (var i = 1; i < frames.length; i++) (frames[i][channel] - frames[i - 1][channel]).abs()];
      expect(steps.reduce((a, b) => a > b ? a : b), lessThan(total * .4), reason: 'channel $channel moves without a jump ($steps)');
    }
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
