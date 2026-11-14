import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/surface/ambient_backdrop.dart' show FrostAmbientBackdropController;
import 'package:material_ui/material_ui.dart';

import 'ambient_material_test.dart' show resolveImage, settleGlow;
import 'media_frame_test.dart' show ControlledImage;
import 'support.dart';

final _paint = find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_AmbientPaint');

List<Symbol> _calls(RenderObject render) {
  final canvas = TestRecordingCanvas();
  render.paint(TestRecordingPaintingContext(canvas), Offset.zero);
  return [for (final call in canvas.invocations) call.invocation.memberName];
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('a new artwork waits for its texture before it fades in, and no frame paints a layer ($brightness)', (tester) async {
      addTearDown(() => FrostAmbientBackdropController.debugTextureDelay = null);
      final grid = ControlledImage(), work = ControlledImage();
      ImageProvider? artwork = grid;
      late StateSetter update;
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        frostTestApp(
          StatefulBuilder(
            builder: (context, set) {
              update = set;
              return FrostAmbientBackdropHost(
                image: artwork,
                child: Navigator(key: navigator, onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const SizedBox.expand())),
              );
            },
          ),
          brightness: brightness,
          platform: TargetPlatform.android,
        ),
      );
      await resolveImage(tester, grid, const Color(0xFF245898));
      // Seen once before, as an app's recent artwork usually is: its colours
      // are known, so a change to it commits as soon as it can be drawn.
      update(() => artwork = work);
      await tester.pump();
      await resolveImage(tester, work, const Color(0xFFB8482A));
      update(() => artwork = grid);
      await tester.pump();
      await settleGlow(tester);

      Future<void> change(ImageProvider to, {required bool opening}) async {
        final raster = Completer<void>();
        FrostAmbientBackdropController.debugTextureDelay = raster.future;
        if (opening) {
          navigator.currentState!.push(
            const FrostDetailPage<void>.media(child: Center(child: SizedBox(width: 200, height: 260))).createRoute(navigator.currentContext!),
          );
        } else {
          navigator.currentState!.pop();
        }
        update(() => artwork = to);
        // While the raster thread is busy, the page moves over the old picture.
        for (var i = 0; i < 12; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2)));
          await tester.pump(const Duration(milliseconds: 16));
          for (final render in tester.renderObjectList(_paint)) {
            final calls = _calls(render);
            expect(calls, isNot(contains(#saveLayer)), reason: 'frame $i');
            expect(calls.where((call) => call == #drawImageRect), hasLength(lessThanOrEqualTo(1)), reason: 'frame $i: only the old picture');
          }
        }
        raster.complete();
        FrostAmbientBackdropController.debugTextureDelay = null;
        var blended = 0;
        for (var i = 0; i < 50; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2)));
          await tester.pump(const Duration(milliseconds: 16));
          for (final render in tester.renderObjectList(_paint)) {
            final calls = _calls(render);
            expect(calls, isNot(contains(#saveLayer)), reason: 'frame $i after the texture');
            if (calls.where((call) => call == #drawImageRect).length == 2) blended++;
          }
        }
        expect(blended, greaterThan(0), reason: 'the new artwork crossfades in once its texture is ready');
        await settleGlow(tester);
      }

      await change(work, opening: true);
      await change(grid, opening: false);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
