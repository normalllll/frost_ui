import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'ambient_material_test.dart' show settleGlow;
import 'ambient_transition_test.dart' show complete;
import 'media_frame_test.dart' show ControlledImage;
import 'support.dart';

const _module = Offset(20, 20), _button = Offset(100, 60);

double _luma(List<int> rgb) => .2126 * rgb[0] + .7152 * rgb[1] + .0722 * rgb[2];

Future<Map<Offset, double>> _probe(WidgetTester tester, GlobalKey key) async {
  var render = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  if (render.debugNeedsPaint) {
    await tester.pump(Duration.zero);
    render = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  }
  final image = (await tester.runAsync(() => render.toImage()))!;
  final bytes = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
  final result = <Offset, double>{};
  for (final point in [_module, _button]) {
    final offset = (point.dy.toInt() * image.width + point.dx.toInt()) * 4;
    result[point] = _luma([for (var channel = 0; channel < 3; channel++) bytes.getUint8(offset + channel)]);
  }
  image.dispose();
  return result;
}

void main() {
  for (final brightness in [Brightness.dark, Brightness.light]) {
    testWidgets('a module and a button stay between their two ends while ambient art fades; $brightness', (tester) async {
      tester.view.physicalSize = const Size(200, 120);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final art = ControlledImage();
      ImageProvider? image;
      final key = GlobalKey();
      late StateSetter update;
      await tester.pumpWidget(
        frostTestApp(
          brightness: brightness,
          StatefulBuilder(
            builder: (context, set) {
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
                          left: 8,
                          top: 8,
                          width: 60,
                          height: 40,
                          child: FrostSurface(role: FrostSurfaceRole.module, child: SizedBox.expand()),
                        ),
                        Positioned(
                          left: 80,
                          top: 44,
                          width: 110,
                          height: 44,
                          child: FrostButton(label: ' ', onPressed: () {}),
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

      Future<void> run(VoidCallback change, String phase, {Future<void> Function()? arrive}) async {
        final frames = [await _probe(tester, key)];
        update(change);
        await tester.pump();
        await arrive?.call();
        for (var i = 0; i < 40; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
          await tester.pump(const Duration(milliseconds: 16));
          frames.add(await _probe(tester, key));
        }
        await settleGlow(tester);
        frames.add(await _probe(tester, key));
        for (final point in [_module, _button]) {
          final a = frames.first[point]!, b = frames.last[point]!;
          final low = a < b ? a : b, high = a < b ? b : a;
          for (final (index, frame) in frames.indexed) {
            expect(frame[point]!, inInclusiveRange(low - 3, high + 3), reason: '$phase $point frame $index: ${frames.map((f) => f[point]!.round()).toList()}');
          }
        }
      }

      await run(() => image = art, 'in', arrive: () => complete(tester, art, Colors.purple));
      await run(() => image = null, 'out');
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  }
}
