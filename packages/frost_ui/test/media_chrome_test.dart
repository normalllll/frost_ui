import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/media.dart';
import 'package:frost_ui/src/media/_video_bar.dart';

import 'support.dart';

void main() {
  late List<String> pressed;
  late List<bool> zoomed;
  setUp(() {
    pressed = [];
    zoomed = [];
  });

  Finder control(String label) => find.byWidgetPredicate((widget) => widget is FrostMediaButton && widget.label == label);
  Widget button(String label) => FrostMediaButton.icon(icon: testIcons.close, label: label, onPressed: () => pressed.add(label));

  Future<void> pump(WidgetTester tester, {bool autoHide = true, Brightness brightness = Brightness.dark}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      frostTestApp(
        brightness: brightness,
        FrostMediaViewport(
          onZoomChanged: zoomed.add,
          overlay: FrostMediaChrome(
            autoHide: autoHide,
            top: Row(children: [button('Close'), const Spacer(), button('More')]),
            bottom: Row(mainAxisAlignment: MainAxisAlignment.center, children: [button('Zoom in'), button('Download')]),
            start: button('Previous'),
            end: button('Next'),
          ),
          child: const ColoredBox(color: Color(0xFFFFFFFF), child: SizedBox.expand()),
        ),
      ),
    );
  }

  bool visible(WidgetTester tester) {
    final states = tester
        .widgetList<FrostPresence>(find.descendant(of: find.byType(FrostMediaChrome), matching: find.byType(FrostPresence)))
        .map((presence) => presence.visible)
        .toSet();
    expect(states, hasLength(1));
    return states.single;
  }

  Iterable<FrostVideoScrimPainter> scrims(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.descendant(of: find.byType(FrostMediaChrome), matching: find.byType(CustomPaint)))
      .map((paint) => paint.painter)
      .whereType<FrostVideoScrimPainter>();

  testWidgets('the rows sit on the video player gradient and stay in the safe area', (tester) async {
    await pump(tester);
    final painters = scrims(tester).toList();
    expect(painters.map((painter) => painter.top), [true, false]);
    final readable = frostVideoControlScrimOpacity(FrostThemeTokens.of(tester.element(find.byType(FrostMediaChrome))));
    for (final painter in painters) {
      expect(painter.controlOpacity, readable);
      expect(painter.color.a, closeTo(readable > .7 ? readable : .7, 1e-6));
    }
    expect(tester.getTopLeft(control('Close')).dy, greaterThanOrEqualTo(4));
    expect(tester.getBottomLeft(control('Download')).dy, lessThanOrEqualTo(596));
    expect(tester.getRect(control('Previous')).center.dy, 300);
    expect(tester.getRect(control('Next')).right, 792);
  });

  testWidgets('an edge control over a light image keeps readable ink behind its glyph', (tester) async {
    await pump(tester, brightness: Brightness.light);
    final tokens = FrostThemeTokens.of(tester.element(find.byType(FrostMediaChrome)));
    final protection = find.ancestor(of: control('Previous'), matching: find.byType(CustomPaint)).evaluate().map((e) => e.widget as CustomPaint);
    final painter = protection.map((paint) => paint.painter).firstWhere((painter) => painter.runtimeType.toString() == '_EdgeProtectionPainter')!;
    // The glyph sits on the full-strength center of the protection.
    final color = (painter as dynamic).color as Color;
    final behind = Color.alphaBlend(color, const Color(0xFFFFFFFF));
    double luminance(Color c) => c.computeLuminance();
    final contrast = (luminance(tokens.onMediaInk) + .05) / (luminance(behind) + .05);
    expect(contrast, greaterThanOrEqualTo(4.5));
    await tester.tap(control('Previous'));
    await tester.tap(control('Next'));
    expect(pressed, ['Previous', 'Next']);
  });

  testWidgets('controls hide after the idle delay and return on pointer movement or a key', (tester) async {
    await pump(tester);
    expect(visible(tester), isTrue);
    await tester.pump(frostMediaChromeIdleDelay + const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(visible(tester), isFalse);
    // Hidden controls leave the tree, so they take no input or focus.
    expect(control('Close'), findsNothing);
    expect(pressed, isEmpty);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(400, 300));
    await mouse.moveTo(const Offset(410, 300));
    await tester.pump();
    expect(visible(tester), isTrue);
    await mouse.moveTo(const Offset(-10, -10));
    await tester.pump(frostMediaChromeIdleDelay + const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(visible(tester), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(visible(tester), isTrue);
  });

  testWidgets('hover, a held pointer and focus on the controls keep them shown', (tester) async {
    await pump(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: tester.getCenter(control('More')));
    await tester.pump(frostMediaChromeIdleDelay * 2);
    expect(visible(tester), isTrue);
    await mouse.moveTo(const Offset(400, 300));
    await tester.pump(frostMediaChromeIdleDelay + const Duration(milliseconds: 100));
    expect(visible(tester), isFalse);
    await mouse.moveTo(const Offset(-10, -10));
    await tester.pumpAndSettle();

    final touch = await tester.startGesture(const Offset(400, 300));
    await tester.pump();
    await touch.up();
    await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 10));
    expect(visible(tester), isTrue);
    final hold = await tester.startGesture(tester.getCenter(control('Download')));
    await tester.pump(frostMediaChromeIdleDelay * 2);
    expect(visible(tester), isTrue);
    await hold.cancel();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<FrostMediaChrome>(), isNotNull);
    await tester.pump(frostMediaChromeIdleDelay * 2);
    expect(visible(tester), isTrue);
  });

  testWidgets('a tap on the media toggles the controls and a double tap zooms instead', (tester) async {
    await pump(tester, autoHide: false);
    await tester.tapAt(const Offset(400, 300));
    await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 10));
    await tester.pumpAndSettle();
    expect(visible(tester), isFalse);
    // Without auto-hide they stay until the next tap.
    await tester.pump(frostMediaChromeIdleDelay * 2);
    await tester.tapAt(const Offset(400, 300));
    await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 10));
    await tester.pumpAndSettle();
    expect(visible(tester), isTrue);
    await tester.pump(frostMediaChromeIdleDelay * 2);
    expect(visible(tester), isTrue);

    await tester.tapAt(const Offset(400, 300));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();
    expect(zoomed, [true]);
    expect(visible(tester), isTrue);

    // A tap on a control is that control's.
    await tester.tap(control('Zoom in'));
    await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 10));
    expect(pressed, ['Zoom in']);
    expect(visible(tester), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a button over the media fires on tap-up, while a double tap on the media still zooms', (tester) async {
    await pump(tester);
    for (final label in ['Close', 'Download', 'Previous']) {
      final gesture = await tester.startGesture(tester.getCenter(control(label)));
      await tester.pump(const Duration(milliseconds: 30));
      await gesture.up();
      // Well inside the double-tap window: nothing waits for a second tap.
      await tester.pump(const Duration(milliseconds: 1));
      expect(pressed.last, label);
    }
    expect(pressed, ['Close', 'Download', 'Previous']);

    await tester.pump(kDoubleTapTimeout);
    await tester.tapAt(const Offset(400, 300));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();
    expect(zoomed, [true]);
    expect(tester.takeException(), isNull);
  });

  group('keys while the controls are hidden', () {
    Future<void> hide(WidgetTester tester) async {
      await tester.pump(frostMediaChromeIdleDelay + const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(find.byType(FrostVideoChrome), findsNothing);
    }

    testWidgets('typing in a field beside the viewer leaves them hidden', (tester) async {
      final field = FocusNode();
      addTearDown(field.dispose);
      await tester.pumpWidget(
        frostTestApp(
          Column(
            children: [
              FrostTextField(focusNode: field, placeholder: 'Comment'),
              Expanded(
                child: FrostMediaViewport(
                  overlay: FrostMediaChrome(top: button('Close')),
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      );
      field.requestFocus();
      await tester.pump();
      await hide(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pump();
      expect(find.byType(FrostVideoChrome), findsNothing);

      field.unfocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pump();
      expect(find.byType(FrostVideoChrome), findsWidgets);
    });

    testWidgets('a route on top of the viewer keeps its keys', (tester) async {
      await pump(tester);
      final navigator = Navigator.of(tester.element(find.byType(FrostMediaChrome)));
      navigator.push(PageRouteBuilder<void>(opaque: false, pageBuilder: (_, _, _) => const SizedBox.expand()));
      await tester.pumpAndSettle();
      await hide(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pump();
      expect(find.byType(FrostVideoChrome), findsNothing);
    });
  });
}
