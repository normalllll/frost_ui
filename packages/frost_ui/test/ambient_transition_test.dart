import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'ambient_material_test.dart' show settleGlow;
import 'media_frame_test.dart' show ControlledImage;
import 'support.dart';

Future<void> complete(WidgetTester tester, ControlledImage provider, Color color) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(color, BlendMode.src);
  final picture = recorder.endRecording();
  final image = (await tester.runAsync(() => picture.toImage(48, 32)))!;
  picture.dispose();
  provider.completer.complete(ImageInfo(image: image));
}

Future<List<int>> pixels(WidgetTester tester, GlobalKey key) async {
  final render = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = (await tester.runAsync(() => render.toImage()))!;
  final bytes = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
  final result = <int>[];
  for (final point in [const Offset(20, 30), const Offset(90, 40), const Offset(150, 100)]) {
    final offset = (point.dy.toInt() * image.width + point.dx.toInt()) * 4;
    result.addAll([for (var channel = 0; channel < 3; channel++) bytes.getUint8(offset + channel)]);
  }
  image.dispose();
  return result;
}

void main() {
  for (final media in [false, true]) {
    for (final reduced in [false, true]) {
      testWidgets('dark ${media ? 'media' : 'window'} replacement blends prepared endpoints once; reduced=$reduced', (tester) async {
        tester.view.physicalSize = const Size(180, 120);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final first = ControlledImage(), second = ControlledImage();
        ImageProvider provider = first;
        final key = GlobalKey();
        late StateSetter update;
        await tester.pumpWidget(
          frostTestApp(
            StatefulBuilder(
              builder: (context, set) {
                update = set;
                final child = media
                    ? FrostAmbientBackdrop.fromImage(image: provider, child: const SizedBox.expand())
                    : FrostAmbientBackdropHost(image: provider, child: const SizedBox.expand());
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
                  child: RepaintBoundary(key: key, child: child),
                );
              },
            ),
            brightness: Brightness.dark,
          ),
        );
        await complete(tester, first, Colors.purple);
        await settleGlow(tester);
        final before = await pixels(tester, key);
        update(() => provider = second);
        await tester.pump();
        await complete(tester, second, Colors.blue);
        final frames = <List<int>>[before];
        for (var i = 0; i < 60; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
          await tester.pump(const Duration(milliseconds: 16));
          frames.add(await pixels(tester, key));
        }
        await settleGlow(tester);
        final after = await pixels(tester, key);
        expect(after, isNot(before));
        // Every local probe stays on the same path between complete endpoints;
        // a fall through canvas fails even when the global average looks smooth.
        for (var channel = 0; channel < before.length; channel++) {
          final start = before[channel], end = after[channel], delta = end - start;
          var furthest = 0;
          for (final frame in frames) {
            final distance = (frame[channel] - start) * delta.sign;
            expect(distance, inInclusiveRange(-2, delta.abs() + 2), reason: 'channel $channel');
            expect(distance, greaterThanOrEqualTo(furthest - 2), reason: 'no second fade at channel $channel');
            if (distance > furthest) furthest = distance;
          }
        }
        expect(frames.last, after);
        if (reduced) {
          for (final frame in frames) {
            // Flattening an alpha wash into the cached 8-bit texture can round
            // one channel by one code value. Every frame must still match one
            // endpoint; a partly blended image is not accepted.
            bool matchesEndpoint(List<int> endpoint) =>
                List.generate(frame.length, (index) => (frame[index] - endpoint[index]).abs()).every((delta) => delta <= 1);
            expect(matchesEndpoint(before) || matchesEndpoint(after), isTrue, reason: 'reduced motion has no intermediate fade');
          }
        }
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      });
    }
  }
}
