import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'ambient_material_test.dart' show resolveImage;
import 'media_frame_test.dart' show ControlledImage;
import 'support.dart';

final _ambientPaint = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_AmbientPaint');

List<Invocation> _calls(RenderObject render, Symbol method) {
  final canvas = TestRecordingCanvas();
  render.paint(TestRecordingPaintingContext(canvas), Offset.zero);
  return [
    for (final call in canvas.invocations)
      if (call.invocation.memberName == method) call.invocation,
  ];
}

void main() {
  testWidgets('settled ambient paint and a change of intensity need no full-window opacity buffer', (tester) async {
    final provider = ControlledImage();
    var intensity = 1.0;
    late StateSetter update;
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (_, set) {
            update = set;
            return FrostAmbientBackdropHost(image: provider, intensity: intensity, child: const SizedBox.expand());
          },
        ),
      ),
    );
    await resolveImage(tester, provider, const Color(0xff245898));
    RenderObject backdrop() => tester.renderObject(
      find.descendant(of: find.byType(FrostAmbientBackdropHost), matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == '_AmbientPaint')).first,
    );
    expect(backdrop(), paintsExactlyCountTimes(#saveLayer, 0));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
    // The settled endpoint is one prepared image and the live grain, with no
    // repeated wash gradients, scrim, or artwork color filter on route frames.
    expect(backdrop(), paintsExactlyCountTimes(#drawImageRect, 1));
    expect(backdrop(), paintsExactlyCountTimes(#drawRect, 1));
    update(() => intensity = .4);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(backdrop(), paintsExactlyCountTimes(#saveLayer, 0));
    await tester.pumpAndSettle();
    expect(backdrop(), paintsExactlyCountTimes(#saveLayer, 0));
    expect(tester.takeException(), isNull);
  });
  testWidgets('the prepared endpoint texture keeps its size when the pixel ratio grows', (tester) async {
    Future<Size> textureAt(double pixelRatio) async {
      tester.view.physicalSize = const Size(375, 416) * pixelRatio;
      tester.view.devicePixelRatio = pixelRatio;
      final provider = ControlledImage();
      await tester.pumpWidget(frostTestApp(FrostAmbientBackdropHost(image: provider, child: const SizedBox.expand())));
      await resolveImage(tester, provider, const Color(0xff245898));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump();
      final images = _calls(tester.renderObject(find.descendant(of: find.byType(FrostAmbientBackdropHost), matching: _ambientPaint).first), #drawImageRect);
      expect(images, hasLength(1));
      final source = images.single.positionalArguments[1] as Rect;
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      return source.size;
    }

    addTearDown(tester.view.reset);
    final standard = await textureAt(1);
    expect(standard, const Size(375, 416), reason: 'one texel per logical pixel');
    expect(await textureAt(2.625), standard);
    expect(await textureAt(3.5), standard);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('a crossfade between prepared endpoints, and to no artwork, records no layer $brightness', (tester) async {
      final first = ControlledImage(), second = ControlledImage();
      ImageProvider? image = first;
      late StateSetter update;
      await tester.pumpWidget(
        frostTestApp(
          StatefulBuilder(
            builder: (_, set) {
              update = set;
              return FrostAmbientBackdropHost(image: image, child: const SizedBox.expand());
            },
          ),
          brightness: brightness,
        ),
      );
      await resolveImage(tester, first, const Color(0xff245898));
      RenderObject backdrop() => tester.renderObject(find.descendant(of: find.byType(FrostAmbientBackdropHost), matching: _ambientPaint).first);

      update(() => image = second);
      await resolveImage(tester, second, const Color(0xffb8482a), settle: false);
      var blended = 0;
      for (var i = 0; i < 60; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump(const Duration(milliseconds: 16));
        final layers = _calls(backdrop(), #saveLayer).length;
        // An endpoint still painted live takes one layer until its texture lands.
        expect(layers, lessThanOrEqualTo(1));
        if (_calls(backdrop(), #drawImageRect).length == 2) {
          blended++;
          expect(layers, 0, reason: 'two prepared endpoints blend without a layer');
        }
      }
      expect(blended, greaterThan(0), reason: 'the fade showed both prepared endpoints');

      update(() => image = null);
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(_calls(backdrop(), #saveLayer), isEmpty);
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets('prepared ambient endpoint matches the live paint and its window anchoring $brightness', (tester) async {
      tester.view.physicalSize = const Size(640, 480);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final provider = ControlledImage();
      final boundary = GlobalKey();
      await tester.pumpWidget(
        frostTestApp(
          FrostAmbientBackdropHost(
            image: provider,
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 180,
                height: 120,
                child: RepaintBoundary(key: boundary, child: const FrostAmbientBackdrop()),
              ),
            ),
          ),
          brightness: brightness,
        ),
      );
      await resolveImage(tester, provider, const Color(0xff245898));
      Future<List<int>> pixels() async {
        final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = (await tester.runAsync(() => render.toImage(pixelRatio: 2)))!;
        final bytes = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
        image.dispose();
        return bytes.buffer.asUint8List().toList();
      }

      final live = await pixels();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump();
      final cached = await pixels();
      expect(cached.length, live.length);
      // One extra 8-bit texture composite can round by one channel step.
      for (var i = 0; i < live.length; i++) {
        expect((live[i] - cached[i]).abs(), lessThanOrEqualTo(1), reason: 'channel $i');
      }
      final paint = find.descendant(of: find.byKey(boundary), matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == '_AmbientPaint'));
      // Only the light grain is painted besides the prepared image.
      expect(tester.renderObject(paint), paintsExactlyCountTimes(#drawRect, brightness == Brightness.light ? 1 : 0));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
