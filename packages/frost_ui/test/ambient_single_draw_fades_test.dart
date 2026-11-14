import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/surface/ambient_backdrop.dart' show FrostFadingAmbientBackdrop;
import 'package:material_ui/material_ui.dart';

import 'ambient_material_test.dart' show resolveImage, settleGlow;
import 'media_frame_test.dart' show ControlledImage;
import 'support.dart';

final _ambientPaint = find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_AmbientPaint');

List<Symbol> _calls(void Function(Canvas canvas) paint) {
  final canvas = TestRecordingCanvas();
  paint(canvas);
  return [for (final call in canvas.invocations) call.invocation.memberName];
}

class _EncodedImage extends ImageProvider<_EncodedImage> {
  _EncodedImage(this.bytes);
  final Uint8List bytes;
  @override
  Future<_EncodedImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(_EncodedImage key, ImageDecoderCallback decode) => OneFrameImageStreamCompleter(_load(decode));

  Future<ImageInfo> _load(ImageDecoderCallback decode) async {
    final codec = await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
    try {
      return ImageInfo(image: (await codec.getNextFrame()).image);
    } finally {
      codec.dispose();
    }
  }
}

Future<_EncodedImage> _solid(WidgetTester tester, Color color) async => (await tester.runAsync(() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 32, 32), Paint()..color = color);
  final picture = recorder.endRecording();
  final image = await picture.toImage(32, 32);
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  image.dispose();
  picture.dispose();
  return _EncodedImage(bytes);
}))!;

void main() {
  testWidgets('a glow fades in as single draws, also in a backdrop that is itself fading', (tester) async {
    final artwork = ControlledImage();
    await tester.pumpWidget(
      frostTestApp(
        FrostAmbientBackdropHost(
          image: artwork,
          // As the backdrop a moving page carries.
          child: const FrostFadingAmbientBackdrop(opacity: .5),
        ),
        brightness: Brightness.dark,
        platform: TargetPlatform.android,
      ),
    );
    await resolveImage(tester, artwork, const Color(0xFF245898), settle: false);
    var blended = 0;
    for (var frame = 0; frame < 60; frame++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 20));
      for (final render in tester.renderObjectList(_ambientPaint)) {
        final calls = _calls((canvas) => render.paint(TestRecordingPaintingContext(canvas), Offset.zero));
        expect(calls, isNot(contains(#saveLayer)), reason: 'frame $frame');
        // The draw the endpoint showed and its texture with the glow in full.
        if (calls.where((call) => call == #drawImageRect || call == #drawRect).length >= 2 && calls.contains(#drawImageRect)) blended++;
      }
    }
    expect(blended, greaterThan(0), reason: 'the glow crossfades in from what the endpoint showed');
    await settleGlow(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('media ambient crossfades its sources as single draws ($brightness)', (tester) async {
      final first = await _solid(tester, Colors.red), second = await _solid(tester, Colors.blue);
      late StateSetter update;
      ImageProvider provider = first;
      await tester.pumpWidget(
        frostTestApp(
          Center(
            child: SizedBox(
              width: 300,
              height: 200,
              child: StatefulBuilder(
                builder: (_, set) {
                  update = set;
                  return FrostAmbientBackdrop.fromImage(image: provider, child: const SizedBox.expand());
                },
              ),
            ),
          ),
          brightness: brightness,
        ),
      );
      Future<int> frames(int count) async {
        var blended = 0;
        for (var frame = 0; frame < count; frame++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
          await tester.pump(const Duration(milliseconds: 16));
          final paints = tester
              .renderObjectList<RenderCustomPaint>(find.descendant(of: find.byType(FrostAmbientBackdrop), matching: find.byType(CustomPaint)))
              .where((render) => render.painter.runtimeType.toString() == '_MediaPalettePainter');
          for (final render in paints) {
            final calls = _calls((canvas) => render.painter!.paint(canvas, render.size));
            expect(calls, isNot(contains(#saveLayer)), reason: 'frame $frame');
            if (calls.where((call) => call == #drawImageRect).length >= 2) blended++;
          }
        }
        return blended;
      }

      await frames(40);
      update(() => provider = second);
      expect(await frames(60), greaterThan(0), reason: 'both sources are on screen while one replaces the other');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
