import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'ambient_material_test.dart' show settleGlow;
import 'ambient_transition_test.dart' show complete;
import 'media_frame_test.dart' show ControlledImage;
import 'support.dart';

/// Window pixels inside the panel and inside the base around it.
Future<List<int>> _probe(WidgetTester tester, GlobalKey key) async {
  var render = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  if (render.debugNeedsPaint) {
    await tester.pump(Duration.zero);
    render = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  }
  final image = (await tester.runAsync(() => render.toImage()))!;
  final bytes = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
  final result = <int>[];
  for (final point in [const Offset(90, 60), const Offset(10, 10)]) {
    final offset = (point.dy.toInt() * image.width + point.dx.toInt()) * 4;
    result.addAll([for (var channel = 0; channel < 3; channel++) bytes.getUint8(offset + channel)]);
  }
  image.dispose();
  return result;
}

void main() {
  for (final brightness in [Brightness.dark, Brightness.light]) {
    for (final reduced in [false, true]) {
      testWidgets('window surfaces follow the glow in and out; $brightness reduced=$reduced', (tester) async {
        tester.view.physicalSize = const Size(180, 120);
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
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
                  child: RepaintBoundary(
                    key: key,
                    child: FrostAmbientBackdropHost(
                      image: image,
                      child: const FrostSurface(
                        role: FrostSurfaceRole.base,
                        child: Center(
                          child: FrostSurface(role: FrostSurfaceRole.panel, child: SizedBox(width: 100, height: 60)),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await settleGlow(tester);

        Future<List<List<int>>> run(VoidCallback change, {Future<void> Function()? arrive}) async {
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
          return frames;
        }

        void expectSmooth(List<List<int>> frames, String phase) {
          final first = frames.first, last = frames.last;
          for (var channel = 0; channel < first.length; channel++) {
            final total = (last[channel] - first[channel]).abs();
            if (total < 12) continue;
            final steps = [for (var i = 1; i < frames.length; i++) (frames[i][channel] - frames[i - 1][channel]).abs()];
            final largest = steps.reduce((a, b) => a > b ? a : b);
            if (reduced) {
              expect(largest, greaterThanOrEqualTo(total - 2), reason: '$phase channel $channel switches at once');
            } else {
              expect(largest, lessThan(total * .4), reason: '$phase channel $channel: no single frame carries the change ($steps)');
            }
          }
        }

        final entering = await run(() => image = art, arrive: () => complete(tester, art, Colors.purple));
        expect(entering.last, isNot(entering.first));
        expectSmooth(entering, 'in');
        final leaving = await run(() => image = null);
        expectSmooth(leaving, 'out');
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      });
    }
  }
}
