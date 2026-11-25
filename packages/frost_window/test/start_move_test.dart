import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_window/frost_window.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('frost_start_move_test');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late FrostWindowController controller;
  late List<MethodCall> calls;
  Future<Object?> Function(MethodCall call)? onCommand;

  setUp(() {
    calls = [];
    onCommand = null;
    controller = FrostWindowController(minimumSize: const Size(480, 360), channel: channel);
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'getState') {
        return {
          'revision': 1,
          'geometry': {
            'displayId': 'display',
            'rect': [10.0, 20.0, 490.0, 290.0],
            'frame': [10.0, 20.0, 490.0, 290.0],
            'workAreaSize': [0.0, 0.0, 1920.0, 1080.0],
            'displayScale': 1.0,
            'maximized': false,
          },
        };
      }
      if (call.method == 'getDiagnostics' || call.method == 'configure') return null;
      return onCommand?.call(call);
    });
  });

  tearDown(() {
    controller.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('startMove hands the press to the native window move', () async {
    await controller.startMove();
    expect(calls.last.method, 'startMove');
    expect(calls.last.arguments, isNull);
  });

  test('startMove reports a platform without a native window move', () async {
    onCommand = (call) async => throw PlatformException(code: 'unsupported', message: '${call.method} is not available.');
    await expectLater(
      controller.startMove(),
      throwsA(isA<FrostWindowUnsupportedFailure>().having((failure) => failure.method, 'method', 'startMove')),
    );
  });
}
