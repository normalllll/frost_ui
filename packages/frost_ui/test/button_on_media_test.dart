import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_button_parts.dart' show FrostButtonFrame;
import 'package:frost_ui/src/foundation/color_math.dart' show colorContrast;
import 'package:material_ui/material_ui.dart';

import 'support.dart';

final _boundary = GlobalKey();
const _text = ValueKey('text choice'), _icon = ValueKey('icon control');

Widget _app(Widget child, {Brightness brightness = Brightness.dark}) => frostTestApp(
  RepaintBoundary(
    key: _boundary,
    child: Center(child: SizedBox(width: 800, height: 450, child: child)),
  ),
  brightness: brightness,
);

Future<Color Function(Offset)> _capture(WidgetTester tester) async {
  final render = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final origin = render.localToGlobal(Offset.zero);
  final image = (await tester.runAsync(() => render.toImage()))!;
  final bytes = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
  final width = image.width;
  image.dispose();
  return (point) {
    final local = point - origin;
    final offset = (local.dy.toInt() * width + local.dx.toInt()) * 4;
    return Color.fromARGB(255, bytes.getUint8(offset), bytes.getUint8(offset + 1), bytes.getUint8(offset + 2));
  };
}

// The painted frame, inside the larger hit area.
Rect _frame(WidgetTester tester, Key key) => tester.getRect(find.descendant(of: find.byKey(key), matching: find.byType(FrostButtonFrame)).first);

// A point on the button's fill, clear of its label or icon.
Offset _fill(WidgetTester tester, Key key) {
  final rect = _frame(tester, key);
  return Offset(rect.left + 3, rect.center.dy);
}

// Where the focus ring paints, just outside the plate.
Offset _ring(WidgetTester tester, Key key) {
  final rect = _frame(tester, key);
  return Offset(rect.left - 3, rect.center.dy);
}

void _close(Color actual, Color expected, String reason) {
  for (final (a, e) in [(actual.r, expected.r), (actual.g, expected.g), (actual.b, expected.b)]) {
    expect((a - e).abs(), lessThanOrEqualTo(2 / 255), reason: '$reason: $actual vs $expected');
  }
}

void main() {
  for (final frame in [const Color(0xFFFFFFFF), const Color(0xFF000000)]) {
    for (final brightness in Brightness.values) {
      testWidgets('a text choice in the video slot takes the on-media scrim and ink over $frame, $brightness', (tester) async {
        await tester.pumpWidget(
          _app(
            FrostVideoFrame(
              video: Stack(
                children: [
                  ColoredBox(color: frame, child: const SizedBox.expand()),
                  Align(
                    alignment: const Alignment(0, .4),
                    child: FrostButton.onMedia(key: _text, label: 'A 3 red 2 blue', onPressed: () {}),
                  ),
                ],
              ),
              state: const FrostVideoState(playing: true, position: Duration.zero, duration: Duration(minutes: 3)),
              onPlayPause: () {},
              onSeek: (_) {},
            ),
            brightness: brightness,
          ),
        );
        await tester.pumpAndSettle();
        final tokens = FrostThemeTokens.of(tester.element(find.byKey(_text)));
        final pixel = await _capture(tester);
        final behind = Color.alphaBlend(tokens.onMediaScrim, frame);
        _close(pixel(_fill(tester, _text)), behind, 'the resting fill is the on-media scrim');
        final label = tester.renderObject<RenderParagraph>(find.descendant(of: find.byKey(_text), matching: find.byType(RichText)));
        expect(label.text.style?.color, tokens.onMediaInk);
        expect(colorContrast(tokens.onMediaInk, behind), greaterThanOrEqualTo(4.5), reason: 'body text contrast over the frame');
      });
    }
  }

  testWidgets('a text choice matches the on-media icon in every state', (tester) async {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
    Widget row({required bool enabled}) => _app(
      Stack(
        children: [
          const ColoredBox(color: Color(0xFF7F8A99), child: SizedBox.expand()),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FrostButton.onMedia(key: _text, label: 'Choice', onPressed: enabled ? () {} : null),
                const SizedBox(width: 40),
                FrostButton.iconOnMedia(key: _icon, icon: testIcons.back, label: 'Back', onPressed: enabled ? () {} : null),
              ],
            ),
          ),
        ],
      ),
    );
    Future<void> same(String state, {Offset Function(WidgetTester, Key) at = _fill}) async {
      final pixel = await _capture(tester);
      _close(pixel(at(tester, _text)), pixel(at(tester, _icon)), state);
    }

    await tester.pumpWidget(row(enabled: true));
    await tester.pumpAndSettle();
    await same('rest');
    final resting = (await _capture(tester))(_fill(tester, _text));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: tester.getCenter(find.byKey(_text)));
    await tester.pumpAndSettle();
    final hovered = (await _capture(tester))(_fill(tester, _text));
    expect(hovered, isNot(resting), reason: 'hover shows');
    await mouse.moveTo(tester.getCenter(find.byKey(_icon)));
    await tester.pumpAndSettle();
    _close((await _capture(tester))(_fill(tester, _icon)), hovered, 'hover');
    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();

    final ringAtRest = (await _capture(tester))(_ring(tester, _text));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    final ring = (await _capture(tester))(_ring(tester, _text));
    expect(ring, isNot(ringAtRest), reason: 'the focus ring shows');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    _close((await _capture(tester))(_ring(tester, _icon)), ring, 'focus ring');

    await tester.pumpWidget(row(enabled: false));
    await tester.pumpAndSettle();
    await same('disabled');
  });

  testWidgets('a text choice reads as a button with its label', (tester) async {
    final semantics = tester.ensureSemantics();
    var presses = 0;
    await tester.pumpWidget(_app(Center(child: FrostButton.onMedia(key: _text, label: 'A 3 red 2 blue', onPressed: () => presses++))));
    expect(tester.getSemantics(find.byKey(_text)), isSemantics(label: 'A 3 red 2 blue', isButton: true, hasTapAction: true, isEnabled: true));
    await tester.tap(find.byKey(_text));
    expect(presses, 1);
    semantics.dispose();
  });
}
