import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/layout/window_move_area.dart' show FrostWindowMoveScope;
import 'package:material_ui/material_ui.dart';

import 'support.dart';

const _picture = ValueKey('picture'), _strip = ValueKey('scrub strip');

/// A small player: a picture that toggles on a tap, a button at the top and a
/// slider along the bottom, and a strip at the left that scrubs on a
/// horizontal drag of any pointer, showing no cursor of its own.
Widget _player({required VoidCallback onTap, required VoidCallback onPlay, required ValueChanged<double> onSeek, VoidCallback? onScrub}) => Stack(
  fit: StackFit.expand,
  children: [
    GestureDetector(
      key: _picture,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: const ColoredBox(color: Color(0xFF000000)),
    ),
    Align(
      alignment: Alignment.topCenter,
      child: FrostButton(label: 'Play', onPressed: onPlay),
    ),
    Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(width: 300, child: FrostSlider(value: .5, semanticLabel: 'Position', onChanged: onSeek)),
    ),
    Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        key: _strip,
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (_) => onScrub?.call(),
        child: const SizedBox(width: 120, height: 120),
      ),
    ),
  ],
);

void main() {
  late int moves, taps, plays, seeks;
  late Future<void> Function() startMove;
  setUp(() {
    moves = taps = plays = seeks = 0;
    startMove = () async => moves++;
  });

  Future<void> pump(WidgetTester tester, {bool scoped = true}) async {
    tester.view.physicalSize = const Size(480, 270);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Widget area = FrostWindowMoveArea(
      child: _player(onTap: () => taps++, onPlay: () => plays++, onSeek: (_) => seeks++),
    );
    if (scoped) area = FrostWindowMoveScope(startMove: () => startMove(), child: area);
    await tester.pumpWidget(frostTestApp(area));
    await tester.pumpAndSettle();
  }

  Future<void> drag(WidgetTester tester, Offset from, Offset by, {PointerDeviceKind kind = PointerDeviceKind.mouse, int buttons = kPrimaryButton}) async {
    final gesture = await tester.startGesture(from, kind: kind, buttons: buttons);
    for (var step = 1; step <= 4; step++) {
      await gesture.moveTo(from + by * (step / 4));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  Offset picture(WidgetTester tester) => tester.getRect(find.byKey(_picture)).center + const Offset(0, -40);

  testWidgets('a mouse drag on the picture moves the window and a click still reaches it', (tester) async {
    await pump(tester);
    await drag(tester, picture(tester), const Offset(60, 30));
    expect(moves, 1);
    expect(taps, 0, reason: 'a drag is not a tap');

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.down(picture(tester));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(taps, 1, reason: 'a plain click toggles the player');
    expect(moves, 1);
  });

  testWidgets('a press on a control inside the area never moves the window', (tester) async {
    await pump(tester);
    await drag(tester, tester.getCenter(find.text('Play')), const Offset(60, 30));
    expect(moves, 0, reason: 'a button shows its own cursor');

    final slider = tester.getCenter(find.byType(FrostSlider));
    await drag(tester, slider, const Offset(80, 0));
    expect(seeks, greaterThan(0));
    await drag(tester, slider, const Offset(0, -60));
    expect(moves, 0, reason: 'a slider keeps its drag in either direction');

    await drag(tester, tester.getCenter(find.byKey(_strip)), const Offset(0, -60));
    expect(moves, 0, reason: 'a gesture that takes mouse drags keeps the press, even across its axis');
    expect(plays, 0);
  });

  testWidgets('touch and secondary-button drags do not move the window', (tester) async {
    await pump(tester);
    await drag(tester, picture(tester), const Offset(60, 30), kind: PointerDeviceKind.touch);
    await drag(tester, picture(tester), const Offset(60, 30), buttons: kSecondaryMouseButton);
    expect(moves, 0);
  });

  testWidgets('without a window host the area is only its child', (tester) async {
    await pump(tester, scoped: false);
    await drag(tester, picture(tester), const Offset(60, 30));
    expect(moves, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a platform without a native window move reports it once', (tester) async {
    startMove = () async {
      moves++;
      throw FrostWindowUnsupportedFailure('startMove');
    };
    await pump(tester);
    await drag(tester, picture(tester), const Offset(60, 30));
    expect(tester.takeException(), isA<FrostWindowUnsupportedFailure>());
    await drag(tester, picture(tester), const Offset(60, 30));
    expect(moves, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the window host hands the drag to its controller', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const channel = MethodChannel('frost_window_move_area_test');
    final calls = <String>[];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return call.method == 'getState' ? <String, Object>{'revision': 1, 'active': true} : null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final controller = FrostWindowController(minimumSize: const Size(320, 180), channel: channel);
    addTearDown(controller.dispose);
    tester.view.physicalSize = const Size(480, 270);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      FrostScope(
        config: testConfig,
        child: MaterialApp(
          theme: FrostTheme.build(config: testConfig, brightness: Brightness.light, platform: TargetPlatform.windows, locale: const Locale('en')),
          home: FrostWindowHost(
            controller: controller,
            title: 'Mini',
            child: FrostWindowMoveArea(child: _player(onTap: () => taps++, onPlay: () => plays++, onSeek: (_) => seeks++)),
          ),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump();
    }
    await drag(tester, picture(tester), const Offset(60, 30));
    expect(calls, contains('startMove'));
  });
}
