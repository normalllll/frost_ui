import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/foundation/_premultiplied_lerp.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

// Backdrops a caption field rests on: an ambient wash and the Mica tones that
// show through a transparent window, per brightness.
const _backdrops = {
  Brightness.dark: [Color(0xFF1B1D2A), Color(0xFF202020)],
  Brightness.light: [Color(0xFFEEF0F8), Color(0xFFF3F3F3)],
};

typedef _Pixels = ({ByteData bytes, int width, int height});

void main() {
  test('premultiplied lerp stays between its ends over any backdrop', () {
    // The dark caption field: a translucent ink wash at rest, opaque when focused.
    const rest = Color(0x0EECECF0), focused = Color(0xFF2E2F33);
    for (final backdrop in const [Color(0xFF000000), Color(0xFF202020), Color(0xFF1B1D2A), Color(0xFFFFFFFF)]) {
      final from = Color.alphaBlend(rest, backdrop), to = Color.alphaBlend(focused, backdrop);
      var straightOvershoots = false;
      for (var i = 1; i < 20; i++) {
        final t = i / 20;
        final frame = Color.alphaBlend(frostLerpColorPremultiplied(rest, focused, t)!, backdrop);
        for (final (channel, a, b) in [(frame.r, from.r, to.r), (frame.g, from.g, to.g), (frame.b, from.b, to.b)]) {
          expect(channel, inInclusiveRange(a < b ? a - 1e-6 : b - 1e-6, a < b ? b + 1e-6 : a + 1e-6), reason: 't=$t over $backdrop');
        }
        final straight = Color.alphaBlend(Color.lerp(rest, focused, t)!, backdrop);
        if (straight.r > from.r + .02 && straight.r > to.r + .02) straightOvershoots = true;
      }
      // The straight-channel lerp this replaces does pass through a brighter grey.
      if (backdrop.r < .5) expect(straightOvershoots, isTrue, reason: 'over $backdrop');
    }
  });

  late TextEditingController controller;
  late FocusNode focus;
  setUp(() {
    controller = TextEditingController();
    focus = FocusNode();
  });
  tearDown(() {
    controller.dispose();
    focus.dispose();
  });

  final boundary = GlobalKey();
  // The caption field in its 48 high title row, at the window origin so the
  // capture shares the window's pixel grid.
  Widget app(Brightness brightness, Color backdrop) => frostTestApp(
    brightness: brightness,
    ColoredBox(
      color: backdrop,
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: boundary,
          child: ColoredBox(
            color: backdrop,
            child: SizedBox(
              width: 400,
              height: 48,
              child: Padding(
                padding: const EdgeInsets.only(left: 20, right: 20),
                child: FrostCaptionSearch(controller: controller, focusNode: focus, placeholder: 'Search', onSubmitted: (_) {}),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Future<_Pixels> capture(WidgetTester tester) async {
    final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    return (await tester.runAsync(() async {
      final image = await render.toImage(pixelRatio: tester.view.devicePixelRatio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final result = (bytes: bytes!, width: image.width, height: image.height);
      image.dispose();
      return result;
    }))!;
  }

  List<int> pixel(_Pixels pixels, int x, int y) {
    final i = (y * pixels.width + x) * 4;
    return [pixels.bytes.getUint8(i), pixels.bytes.getUint8(i + 1), pixels.bytes.getUint8(i + 2)];
  }

  for (final brightness in Brightness.values) {
    for (final backdrop in _backdrops[brightness]!) {
      testWidgets('caption field focus and blur pass no brighter or darker frame ($brightness on $backdrop)', (tester) async {
        await tester.pumpWidget(app(brightness, backdrop));
        await tester.pumpAndSettle();
        // An empty stretch of the editor: right of the placeholder, left of
        // the trailing hint and submit action.
        final probe = (tester.getCenter(find.byType(FrostCaptionSearch)) + const Offset(20, 0)) * tester.view.devicePixelRatio;
        Future<List<int>> sample() async => pixel(await capture(tester), probe.dx.round(), probe.dy.round());

        Future<void> transition(void Function() change) async {
          final start = await sample();
          change();
          final frames = <List<int>>[];
          for (var i = 0; i < 20; i++) {
            await tester.pump(const Duration(milliseconds: 16));
            frames.add(await sample());
          }
          await tester.pumpAndSettle();
          final end = await sample();
          expect(end, isNot(start), reason: 'focus must change the fill');
          for (final (i, frame) in frames.indexed) {
            for (var c = 0; c < 3; c++) {
              final low = start[c] < end[c] ? start[c] : end[c], high = start[c] < end[c] ? end[c] : start[c];
              expect(frame[c], inInclusiveRange(low - 1, high + 1), reason: 'frame $i channel $c: $frame between $start and $end');
            }
          }
        }

        await transition(focus.requestFocus);
        await transition(focus.unfocus);
      });
    }
  }

  testWidgets('focused caption edge covers two whole pixel rows per side at 125%', (tester) async {
    tester.view.devicePixelRatio = 1.25;
    tester.view.physicalSize = const Size(500, 500);
    addTearDown(tester.view.reset);
    const backdrop = Color(0xFF202020);
    await tester.pumpWidget(app(Brightness.dark, backdrop));
    focus.requestFocus();
    await tester.pumpAndSettle();
    // The 30 high field is centred at y 9 of the row: 11.25 to 48.75 pixels.
    final frame = tester.getRect(find.byType(FrostCaptionSearch));
    final pixels = await capture(tester);
    final x = ((frame.center.dx + 20) * 1.25).round();
    final fill = pixel(pixels, x, (frame.center.dy * 1.25).round());
    final outside = pixel(pixels, x, 0);
    bool plain(List<int> p, List<int> q) => [for (var c = 0; c < 3; c++) (p[c] - q[c]).abs() <= 1].every((same) => same);
    final edgeRows = [
      for (var y = 0; y < pixels.height; y++)
        if (!plain(pixel(pixels, x, y), fill) && !plain(pixel(pixels, x, y), outside)) y,
    ];
    // Two rows each for the top and bottom edges, nothing half covered.
    expect(edgeRows, hasLength(4), reason: 'rows $edgeRows');
  });
}
