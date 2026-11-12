import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/feedback/_pull_refresh.dart';

import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a pull from the failed hold', () {
    testWidgets('scrolling up during the hold ends the failed state without a refresh', (tester) async {
      final rig = await _Rig.mount(tester);
      await rig.fail();
      expect(rig.value.phase, FrostPullRefreshPhase.failed);

      rig.start();
      expect(rig.value.phase, FrostPullRefreshPhase.drag);
      expect(rig.value.extent, FrostPullRefresh.holdExtent);
      rig.update(pixels: 30, delta: 30);
      await _settle(tester);
      expect(rig.value.phase, FrostPullRefreshPhase.idle);
      expect(rig.value.extent, 0);
      expect(rig.refresh.calls, 1);
      await rig.unmount();
    });

    testWidgets('releasing without pulling down ends the failed state without a refresh', (tester) async {
      final rig = await _Rig.mount(tester);
      await rig.fail();
      rig.start();
      rig.end();
      await _settle(tester);
      expect(rig.value.phase, FrostPullRefreshPhase.idle);
      expect(rig.value.extent, 0);
      expect(rig.refresh.calls, 1);
      await rig.unmount();
    });

    testWidgets('pulling down past the held extent arms and refreshes again', (tester) async {
      final rig = await _Rig.mount(tester);
      await rig.fail();
      rig.start();
      expect(rig.value.phase, FrostPullRefreshPhase.drag);
      rig.overscroll(-1);
      expect(rig.value.phase, FrostPullRefreshPhase.armed);
      expect(rig.value.extent, greaterThan(FrostPullRefresh.holdExtent));
      rig.end();
      await _settle(tester);
      expect(rig.refresh.calls, 2);
      expect(rig.value.phase, FrostPullRefreshPhase.refreshing);
      await rig.unmount();
    });
  });

  group('starting a pull', () {
    testWidgets('a start while the last pull never ended retracts it without a refresh and begins a new one', (tester) async {
      final rig = await _Rig.mount(tester);
      rig.start();
      rig.overscroll(-180);
      expect(rig.value.phase, FrostPullRefreshPhase.armed);
      // The scrollable went away mid-gesture, so no end arrives; the next one
      // starts.
      rig.start();
      expect(rig.refresh.calls, 0);
      expect(rig.value.phase, FrostPullRefreshPhase.drag);
      rig.end();
      await _settle(tester);
      expect(rig.value.phase, FrostPullRefreshPhase.idle);
      expect(rig.value.extent, 0);
      expect(rig.refresh.calls, 0);
      await rig.unmount();
    });

    testWidgets('a pull that starts during a retraction takes over from the current extent', (tester) async {
      final rig = await _Rig.mount(tester);
      rig.start();
      rig.overscroll(-60);
      rig.end();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final retracting = rig.value.extent;
      expect(retracting, allOf(greaterThan(0), lessThan(30)));
      expect(rig.value.phase, FrostPullRefreshPhase.drag);

      rig.start();
      expect(rig.value.phase, FrostPullRefreshPhase.drag);
      expect(rig.value.extent, retracting);
      await tester.pump(const Duration(milliseconds: 400));
      expect(rig.value.extent, retracting);
      rig.overscroll(-20);
      expect(rig.value.extent, closeTo(retracting + 10, .001));
      rig.end();
      await _settle(tester);
      expect(rig.value.phase, FrostPullRefreshPhase.idle);
      expect(rig.refresh.calls, 0);
      await rig.unmount();
    });

    testWidgets('a pull that starts while the done phase retracts takes over from the current extent', (tester) async {
      final rig = await _Rig.mount(tester);
      unawaited(rig.state.refresh());
      await _settle(tester);
      rig.refresh.last.complete(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(rig.value.phase, FrostPullRefreshPhase.done);
      final held = rig.value.extent;
      expect(held, greaterThan(0));

      rig.start();
      expect(rig.value.phase, anyOf(FrostPullRefreshPhase.drag, FrostPullRefreshPhase.armed));
      expect(rig.value.extent, held);
      await tester.pump(const Duration(milliseconds: 400));
      expect(rig.value.extent, held);
      rig.end();
      await _settle(tester);
      expect(rig.value.phase, FrostPullRefreshPhase.idle);
      expect(rig.refresh.calls, 1);
      await rig.unmount();
    });

    testWidgets('a start while refreshing does not begin a pull', (tester) async {
      final rig = await _Rig.mount(tester);
      unawaited(rig.state.refresh());
      await _settle(tester);
      rig.start();
      rig.overscroll(-100);
      rig.end();
      await _settle(tester);
      expect(rig.value.phase, FrostPullRefreshPhase.refreshing);
      expect(rig.value.extent, FrostPullRefresh.holdExtent);
      expect(rig.refresh.calls, 1);
      rig.refresh.last.complete(true);
      await tester.pump();
      await _settle(tester);
      await rig.unmount();
    });
  });

  group('late results', () {
    testWidgets('an asynchronous error that arrives after dispose is not reported', (tester) async {
      final rig = await _Rig.mount(tester);
      unawaited(rig.state.refresh());
      await _settle(tester);
      await tester.pumpWidget(const SizedBox());
      rig.refresh.last.completeError(StateError('late'));
      await tester.pump();
      await tester.pump(FrostPullRefresh.failedHold + const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('an asynchronous error while mounted is reported and fails the refresh', (tester) async {
      final rig = await _Rig.mount(tester);
      unawaited(rig.state.refresh());
      await _settle(tester);
      rig.refresh.last.completeError(StateError('now'));
      await tester.pump();
      expect(tester.takeException(), isA<StateError>());
      expect(rig.value.phase, FrostPullRefreshPhase.failed);
      await rig.unmount();
    });
  });

  group('enabled', () {
    testWidgets('becoming disabled mid-pull retracts to idle', (tester) async {
      final enabled = ValueNotifier<bool>(true);
      addTearDown(enabled.dispose);
      final rig = await _Rig.mount(tester, enabled: enabled);
      rig.start();
      rig.overscroll(-200);
      expect(rig.value.phase, FrostPullRefreshPhase.armed);
      enabled.value = false;
      await tester.pump();
      await _settle(tester);
      expect(rig.value.phase, FrostPullRefreshPhase.idle);
      expect(rig.value.extent, 0);
      rig.end();
      await _settle(tester);
      expect(rig.refresh.calls, 0);
      await rig.unmount();
    });

    testWidgets('becoming disabled mid-refresh lets that refresh finish normally', (tester) async {
      final enabled = ValueNotifier<bool>(true);
      addTearDown(enabled.dispose);
      final rig = await _Rig.mount(tester, enabled: enabled);
      var done = false;
      unawaited(rig.state.refresh().then((_) => done = true));
      await _settle(tester);
      expect(rig.value.phase, FrostPullRefreshPhase.refreshing);
      enabled.value = false;
      await tester.pump();
      await _settle(tester);
      expect(rig.value.phase, FrostPullRefreshPhase.refreshing);
      expect(rig.value.extent, FrostPullRefresh.holdExtent);
      expect(done, isFalse);

      rig.refresh.last.complete(true);
      await tester.pump();
      await tester.pump();
      await _settle(tester);
      expect(done, isTrue);
      expect(rig.value.phase, FrostPullRefreshPhase.idle);
      expect(rig.value.extent, 0);
      expect(rig.refresh.calls, 1);
      await rig.unmount();
    });
  });

  testWidgets('toggling onRefresh on a live refresh view keeps the child state and scroll offset', (tester) async {
    final onRefresh = ValueNotifier<FrostRefreshAction?>(null);
    addTearDown(onRefresh.dispose);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      frostTestApp(
        Scaffold(
          body: ValueListenableBuilder<FrostRefreshAction?>(
            valueListenable: onRefresh,
            builder: (context, action, _) => FrostRefreshView(
              onRefresh: action,
              scrollController: controller,
              builder: (context, physics, locators) => _Counter(
                child: CustomScrollView(
                  controller: controller,
                  physics: physics,
                  slivers: [?locators.sliverHeader, const SliverToBoxAdapter(child: SizedBox(height: 3000))],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final counter = tester.state<_CounterState>(find.byType(_Counter));
    counter.count = 7;
    controller.jumpTo(300);
    await tester.pump();

    for (final action in <FrostRefreshAction?>[() async => true, null, () async => true]) {
      onRefresh.value = action;
      await tester.pump();
      expect(tester.state<_CounterState>(find.byType(_Counter)), same(counter));
      expect(counter.count, 7);
      expect(controller.offset, 300);
      expect(find.byType(FrostPullRefresh), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox());
  });
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 800));
}

class _Counter extends StatefulWidget {
  const _Counter({required this.child});
  final Widget child;
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;
  @override
  Widget build(BuildContext context) => widget.child;
}

/// A refresh whose results the test completes by hand.
class _Refresh {
  final completers = <Completer<bool>>[];
  int get calls => completers.length;
  Completer<bool> get last => completers.last;
  Future<bool> call() {
    final completer = Completer<bool>();
    completers.add(completer);
    return completer.future;
  }
}

/// A mounted [FrostPullRefresh] fed the scroll notifications of a pull, so a
/// test controls each step exactly.
class _Rig {
  _Rig._(this.tester, this.refresh, this._context);

  final WidgetTester tester;
  final _Refresh refresh;
  final BuildContext Function() _context;

  static Future<_Rig> mount(WidgetTester tester, {ValueNotifier<bool>? enabled}) async {
    final refresh = _Refresh();
    late BuildContext context;
    Widget build(bool on) => FrostPullRefresh(
      enabled: on,
      onRefresh: refresh.call,
      child: Builder(
        builder: (inner) {
          context = inner;
          return const CustomScrollView(
            physics: frostRefreshPhysics,
            slivers: [SliverToBoxAdapter(child: SizedBox(height: 2000))],
          );
        },
      ),
    );
    await tester.pumpWidget(
      frostTestApp(
        Scaffold(
          body: enabled == null
              ? build(true)
              : ValueListenableBuilder<bool>(valueListenable: enabled, builder: (_, on, _) => build(on)),
        ),
      ),
    );
    return _Rig._(tester, refresh, () => context);
  }

  FrostPullRefreshState get state => tester.state<FrostPullRefreshState>(find.byType(FrostPullRefresh));
  FrostPullRefreshValue get value => state.value.value;

  ScrollMetrics _metrics(double pixels) => FixedScrollMetrics(
    minScrollExtent: 0,
    maxScrollExtent: 1400,
    pixels: pixels,
    viewportDimension: 600,
    axisDirection: AxisDirection.down,
    devicePixelRatio: 1,
  );

  void start() {
    final target = _context();
    ScrollStartNotification(metrics: _metrics(0), context: target).dispatch(target);
  }

  void overscroll(double overscroll) {
    final target = _context();
    OverscrollNotification(metrics: _metrics(0), context: target, overscroll: overscroll).dispatch(target);
  }

  void update({required double pixels, required double delta}) {
    final target = _context();
    ScrollUpdateNotification(
      metrics: _metrics(pixels),
      context: target,
      scrollDelta: delta,
      dragDetails: DragUpdateDetails(globalPosition: Offset.zero),
    ).dispatch(target);
  }

  void end() {
    final target = _context();
    ScrollEndNotification(metrics: _metrics(0), context: target).dispatch(target);
  }

  /// Refreshes programmatically and fails, leaving the failed hold up.
  Future<void> fail() async {
    unawaited(state.refresh());
    await _settle(tester);
    refresh.last.complete(false);
    await tester.pump();
  }

  Future<void> unmount() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(FrostPullRefresh.failedHold + const Duration(seconds: 1));
  }
}
