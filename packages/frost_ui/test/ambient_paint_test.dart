import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/foundation/_ambient_material.dart';
import 'package:frost_ui/src/foundation/color_math.dart' show colorContrast;
import 'package:material_ui/material_ui.dart';

import 'media_frame_test.dart' show ControlledImage;
import 'support.dart';

final _host = GlobalKey();

Future<void> resolveSplit(WidgetTester tester, ControlledImage provider) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder)
    ..drawRect(const Rect.fromLTWH(0, 0, 24, 32), Paint()..color = const Color(0xFFE53935))
    ..drawRect(const Rect.fromLTWH(24, 0, 24, 32), Paint()..color = const Color(0xFF1E88E5));
  final recording = recorder.endRecording();
  final image = (await tester.runAsync(() => recording.toImage(48, 32)))!;
  recording.dispose();
  provider.completer.complete(ImageInfo(image: image));
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

Future<List<Color>> pixels(WidgetTester tester, List<Offset> points) async {
  final boundary = _host.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = (await tester.runAsync(() => boundary.toImage()))!;
  final bytes = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
  final width = image.width;
  image.dispose();
  return [
    for (final p in points)
      Color.fromARGB(
        255,
        bytes.getUint8((p.dy.round() * width + p.dx.round()) * 4),
        bytes.getUint8((p.dy.round() * width + p.dx.round()) * 4 + 1),
        bytes.getUint8((p.dy.round() * width + p.dx.round()) * 4 + 2),
      ),
  ];
}

Widget app(ImageProvider? image, Brightness brightness, {FrostAmbientFallback fallback = FrostAmbientFallback.none}) => frostTestApp(
  RepaintBoundary(
    key: _host,
    child: FrostAmbientBackdropHost(image: image, fallback: fallback, child: const SizedBox.expand()),
  ),
  brightness: brightness,
);

double hue(Color c) => HSVColor.fromColor(c).hue;

// The dark glow field is baked on another isolate and faded in on the wall
// clock; let real time pass until it has settled.
Future<void> settleGlow(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('dark artwork paints glows at its colour positions, pulled to the top, no texture of the art', (tester) async {
    final provider = ControlledImage();
    await tester.pumpWidget(app(provider, Brightness.dark));
    await resolveSplit(tester, provider);
    await settleGlow(tester);
    // Whichever path paints the frame (live or the prepared window-sized
    // endpoint), the small blurred artwork itself is never drawn.
    final calls = <(Symbol, List<dynamic>)>[];
    expect(
      tester.renderObject(find.byType(FrostAmbientBackdrop)),
      paints..everything((method, arguments) {
        calls.add((method, arguments));
        return true;
      }),
    );
    for (final (method, arguments) in calls) {
      if (method == #drawImageRect || method == #drawImage) {
        expect((arguments.first as ui.Image).width, greaterThan(48), reason: 'only the glow field or the window endpoint may be drawn');
      }
    }
    final [left, right, far] = await pixels(tester, [const Offset(120, 40), const Offset(680, 40), const Offset(790, 590)]);
    final tokens = FrostPalettes.pink.darkNeutral;
    expect(left, isNot(tokens.canvas));
    expect(left.r, greaterThan(left.b), reason: 'red half stays on the left');
    expect(right.b, greaterThan(right.r), reason: 'blue half stays on the right');
    final spread = (hue(left) - hue(right)).abs();
    expect(math.min(spread, 360 - spread), greaterThanOrEqualTo(60));
    // Outside the local glow, the approved light wash still carries artwork
    // colour. It stays subtle and readable instead of returning to canvas.
    expect(far, isNot(tokens.canvas));
    for (final (actual, canvas) in [(far.r, tokens.canvas.r), (far.g, tokens.canvas.g), (far.b, tokens.canvas.b)]) {
      expect((actual - canvas).abs(), lessThanOrEqualTo(8 / 255));
    }
    for (final ink in [tokens.textPrimary, tokens.textSecondary]) {
      expect(colorContrast(ink, far), greaterThanOrEqualTo(4.5));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('light artwork retains a subtle wash beyond the local gradient', (tester) async {
    final provider = ControlledImage();
    await tester.pumpWidget(app(provider, Brightness.light));
    await resolveSplit(tester, provider);
    final tokens = FrostPalettes.pink.lightNeutral;
    // 800 × 600 test window: the reach is 650 px from the top-left corner.
    final [near, far] = await pixels(tester, [const Offset(80, 60), const Offset(700, 500)]);
    expect(near, isNot(tokens.canvas));
    expect(near.r, greaterThan(near.b), reason: 'the red half sits at the top-left');
    expect(far, isNot(tokens.canvas));
    for (final (actual, canvas) in [(far.r, tokens.canvas.r), (far.g, tokens.canvas.g), (far.b, tokens.canvas.b)]) {
      // Twenty-percent toned colour plus the existing two-step grain.
      expect((canvas - actual).abs(), lessThanOrEqualTo(12 / 255));
    }
    for (final ink in [tokens.textPrimary, tokens.textSecondary]) {
      expect(colorContrast(ink, far), greaterThanOrEqualTo(4.5));
    }
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('no artwork with the accent fallback paints the accent-tinted mesh ($brightness)', (tester) async {
      await tester.pumpWidget(app(null, brightness, fallback: FrostAmbientFallback.accentWash));
      await tester.pumpAndSettle();
      final [corner] = await pixels(tester, [const Offset(4, 4)]);
      final tokens = brightness == Brightness.dark ? FrostPalettes.pink.darkNeutral : FrostPalettes.pink.lightNeutral;
      expect(corner, isNot(tokens.canvas), reason: 'top-left mesh stop');
      expect(tester.takeException(), isNull);
    });
  }

  test('light falloff is smooth and reaches zero at 65% of the diagonal', () {
    expect(frostAmbientFalloffReach, .65);
    expect(frostAmbientFalloff(0), 1);
    expect(frostAmbientFalloff(1), 0);
    expect(frostAmbientFalloff(1.4), 0);
    for (var i = 1; i <= 20; i++) {
      expect(frostAmbientFalloff(i / 20), lessThanOrEqualTo(frostAmbientFalloff((i - 1) / 20)));
    }
  });
}
