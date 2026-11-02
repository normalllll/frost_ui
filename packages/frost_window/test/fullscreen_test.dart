import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_window/frost_window.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('frost_fullscreen_test');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late FrostWindowController controller;
  late List<bool> targets;
  late Map<String, Object> actual;
  void event(Map<String, Object> state) {
    TestWidgetsFlutterBinding.instance.channelBuffers.push(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall('stateChanged', state)),
      (_) {},
    );
  }

  Map<String, Object> state(int revision, bool fullscreen, {bool transitioning = false}) => {
    'revision': revision,
    'fullscreen': fullscreen,
    'fullscreenAvailable': true,
    'fullscreenTransitioning': transitioning,
  };

  void setup() {
    targets = [];
    actual = state(1, false);
    controller = FrostWindowController(minimumSize: const Size(480, 360), channel: channel, fullscreenTimeout: const Duration(seconds: 1));
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getState') return actual;
      if (call.method == 'setFullscreen') {
        targets.add(call.arguments as bool);
        return actual;
      }
      return null;
    });
  }

  tearDown(() {
    controller.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  });

  testWidgets('acknowledgement waits for actual state; stale replies cannot undo external exit', (tester) async {
    setup();
    await controller.initialize();
    var complete = false;
    final enter = controller.setFullscreen(true).then((_) => complete = true);
    await tester.pump();
    expect(targets, [true]);
    expect(complete, false);
    event(state(3, true));
    await tester.pump();
    await enter;
    expect(complete, true);
    event(state(4, false));
    await tester.pump();
    event(state(2, true));
    await tester.pump();
    expect(controller.state.fullscreen, false);
    expect(controller.state.revision, 4);
    expect(targets, [true]); // No sticky request re-enters after external exit.
  });

  testWidgets('a newer actual event wins over a delayed command reply', (tester) async {
    setup();
    await controller.initialize();
    final reply = Completer<Map<String, Object>>();
    messenger.setMockMethodCallHandler(channel, (call) async => call.method == 'setFullscreen' ? reply.future : null);
    var completed = false;
    final enter = controller.setFullscreen(true).then((_) => completed = true);
    await tester.pump();
    event(state(5, true));
    await tester.pump();
    expect(controller.state.fullscreen, true);
    expect(completed, false);
    reply.complete(state(2, false));
    await tester.pump();
    await enter;
    expect(controller.state.revision, 5);
    expect(controller.state.fullscreen, true);
    // Avoid an actual/fullscreen cleanup command using the held mock reply.
    event(state(6, false));
    await tester.pump();
  });

  testWidgets('same targets share a wait; reversal supersedes and waits through entry', (tester) async {
    setup();
    await controller.initialize();
    final enter = controller.setFullscreen(true);
    expect(identical(enter, controller.setFullscreen(true)), true);
    final superseded = expectLater(enter, throwsA(isA<FrostFullscreenFailure>().having((e) => e.reason, 'reason', FrostFullscreenFailureReason.superseded)));
    await tester.pump();
    actual = state(2, false, transitioning: true);
    final exit = controller.setFullscreen(false);
    await superseded;
    await tester.pump();
    expect(targets, [true, false]);
    event(state(3, true, transitioning: true));
    await tester.pump();
    event(state(4, false));
    await tester.pump();
    await exit;
    expect(controller.fullscreenFailure, isNull);
  });

  testWidgets('an unawaited request that is superseded or disposed raises no unhandled error', (tester) async {
    setup();
    await controller.initialize();
    unawaited(controller.setFullscreen(true));
    await tester.pump();
    actual = state(2, false, transitioning: true);
    final exit = controller.setFullscreen(false);
    await tester.pump();
    expect(targets, [true, false]);
    event(state(3, false));
    await tester.pump();
    await exit;
    expect(controller.fullscreenFailure, isNull);
    unawaited(controller.setFullscreen(true));
    await tester.pump();
    controller.dispose();
    await tester.pump();
    // tearDown owns a separate, unused controller after this disposal.
    controller = FrostWindowController(minimumSize: const Size(480, 360), channel: const MethodChannel('unused'));
  });

  testWidgets('failed exit preserves actual state and frame health; retry succeeds', (tester) async {
    setup();
    await controller.initialize();
    actual = state(2, true);
    event(actual);
    await tester.pump();
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'setFullscreen') throw PlatformException(code: 'fullscreen_failed');
      return null;
    });
    await expectLater(controller.setFullscreen(false), throwsA(isA<FrostFullscreenFailure>()));
    expect(controller.state.fullscreen, true);
    expect(controller.ready, true);
    expect(controller.fullscreenFailure?.reason, FrostFullscreenFailureReason.rejected);
    messenger.setMockMethodCallHandler(channel, (call) async => call.method == 'setFullscreen' ? state(3, false) : null);
    await controller.setFullscreen(false);
    expect(controller.state.fullscreen, false);
    expect(controller.fullscreenFailure, isNull);
  });

  testWidgets('timeout cancels pending entry; unavailable is distinct', (tester) async {
    setup();
    await controller.initialize();
    final pending = expectLater(
      controller.setFullscreen(true),
      throwsA(isA<FrostFullscreenFailure>().having((e) => e.reason, 'reason', FrostFullscreenFailureReason.timeout)),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await pending;
    await tester.pump();
    expect(targets, [true, false]);
    event({'revision': 4, 'fullscreen': false, 'fullscreenAvailable': false});
    await tester.pump();
    await expectLater(
      controller.setFullscreen(true),
      throwsA(isA<FrostFullscreenFailure>().having((e) => e.reason, 'reason', FrostFullscreenFailureReason.unavailable)),
    );
    expect(controller.ready, true);
  });

  testWidgets('disposal supersedes in-flight entry and sends native exit', (tester) async {
    setup();
    await controller.initialize();
    final pending = expectLater(
      controller.setFullscreen(true),
      throwsA(isA<FrostFullscreenFailure>().having((e) => e.reason, 'reason', FrostFullscreenFailureReason.disposed)),
    );
    await tester.pump();
    controller.dispose();
    await pending;
    await tester.pump();
    expect(targets, [true, false]);
    // tearDown owns a separate, unused controller after this disposal.
    controller = FrostWindowController(minimumSize: const Size(480, 360), channel: const MethodChannel('unused'));
  });
}
