import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_window/frost_window.dart';

FrostDisplay display({String id = 'primary', double width = 1920, double height = 1040, double scale = 1.25, double x = 0, bool primary = true}) =>
    FrostDisplay(
      id: id,
      bounds: Rect.fromLTWH(x, 0, width, height + 40),
      workArea: Rect.fromLTWH(x, 0, width, height),
      scale: scale,
      coordinateScale: scale,
      primary: primary,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final environment = FrostWindowEnvironment(displays: [display()]);
  test('first window fits work area, centers and preserves 16:10', () {
    final result = recommendFrostWindow(environment);
    expect(result.rect.width / result.rect.height, closeTo(1.6, .000001));
    expect(result.rect.height, closeTo(748.8, .0001));
    expect(result.rect.center.dx, closeTo(768, .000001));
    expect(result.rect.center.dy, closeTo(416, .000001));
    expect(result.maximized, false);
    expect(result.rect.right, lessThanOrEqualTo(1536));
  });
  test('2K at 150 percent defaults to 1280 by 800', () {
    final result = recommendFrostWindow(FrostWindowEnvironment(displays: [display(width: 2560, height: 1400, scale: 1.5)]));
    expect(result.rect.size, const Size(1280, 800));
  });
  test('explicit size, ratio and maximum fraction', () {
    final ratio = recommendFrostWindow(environment, sizing: const FrostWindowSizing(aspectRatio: 16 / 9, maxWorkAreaFraction: .75));
    // Height is the limiting axis at 75% of this work area.
    expect(ratio.rect.width, closeTo(1109.333333333333, .000001));
    expect(ratio.rect.width / ratio.rect.height, closeTo(16 / 9, .001));
    final size = recommendFrostWindow(environment, sizing: const FrostWindowSizing(preferredSize: Size(800, 600)));
    expect(size.rect.size, const Size(800, 600));
  });
  test('minimum content beats margin, actual work area beats minimum', () {
    final tiny = FrostWindowEnvironment(displays: [display(width: 500, height: 350, scale: 1)]);
    expect(recommendFrostWindow(tiny).rect, const Rect.fromLTWH(0, 0, 500, 350));
    final small = FrostWindowEnvironment(displays: [display(width: 700, height: 500, scale: 1)]);
    expect(recommendFrostWindow(small).rect.size, const Size(640, 480));
  });
  test('target priority supports cursor, primary and missing selection', () {
    final env = FrostWindowEnvironment(
      displays: [
        display(),
        display(id: 'left', x: -2560, width: 2560, height: 1400, scale: 1.5, primary: false),
      ],
      cursorDisplayId: 'left',
    );
    expect(recommendFrostWindow(env).displayId, 'primary');
    expect(recommendFrostWindow(env, useCursor: true).displayId, 'left');
    expect(recommendFrostWindow(env, displayId: 'primary', useCursor: true).displayId, 'primary');
    expect(recommendFrostWindow(env, displayId: 'missing').displayId, 'primary');
    // Negative global origins never contaminate the saved logical offset.
    expect(recommendFrostWindow(env, displayId: 'left').rect.left, greaterThanOrEqualTo(0));
  });
  test('unchanged saved bounds and maximize target survive a round trip', () {
    const original = FrostWindowPlacement(
      displayId: 'primary',
      rect: Rect.fromLTWH(50, 70, 900, 600),
      maximized: true,
      workAreaSize: Size(1536, 832),
      displayScale: 1.25,
    );
    final result = validateFrostWindow(FrostWindowPlacement.fromMap(original.toMap()), environment);
    expect(result.placement, original);
    expect(result.adjustments, isEmpty);
  });
  test('removed monitor falls back to recommendation rather than stale maximized bounds', () {
    const saved = FrostWindowPlacement(displayId: 'removed', rect: Rect.fromLTWH(-3000, 20, 1000, 700), maximized: true);
    final result = validateFrostWindow(saved, environment);
    expect(result.adjustments, {FrostWindowPlacementAdjustment.displayMissing});
    expect(result.placement, recommendFrostWindow(environment));
    expect(result.placement.maximized, false);
  });
  test('work area and DPI changes keep logical size, proportional free-space position', () {
    const saved = FrostWindowPlacement(displayId: 'primary', rect: Rect.fromLTWH(400, 200, 800, 600), workAreaSize: Size(1600, 1000), displayScale: 1);
    final result = validateFrostWindow(saved, environment);
    expect(result.placement.rect, const Rect.fromLTWH(368, 116, 800, 600));
    expect(result.adjustments, {FrostWindowPlacementAdjustment.displayChanged});
    expect(result.placement.displayScale, 1.25);
  });
  test('environment changes use the final fitted size when preserving relative position', () {
    const saved = FrostWindowPlacement(displayId: 'primary', rect: Rect.fromLTWH(400, 200, 800, 600), workAreaSize: Size(1600, 1000), displayScale: 1);
    final result = validateFrostWindow(saved, environment, sizing: const FrostWindowSizing(minimumSize: Size(1200, 700)));
    expect(result.placement.rect, const Rect.fromLTWH(168, 66, 1200, 700));
    expect(result.adjustments, {FrostWindowPlacementAdjustment.displayChanged, FrostWindowPlacementAdjustment.clamped});
  });
  for (final rect in [const Rect.fromLTWH(-100, -50, 900, 600), const Rect.fromLTWH(2000, 3000, 3000, 2000), const Rect.fromLTWH(30, 30, 10, 10)]) {
    test('out-of-view or invalid minimum is clamped: $rect', () {
      final result = validateFrostWindow(FrostWindowPlacement(displayId: 'primary', rect: rect), environment);
      expect(result.adjustments, contains(FrostWindowPlacementAdjustment.clamped));
      expect(result.placement.rect.left, greaterThanOrEqualTo(0));
      expect(result.placement.rect.top, greaterThanOrEqualTo(0));
      expect(result.placement.rect.right, lessThanOrEqualTo(1536));
      expect(result.placement.rect.bottom, lessThanOrEqualTo(832));
      expect(result.placement.rect.width, greaterThanOrEqualTo(640));
      expect(result.placement.rect.height, greaterThanOrEqualTo(480));
    });
  }
  for (final rect in [const Rect.fromLTWH(double.nan, 0, 800, 600), Rect.zero, const Rect.fromLTWH(0, 0, -1, 50)]) {
    test('corrupt saved geometry falls back: $rect', () {
      final result = validateFrostWindow(FrostWindowPlacement(displayId: 'primary', rect: rect), environment);
      expect(result.adjustments, {FrostWindowPlacementAdjustment.invalidPlacement});
      expect(result.placement, recommendFrostWindow(environment));
    });
  }
  test('runtime compositor capability ignores only position and reports it', () {
    final env = FrostWindowEnvironment(displays: [display()], positionSupport: FrostWindowPositionSupport.compositorControlled);
    final result = validateFrostWindow(const FrostWindowPlacement(displayId: 'primary', rect: Rect.fromLTWH(9999, -200, 900, 600), maximized: true), env);
    expect(result.adjustments, {FrostWindowPlacementAdjustment.positionIgnoredUnsupported});
    expect(result.placement.rect, const Rect.fromLTWH(0, 0, 900, 600));
    expect(result.placement.maximized, true);
    final geometry = FrostWindowGeometry(placement: result.placement, frame: result.placement.rect, positionSupport: env.positionSupport);
    expect(geometry.position, isNull);
    expect(geometry.placement.displayId, 'primary');
  });
  test('Wayland missing topology-local ID retains usable size and maximize', () {
    final env = FrostWindowEnvironment(displays: [display()], positionSupport: FrostWindowPositionSupport.compositorControlled);
    final result = validateFrostWindow(const FrostWindowPlacement(displayId: 'old-topology', rect: Rect.fromLTWH(50, 80, 900, 600), maximized: true), env);
    expect(result.adjustments, {FrostWindowPlacementAdjustment.displayMissing, FrostWindowPlacementAdjustment.positionIgnoredUnsupported});
    expect(result.placement.rect.size, const Size(900, 600));
    expect(result.placement.maximized, true);
    expect(result.placement.displayId, 'primary');
  });
  for (final sizing in [
    const FrostWindowSizing(maxWorkAreaFraction: 0),
    const FrostWindowSizing(aspectRatio: double.nan),
    const FrostWindowSizing(minimumSize: Size(-1, 2)),
  ]) {
    test(
      'invalid sizing rejected without native mutation: $sizing',
      () => expect(() => recommendFrostWindow(environment, sizing: sizing), throwsArgumentError),
    );
  }

  const channel = MethodChannel('frost_window_placement_test');
  Map<String, Object?> nativeState(int revision, double x) => {
    'revision': revision,
    'geometry': {
      ...const FrostWindowPlacement(displayId: 'primary', rect: Rect.fromLTWH(0, 0, 900, 600)).toMap(),
      'rect': [x, 0.0, x + 900, 600.0],
      'frame': [x, 0.0, x + 900, 600.0],
    },
  };
  Future<void> event(Map<String, Object?> state) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall('stateChanged', state)),
      (_) {},
    );
  }

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => switch (call.method) {
        'getState' => nativeState(1, 0),
        'getEnvironment' => {
          'displays': [
            {
              'id': 'primary',
              'bounds': [0, 0, 1920, 1080],
              'workArea': [0, 0, 1920, 1040],
              'scale': 1.25,
              'coordinateScale': 1.25,
              'primary': true,
            },
          ],
        },
        _ => null,
      },
    );
  });
  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
  testWidgets('geometry trailing debounce ignores hover duplicates and stale replies; disposal cancels', (tester) async {
    final controller = FrostWindowController(minimumSize: const Size(640, 480), channel: channel);
    await controller.initialize();
    var changes = 0;
    controller.geometry.addListener(() => changes++);
    await event(nativeState(2, 10));
    await tester.pump(const Duration(milliseconds: 150));
    await event(nativeState(3, 20));
    await tester.pump(const Duration(milliseconds: 150));
    expect(changes, 0);
    await event(nativeState(4, 20)); // Same geometry must not restart the timer.
    await tester.pump(const Duration(milliseconds: 50));
    expect(changes, 1);
    expect(controller.geometry.value!.position!.dx, 20);
    await event(nativeState(2, 99));
    await tester.pump(const Duration(milliseconds: 300));
    expect(changes, 1);
    await event(nativeState(5, 30));
    controller.dispose();
    await tester.pump(const Duration(seconds: 1));
    expect(changes, 1);
  });
  testWidgets('prepare cannot bypass the controller native minimum with a smaller sizing floor', (tester) async {
    final controller = FrostWindowController(minimumSize: const Size(1200, 800), channel: channel);
    final result = await controller.prepare(sizing: const FrostWindowSizing(preferredSize: Size(800, 600)));
    expect(result.placement.rect.size, const Size(1200, 800));
    controller.dispose();
  });
  testWidgets('maximize and display changes notify the debounced geometry listener', (tester) async {
    final controller = FrostWindowController(minimumSize: const Size(640, 480), channel: channel);
    await controller.initialize();
    await tester.pump(const Duration(milliseconds: 200));
    var changes = 0;
    controller.geometry.addListener(() => changes++);
    final state = nativeState(2, 0);
    final geometry = state['geometry']! as Map<String, Object?>;
    geometry['maximized'] = true;
    geometry['displayId'] = 'secondary';
    geometry['displayScale'] = 1.5;
    await event(state);
    expect(controller.state.geometry!.placement.maximized, true);
    expect(changes, 0);
    await tester.pump(const Duration(milliseconds: 200));
    expect(changes, 1);
    expect(controller.geometry.value!.placement.displayId, 'secondary');
    expect(controller.geometry.value!.placement.displayScale, 1.5);
    expect(controller.geometry.value!.placement.maximized, true);
    controller.dispose();
  });
  testWidgets('prepare computes before apply, never implicitly shows or persists', (tester) async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'getState') return nativeState(1, 0);
      if (call.method == 'getEnvironment') {
        return {
          'displays': [
            {
              'id': 'primary',
              'bounds': [0, 0, 1920, 1080],
              'workArea': [0, 0, 1920, 1040],
              'scale': 1.25,
              'coordinateScale': 1.25,
              'primary': true,
            },
          ],
        };
      }
      if (call.method == 'applyPlacement') {
        final size = FrostWindowPlacement.fromMap(call.arguments as Map<Object?, Object?>).rect.size;
        expect(size.width, closeTo(1198.08, .000001));
        expect(size.height, closeTo(748.8, .000001));
      }
      return null;
    });
    final controller = FrostWindowController(minimumSize: const Size(640, 480), channel: channel);
    final result = await controller.prepare();
    expect(result.adjustments, {FrostWindowPlacementAdjustment.recommended});
    expect(calls, ['getDiagnostics', 'configure', 'getState', 'getEnvironment', 'applyPlacement']);
    await controller.show();
    expect(calls.last, 'show');
    controller.dispose();
  });
}
