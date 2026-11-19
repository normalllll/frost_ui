import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_window/frost_window.dart';

Map<String, Object?> _geometry({bool alwaysOnTop = false, Object? occluded, Rect rect = const Rect.fromLTWH(10, 20, 800, 600), bool maximized = false}) => {
  'displayId': 'display',
  'rect': [rect.left, rect.top, rect.right, rect.bottom],
  'frame': [rect.left, rect.top, rect.right, rect.bottom],
  'workAreaSize': [0.0, 0.0, 1920.0, 1080.0],
  'displayScale': 1.0,
  'maximized': maximized,
  'alwaysOnTop': alwaysOnTop,
  'occluded': ?occluded,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('frost_always_on_top_test');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late FrostWindowController controller;
  late List<MethodCall> calls;
  late Map<String, Object?> nativeGeometry;
  Future<Object?> Function(MethodCall call)? onCommand;

  Map<String, Object?> state(int revision) => {'revision': revision, 'geometry': nativeGeometry};

  Future<void> nativeEvent(int revision) => messenger.handlePlatformMessage(
    channel.name,
    const StandardMethodCodec().encodeMethodCall(MethodCall('stateChanged', state(revision))),
    (_) {},
  );

  setUp(() {
    calls = [];
    onCommand = null;
    nativeGeometry = _geometry();
    controller = FrostWindowController(minimumSize: const Size(480, 360), channel: channel, geometryDebounce: const Duration(milliseconds: 1));
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'getState') return state(1);
      if (call.method == 'getDiagnostics' || call.method == 'configure') return null;
      return onCommand?.call(call);
    });
  });

  tearDown(() {
    controller.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('setAlwaysOnTop sends the target and the actual state comes back through geometry', () async {
    await controller.setAlwaysOnTop(true);
    expect(calls.last.method, 'setAlwaysOnTop');
    expect(calls.last.arguments, true);

    nativeGeometry = _geometry(alwaysOnTop: true);
    await nativeEvent(2);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(controller.geometry.value?.alwaysOnTop, true);

    nativeGeometry = _geometry();
    await nativeEvent(3);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(controller.geometry.value?.alwaysOnTop, false);
  });

  test('geometry publishes occluded from native events and keeps unknown as null', () async {
    nativeGeometry = _geometry();
    final queried = await controller.queryGeometry();
    expect(queried.occluded, isNull);
    expect(queried.alwaysOnTop, false);

    final seen = <bool?>[];
    controller.geometry.addListener(() => seen.add(controller.geometry.value?.occluded));
    nativeGeometry = _geometry(occluded: true);
    await nativeEvent(2);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    nativeGeometry = _geometry(occluded: false);
    await nativeEvent(3);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(seen, [true, false]);
  });

  test('setFrame sends a work-area-relative rectangle and an optional display', () async {
    await controller.setFrame(const Rect.fromLTWH(1500, 800, 320, 180));
    expect(calls.last.method, 'setFrame');
    expect(calls.last.arguments, {
      'rect': [1500.0, 800.0, 1820.0, 980.0],
    });
    await controller.setFrame(const Rect.fromLTWH(0, 0, 320, 180), displayId: 'other');
    expect((calls.last.arguments as Map)['displayId'], 'other');
  });

  test('a captured placement restores the window after a direct frame', () async {
    nativeGeometry = _geometry(rect: const Rect.fromLTWH(100, 50, 1000, 700), maximized: true);
    final before = (await controller.queryGeometry()).placement;
    expect(before.maximized, true);
    expect(before.rect, const Rect.fromLTWH(100, 50, 1000, 700));

    await controller.setFrame(const Rect.fromLTWH(1500, 800, 320, 180));
    await controller.applyPlacement(before);
    expect(calls.last.method, 'applyPlacement');
    expect(FrostWindowPlacement.fromMap((calls.last.arguments as Map).cast<Object?, Object?>()), before);
  });

  test('an unsupported platform throws a typed failure and the controller stays healthy', () async {
    onCommand = (call) async => throw PlatformException(code: 'unsupported');
    await expectLater(
      controller.setAlwaysOnTop(true),
      throwsA(isA<FrostWindowUnsupportedFailure>().having((e) => e.method, 'method', 'setAlwaysOnTop')),
    );
    await expectLater(controller.setFrame(const Rect.fromLTWH(0, 0, 320, 180)), throwsA(isA<FrostWindowUnsupportedFailure>()));
    expect(controller.failed, false);
    expect(controller.ready, true);
  });

  test('other native errors stay generic failures', () async {
    onCommand = (call) async => throw PlatformException(code: 'always_on_top_failed');
    await expectLater(
      controller.setAlwaysOnTop(true),
      throwsA(isA<FrostWindowFailure>().having((e) => e, 'type', isNot(isA<FrostWindowUnsupportedFailure>()))),
    );
    expect(controller.failed, false);
  });
}
