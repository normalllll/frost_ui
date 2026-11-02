import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_window/frost_window.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('native caption state preserves single buttons and reuses unchanged theme icons', () {
    final bytes = Uint8List.fromList([137, 80, 78, 71]);
    Map<Object?, Object?> native(Uint8List icon) => {
      'captionStyle': 'breeze',
      'leftButtons': ['close'],
      'rightButtons': <String>[],
      'captionIcons': {'close': icon},
    };
    final first = FrostWindowState.fromMap(native(bytes));
    expect(first.captionStyle, FrostCaptionStyle.breeze);
    expect(first.leftButtons, [FrostCaptionAction.close]);
    expect(first.rightButtons, isEmpty);
    final next = FrostWindowState.fromMap(native(Uint8List.fromList(bytes)), previous: first);
    expect(identical(first.captionIcons[FrostCaptionIcon.close], next.captionIcons[FrostCaptionIcon.close]), isTrue);
    final missing = FrostWindowState.fromMap({'captionStyle': 'adwaita', 'captionIcons': <String, Object>{}}, previous: first);
    expect(missing.captionIcons, isEmpty);
    expect(() => first.captionIcons.clear(), throwsUnsupportedError);
  });

  test('an unknown native button or icon name is a malformed state, like an unknown caption mode', () {
    expect(() => FrostWindowState.fromMap({'captionMode': 'sparkle'}), throwsFormatException);
    expect(
      () => FrostWindowState.fromMap({
        'rightButtons': ['close', 'sparkle'],
      }),
      throwsFormatException,
    );
    expect(
      () => FrostWindowState.fromMap({
        'leftButtons': ['sparkle'],
      }),
      throwsFormatException,
    );
    expect(
      () => FrostWindowState.fromMap({
        'captionIcons': {
          'sparkle': Uint8List.fromList([1]),
        },
      }),
      throwsFormatException,
    );
  });

  group('failures', () {
    const channel = MethodChannel('frost_controller_failure_test');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late FrostWindowController controller;
    late List<MethodCall> calls;
    late Map<String, Object?> nativeState;
    Future<Object?> Function(MethodCall call)? onCommand;

    setUp(() {
      calls = [];
      onCommand = null;
      nativeState = {'revision': 1, 'active': true};
      controller = FrostWindowController(minimumSize: const Size(480, 360), channel: channel);
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'getState') return nativeState;
        if (call.method == 'getDiagnostics' || call.method == 'configure') return null;
        return onCommand?.call(call);
      });
    });

    tearDown(() {
      controller.dispose();
      messenger.setMockMethodCallHandler(channel, null);
    });

    test('a failed command fails only that command', () async {
      await controller.initialize();
      var notifications = 0;
      controller.addListener(() => notifications++);
      onCommand = (call) async => throw PlatformException(code: call.method == 'copyImage' ? 'clipboard_unavailable' : 'boom');
      await expectLater(controller.setToolbar(title: 'a', dark: false), throwsA(isA<FrostWindowFailure>()));
      await expectLater(controller.copyImage(dib: Uint8List(1), png: Uint8List(1)), throwsA(isA<FrostWindowFailure>()));
      expect(controller.failed, false);
      expect(controller.ready, true);
      expect(controller.failureMethod, isNull);
      expect(controller.failureCode, isNull);
      expect(notifications, 0);
      onCommand = null;
      await controller.minimize();
      expect(calls.last.method, 'minimize');
    });

    test('a lost native channel or window marks the controller failed and initialize can retry', () async {
      await controller.initialize();
      onCommand = (call) async => throw MissingPluginException();
      await expectLater(controller.minimize(), throwsA(isA<FrostWindowFailure>()));
      expect(controller.failed, true);
      expect(controller.ready, false);
      expect(controller.failureCode, 'missing_plugin');
      onCommand = null;
      await controller.initialize();
      expect(controller.failed, false);
      expect(controller.ready, true);

      onCommand = (call) async => throw PlatformException(code: 'window_unavailable');
      await expectLater(controller.close(), throwsA(isA<FrostWindowFailure>()));
      expect(controller.failed, true);
      expect(controller.failureCode, 'window_unavailable');
    });

    test('initialize with an unknown button name fails consistently and can be retried', () async {
      nativeState = {
        'revision': 1,
        'active': true,
        'rightButtons': ['close', 'sparkle'],
      };
      await expectLater(controller.initialize(), throwsA(isA<FrostWindowFailure>()));
      expect(controller.ready, false);
      expect(controller.failed, true);
      expect(controller.failureMethod, 'getState');
      expect(controller.failureCode, 'invalid_state');
      expect(controller.state.revision, -1);
      expect(controller.state.rightButtons, const FrostWindowState().rightButtons);

      nativeState = {
        'revision': 2,
        'active': true,
        'rightButtons': ['close'],
      };
      await controller.initialize();
      expect(controller.ready, true);
      expect(controller.failed, false);
      expect(controller.failureCode, isNull);
      expect(controller.state.rightButtons, [FrostCaptionAction.close]);
    });

    test('a malformed native state is rejected without changing the controller', () async {
      await controller.initialize();
      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('stateChanged', {
            'revision': 5,
            'rightButtons': ['sparkle'],
          }),
        ),
        (_) {},
      );
      expect(controller.ready, true);
      expect(controller.state.revision, 1);
      nativeState = {
        'revision': 2,
        'geometry': {'sparkle': 1},
        'rightButtons': ['sparkle'],
      };
      await expectLater(controller.queryGeometry(), throwsA(isA<FrostWindowFailure>()));
      expect(controller.ready, true);
      expect(controller.state.revision, 1);
    });
  });
}
