import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/feedback/_pull_refresh.dart';

import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('constants and value', () {
    test('the thresholds and the failed hold are fixed', () {
      expect(FrostPullRefresh.holdExtent, 56);
      expect(FrostPullRefresh.maxExtent, 120);
      expect(FrostPullRefresh.failedHold, const Duration(seconds: 3));
    });

    test('values compare by phase and extent', () {
      const a = FrostPullRefreshValue(phase: FrostPullRefreshPhase.drag, extent: 10);
      expect(a, const FrostPullRefreshValue(phase: FrostPullRefreshPhase.drag, extent: 10));
      expect(a.hashCode, const FrostPullRefreshValue(phase: FrostPullRefreshPhase.drag, extent: 10).hashCode);
      expect(a, isNot(const FrostPullRefreshValue(phase: FrostPullRefreshPhase.armed, extent: 10)));
      expect(a, isNot(const FrostPullRefreshValue(phase: FrostPullRefreshPhase.drag, extent: 11)));
    });
  });

  group('pulling', () {
    testWidgets('the extent is half the overscroll distance and the phase follows the hold threshold', (tester) async {
      final refresh = _Refresh();
      await tester.pumpWidget(_app(FrostPullRefresh(onRefresh: refresh.call, child: _scroll())));
      final recorder = _Recorder(_state(tester));

      final gesture = await _beginPull(tester);
      final base = _value(tester).extent;
      await _pullBy(tester, gesture, 40);
      expect(_value(tester).extent, closeTo(base + 20, .001));
      expect(_value(tester).phase, FrostPullRefreshPhase.drag);
      await _pullBy(tester, gesture, 30);
      expect(_value(tester).extent, closeTo(base + 35, .001));
      expect(_value(tester).phase, FrostPullRefreshPhase.drag);

      await _pullTo(tester, gesture, 55);
      expect(_value(tester).extent, closeTo(55, .001));
      expect(_value(tester).phase, FrostPullRefreshPhase.drag);
      await _pullTo(tester, gesture, 56);
      expect(_value(tester).extent, closeTo(56, .001));
      expect(_value(tester).phase, FrostPullRefreshPhase.armed);
      await _pullTo(tester, gesture, 90);
      expect(_value(tester).extent, closeTo(90, .001));
      expect(_value(tester).phase, FrostPullRefreshPhase.armed);

      expect(refresh.calls, 0);
      await gesture.up();
      await _settle(tester);
      expect(recorder.extents, everyElement(allOf(greaterThanOrEqualTo(0), lessThanOrEqualTo(FrostPullRefresh.maxExtent))));
      await _unmount(tester);
    });

    testWidgets('moving the finger up during the drag phase cancels the pull', (tester) async {
      final refresh = _Refresh();
      await tester.pumpWidget(_app(FrostPullRefresh(onRefresh: refresh.call, child: _scroll())));
      final gesture = await _beginPull(tester);
      await _pullTo(tester, gesture, 30);
      expect(_value(tester).phase, FrostPullRefreshPhase.drag);
      await _pullBy(tester, gesture, -60);
      await _settle(tester);
      expect(_value(tester).phase, FrostPullRefreshPhase.idle);
      expect(_value(tester).extent, 0);
      expect(refresh.calls, 0);
      await gesture.up();
      await _settle(tester);
      expect(refresh.calls, 0);
      await _unmount(tester);
    });

    testWidgets('moving the finger up during the armed phase starts the refresh', (tester) async {
      final refresh = _Refresh();
      await tester.pumpWidget(_app(FrostPullRefresh(onRefresh: refresh.call, child: _scroll())));
      final gesture = await _beginPull(tester);
      await _pullTo(tester, gesture, 70);
      expect(_value(tester).phase, FrostPullRefreshPhase.armed);
      await _pullBy(tester, gesture, -60);
      await _settle(tester);
      expect(refresh.calls, 1);
      expect(_value(tester).phase, FrostPullRefreshPhase.refreshing);
      await gesture.up();
      await _settle(tester);
      expect(refresh.calls, 1);
      await _unmount(tester);
    });

    testWidgets('the extent never exceeds the maximum', (tester) async {
      final refresh = _Refresh();
      await tester.pumpWidget(_app(FrostPullRefresh(onRefresh: refresh.call, child: _scroll())));
      final recorder = _Recorder(_state(tester));
      final gesture = await _beginPull(tester);
      await _pullBy(tester, gesture, 600);
      expect(_value(tester).extent, FrostPullRefresh.maxExtent);
      expect(_value(tester).phase, FrostPullRefreshPhase.armed);
      await _pullBy(tester, gesture, 400);
      expect(_value(tester).extent, FrostPullRefresh.maxExtent);
      expect(recorder.extents.reduce((a, b) => a > b ? a : b), FrostPullRefresh.maxExtent);
      await gesture.up();
      await _settle(tester);
      await _unmount(tester);
    });

    testWidgets('releasing in the drag phase retracts to idle without refreshing', (tester) async {
      final refresh = _Refresh();
      await tester.pumpWidget(_app(FrostPullRefresh(onRefresh: refresh.call, child: _scroll())));
      final gesture = await _beginPull(tester);
      await _pullTo(tester, gesture, 30);
      expect(_value(tester).phase, FrostPullRefreshPhase.drag);
      await gesture.up();
      await _settle(tester);
      expect(_value(tester).phase, FrostPullRefreshPhase.idle);
      expect(_value(tester).extent, 0);
      expect(refresh.calls, 0);
      await tester.pump(const Duration(seconds: 10));
      expect(_value(tester).phase, FrostPullRefreshPhase.idle);
      expect(refresh.calls, 0);
      await _unmount(tester);
    });

    testWidgets('releasing in the armed phase holds the extent until the refresh completes', (tester) async {
      final refresh = _Refresh();
      await tester.pumpWidget(_app(FrostPullRefresh(onRefresh: refresh.call, child: _scroll())));
      final gesture = await _beginPull(tester);
      await _pullTo(tester, gesture, 90);
      expect(_value(tester).phase, FrostPullRefreshPhase.armed);
      expect(refresh.calls, 0);
      await gesture.up();
      await _settle(tester);
      expect(refresh.calls, 1);
      expect(_value(tester).phase, FrostPullRefreshPhase.refreshing);
      expect(_value(tester).extent, FrostPullRefresh.holdExtent);
      await tester.pump(const Duration(seconds: 10));
      expect(_value(tester).phase, FrostPullRefreshPhase.refreshing);
      expect(_value(tester).extent, FrostPullRefresh.holdExtent);
      expect(refresh.calls, 1);
      refresh.last.complete(true);
      await tester.pump();
      await _settle(tester);
      expect(_value(tester).phase, FrostPullRefreshPhase.idle);
      await _unmount(tester);
    });

    testWidgets('pushing the content back up past the top while armed starts the refresh', (tester) async {
      final refresh = _Refresh();
      await tester.pumpWidget(_app(FrostPullRefresh(onRefresh: refresh.call, child: _scroll())));
      final gesture = await _beginPull(tester);
      await _pullTo(tester, gesture, 70);
      expect(_value(tester).phase, FrostPullRefreshPhase.armed);
      expect(refresh.calls, 0);
      // Back through the pulled distance and then 40 more, still without releasing.
      await _pullBy(tester, gesture, -(2 * _value(tester).extent + 40));
      await _settle(tester);
      expect(refresh.calls, 1);
      expect(_value(tester).phase, FrostPullRefreshPhase.refreshing);
      expect(_value(tester).extent, FrostPullRefresh.holdExtent);
      await gesture.up();
      await _settle(tester);
      expect(refresh.calls, 1);
      expect(_value(tester).phase, FrostPullRefreshPhase.refreshing);
      expect(_value(tester).extent, FrostPullRefresh.holdExtent);
      await _unmount(tester);
    });
  });

  group('outcome', () {
    testWidgets('a successful refresh shows done and then retracts to idle', (tester) async {
      final refresh = _Refresh();
      await tester.pumpWidget(_app(FrostPullRefresh(onRefresh: refresh.call, child: _scroll())));
      await _pullAndRelease(tester, 90);
      await _settle(tester);
      expect(_value(tester).phase, FrostPullRefreshPhase.refreshing);
      final recorder = _Recorder(_state(tester));
      refresh.last.complete(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await _settle(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(recorder.phases, [FrostPullRefreshPhase.refreshing, FrostPullRefreshPhase.done, FrostPullRefreshPhase.idle]);
      expect(_value(tester).extent, 0);
      expect(refresh.calls, 1);
      await _unmount(tester);
    });

    testWidgets('a failed refresh holds the failed phase for the hold duration and then retracts', (tester) async {
      final refresh = _Refresh();
      await tester.pumpWidget(_app(FrostPullRefresh(onRefresh: refresh.call, child: _scroll())));
      await _pullAndRelease(tester, 90);
      await _settle(tester);
      refresh.last.complete(false);
      await tester.pump();
      expect(_value(tester).phase, FrostPullRefreshPhase.failed);
      expect(_value(tester).extent, FrostPullRefresh.holdExtent);

      await tester.pump(FrostPullRefresh.failedHold - const Duration(milliseconds: 100));
      expect(_value(tester).phase, FrostPullRefreshPhase.failed);
      expect(_value(tester).extent, FrostPullRefresh.holdExtent);

      await tester.pump(const Duration(milliseconds: 200));
      await _settle(tester);
      expect(_value(tester).phase, FrostPullRefreshPhase.idle);
      expect(_value(tester).extent, 0);
      expect(refresh.calls, 1);
      await _unmount(tester);
    });

    for (final sync in [false, true]) {
      testWidgets('a refresh that throws ${sync ? 'synchronously' : 'asynchronously'} fails and reports the error', (tester) async {
        var calls = 0;
        Future<bool> onRefresh() {
          calls++;
          if (sync) throw StateError('boom');
          return Future<bool>.error(StateError('boom'));
        }

        await tester.pumpWidget(_app(FrostPullRefresh(onRefresh: onRefresh, child: _scroll())));
        await _pullAndRelease(tester, 90);
        await _settle(tester);
        expect(calls, 1);
        expect(_value(tester).phase, FrostPullRefreshPhase.failed);
        expect(_value(tester).extent, FrostPullRefresh.holdExtent);
        expect(tester.takeException(), isA<StateError>());
        await tester.pump(FrostPullRefresh.failedHold + const Duration(milliseconds: 100));
        await _settle(tester);
        expect(_value(tester).phase, FrostPullRefreshPhase.idle);
        expect(tester.takeException(), isNull);
        await _unmount(tester);
      });
    }
  });

  group('failed hold', () {
    testWidgets('tapping the header during the failed hold refreshes again', (tester) async {
      final refresh = _Refresh();
      await tester.pumpWidget(
        _app(
          FrostRefreshView(
            onRefresh: refresh.call,
            builder: (context, physics, locators) => CustomScrollView(
              physics: physics,
              slivers: [?locators.sliverHeader, const SliverToBoxAdapter(child: SizedBox(height: 2000))],
            ),
          ),
        ),
      );
      final state = _state(tester);
      unawaited(state.refresh());
      await _settle(tester);
      expect(refresh.calls, 1);
      expect(find.text('L.refreshing'), findsOneWidget);
      refresh.last.complete(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(_value(tester).phase, FrostPullRefreshPhase.failed);
      expect(find.text('L.refreshFailed'), findsOneWidget);

      await tester.tap(find.text('L.refreshFailed'));
      await _settle(tester);
      expect(refresh.calls, 2);
      expect(_value(tester).phase, FrostPullRefreshPhase.refreshing);
      expect(_value(tester).extent, FrostPullRefresh.holdExtent);
      expect(find.text('L.refreshing'), findsOneWidget);

      // The earlier hold must not retract the new refresh.
      await tester.pump(FrostPullRefresh.failedHold + const Duration(seconds: 1));
      expect(_value(tester).phase, FrostPullRefreshPhase.refreshing);
      expect(_value(tester).extent, FrostPullRefresh.holdExtent);
      expect(refresh.calls, 2);
      refresh.last.complete(true);
      await tester.pump();
      await _settle(tester);
      await _unmount(tester);
    });

    testWidgets('a new pull during the failed hold takes over without retracting first', (tester) async {
      final refresh = _Refresh();
      await tester.pumpWidget(_app(FrostPullRefresh(onRefresh: refresh.call, child: _scroll())));
      final state = _state(tester);
      unawaited(state.refresh());
      await _settle(tester);
      refresh.last.complete(false);
      await tester.pump();
      expect(_value(tester).phase, FrostPullRefreshPhase.failed);
      final recorder = _Recorder(state);

      final gesture = await _beginPull(tester);
      await _pullBy(tester, gesture, 80);
      expect(_value(tester).phase, anyOf(FrostPullRefreshPhase.drag, FrostPullRefreshPhase.armed));
      expect(_value(tester).extent, greaterThan(0));
      expect(recorder.extents, everyElement(greaterThan(0)));

      // The old hold timer must not pull the extent away from the finger.
      await tester.pump(FrostPullRefresh.failedHold + const Duration(seconds: 1));
      expect(_value(tester).phase, anyOf(FrostPullRefreshPhase.drag, FrostPullRefreshPhase.armed));
      expect(_value(tester).extent, greaterThan(0));
      expect(recorder.extents, everyElement(greaterThan(0)));

      await gesture.up();
      await _settle(tester);
      await _unmount(tester);
    });
  });

  group('programmatic refresh', () {
    testWidgets('refresh() holds the extent and calls onRefresh once, even when called again while refreshing', (tester) async {
      final refresh = _Refresh();
      await tester.pumpWidget(_app(FrostPullRefresh(onRefresh: refresh.call, child: _scroll())));
      final state = _state(tester);

      var firstDone = false;
      var secondDone = false;
      unawaited(state.refresh().then((_) => firstDone = true));
      await _settle(tester);
      expect(_value(tester).phase, FrostPullRefreshPhase.refreshing);
      expect(_value(tester).extent, FrostPullRefresh.holdExtent);
      expect(refresh.calls, 1);

      unawaited(state.refresh().then((_) => secondDone = true));
      await _settle(tester);
      expect(refresh.calls, 1);
      expect(firstDone, isFalse);
      expect(secondDone, isFalse);
      expect(_value(tester).phase, FrostPullRefreshPhase.refreshing);

      refresh.last.complete(true);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));
      expect(firstDone, isTrue);
      expect(secondDone, isTrue);
      expect(refresh.calls, 1);
      expect(_value(tester).phase, FrostPullRefreshPhase.idle);
      expect(_value(tester).extent, 0);
      await _unmount(tester);
    });

    testWidgets('maybeOf finds the nearest pull refresh from a descendant', (tester) async {
      FrostPullRefreshState? inside;
      FrostPullRefreshState? outside;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (outer) {
              outside = FrostPullRefresh.maybeOf(outer);
              return FrostPullRefresh(
                onRefresh: _Refresh().call,
                child: Builder(
                  builder: (context) {
                    inside = FrostPullRefresh.maybeOf(context);
                    return _scroll();
                  },
                ),
              );
            },
          ),
        ),
      );
      expect(outside, isNull);
      expect(inside, isNotNull);
      expect(inside, same(_state(tester)));
    });

    testWidgets('disposing while refreshing completes the refresh future and ignores the late result', (tester) async {
      final refresh = _Refresh();
      await tester.pumpWidget(_app(FrostPullRefresh(onRefresh: refresh.call, child: _scroll())));
      final state = _state(tester);
      var done = false;
      unawaited(state.refresh().then((_) => done = true));
      await _settle(tester);
      expect(_value(tester).phase, FrostPullRefreshPhase.refreshing);
      expect(done, isFalse);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(done, isTrue);
      expect(tester.takeException(), isNull);

      refresh.last.complete(true);
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposing while refreshing leaves no timer after a late failure', (tester) async {
      final refresh = _Refresh();
      await tester.pumpWidget(_app(FrostPullRefresh(onRefresh: refresh.call, child: _scroll())));
      unawaited(_state(tester).refresh());
      await _settle(tester);
      await tester.pumpWidget(const SizedBox());
      refresh.last.complete(false);
      await tester.pump();
      await tester.pump(FrostPullRefresh.failedHold + const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  });

  group('reduced motion', () {
    testWidgets('the extent jumps to the hold extent and back to zero within one pump', (tester) async {
      final refresh = _Refresh();
      await tester.pumpWidget(_app(FrostPullRefresh(onRefresh: refresh.call, child: _scroll()), reduced: true));
      final gesture = await _beginPull(tester);
      await _pullTo(tester, gesture, 90);
      expect(_value(tester).phase, FrostPullRefreshPhase.armed);
      await gesture.up();
      await tester.pump();
      expect(refresh.calls, 1);
      expect(_value(tester).phase, FrostPullRefreshPhase.refreshing);
      expect(_value(tester).extent, FrostPullRefresh.holdExtent);

      refresh.last.complete(true);
      await tester.pump();
      expect(_value(tester).extent, 0);
      await _settle(tester);
      expect(_value(tester).phase, FrostPullRefreshPhase.idle);
      await _unmount(tester);
    });

    testWidgets('programmatic refresh jumps to the hold extent within one pump', (tester) async {
      final refresh = _Refresh();
      await tester.pumpWidget(_app(FrostPullRefresh(onRefresh: refresh.call, child: _scroll()), reduced: true));
      unawaited(_state(tester).refresh());
      await tester.pump();
      expect(_value(tester).phase, FrostPullRefreshPhase.refreshing);
      expect(_value(tester).extent, FrostPullRefresh.holdExtent);
      refresh.last.complete(true);
      await tester.pump();
      expect(_value(tester).extent, 0);
      await _settle(tester);
      await _unmount(tester);
    });
  });

  group('late listeners', () {
    testWidgets('a listener mounted during a refresh reads the current value at once', (tester) async {
      final refresh = _Refresh();
      final showProbe = ValueNotifier<bool>(false);
      addTearDown(showProbe.dispose);
      await tester.pumpWidget(
        _app(
          FrostPullRefresh(
            onRefresh: refresh.call,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _scroll(),
                ValueListenableBuilder<bool>(
                  valueListenable: showProbe,
                  builder: (context, show, _) => !show
                      ? const SizedBox.shrink()
                      : Positioned(
                          top: 0,
                          left: 0,
                          child: Builder(
                            builder: (context) => ValueListenableBuilder<FrostPullRefreshValue>(
                              valueListenable: FrostPullRefresh.maybeOf(context)!.value,
                              builder: (context, value, _) => Text('probe ${value.phase.name} ${value.extent}'),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      );
      unawaited(_state(tester).refresh());
      await _settle(tester);
      expect(_value(tester).phase, FrostPullRefreshPhase.refreshing);
      expect(find.textContaining('probe'), findsNothing);

      showProbe.value = true;
      await tester.pump();
      expect(find.text('probe refreshing 56.0'), findsOneWidget);
      refresh.last.complete(true);
      await tester.pump();
      await _settle(tester);
      expect(find.text('probe idle 0.0'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('the sliver header inserted during a refresh shows the refreshing label at once', (tester) async {
      final refresh = _Refresh();
      final showHeader = ValueNotifier<bool>(false);
      addTearDown(showHeader.dispose);
      await tester.pumpWidget(
        _app(
          FrostRefreshView(
            onRefresh: refresh.call,
            builder: (context, physics, locators) => ValueListenableBuilder<bool>(
              valueListenable: showHeader,
              builder: (context, show, _) => CustomScrollView(
                physics: physics,
                slivers: [if (show) ?locators.sliverHeader, const SliverToBoxAdapter(child: SizedBox(height: 2000))],
              ),
            ),
          ),
        ),
      );
      unawaited(_state(tester).refresh());
      await _settle(tester);
      expect(_value(tester).phase, FrostPullRefreshPhase.refreshing);
      expect(find.text('L.refreshing'), findsNothing);

      showHeader.value = true;
      await tester.pump();
      expect(find.text('L.refreshing'), findsOneWidget);
      refresh.last.complete(true);
      await tester.pump();
      await _settle(tester);
      await _unmount(tester);
    });
  });

  group('which notifications count', () {
    for (final nested in [false, true]) {
      testWidgets('an inner vertical list ${nested ? 'starts' : 'does not start'} a pull when nested is $nested', (tester) async {
        final refresh = _Refresh();
        await tester.pumpWidget(
          _app(
            FrostPullRefresh(
              nested: nested,
              onRefresh: refresh.call,
              child: CustomScrollView(
                physics: frostRefreshPhysics,
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 300,
                      child: ListView.builder(physics: frostRefreshPhysics, itemExtent: 40, itemCount: 30, itemBuilder: (context, index) => Text('Row $index')),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 2000)),
                ],
              ),
            ),
          ),
        );
        final gesture = await tester.startGesture(tester.getCenter(find.byType(ListView)));
        await gesture.moveBy(const Offset(0, 25));
        await tester.pump();
        await gesture.moveBy(const Offset(0, 60));
        await tester.pump();
        if (nested) {
          expect(_value(tester).phase, FrostPullRefreshPhase.drag);
          expect(_value(tester).extent, greaterThan(0));
        } else {
          expect(_value(tester).phase, FrostPullRefreshPhase.idle);
          expect(_value(tester).extent, 0);
        }
        await gesture.moveBy(const Offset(0, 300));
        await tester.pump();
        if (nested) {
          expect(_value(tester).phase, FrostPullRefreshPhase.armed);
        } else {
          expect(_value(tester).phase, FrostPullRefreshPhase.idle);
        }
        await gesture.up();
        await _settle(tester);
        expect(refresh.calls, nested ? 1 : 0);
        await _unmount(tester);
      });
    }

    for (final inner in [false, true]) {
      for (final armed in [false, true]) {
        testWidgets('horizontal scroll notifications${inner ? ' from a descendant' : ''} leave a ${armed ? 'armed' : 'dragging'} pull alone', (tester) async {
          final refresh = _Refresh();
          late BuildContext outerContext;
          late BuildContext innerContext;
          await tester.pumpWidget(
            _app(
              FrostPullRefresh(
                nested: true,
                onRefresh: refresh.call,
                child: Builder(
                  builder: (context) {
                    outerContext = context;
                    return CustomScrollView(
                      physics: frostRefreshPhysics,
                      slivers: [
                        SliverToBoxAdapter(
                          child: Builder(
                            builder: (context) {
                              innerContext = context;
                              return const SizedBox(height: 100);
                            },
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 2000)),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
          final gesture = await _beginPull(tester);
          await _pullTo(tester, gesture, armed ? 80 : 30);
          final before = _value(tester);
          expect(before.phase, armed ? FrostPullRefreshPhase.armed : FrostPullRefreshPhase.drag);

          final target = inner ? innerContext : outerContext;
          final metrics = FixedScrollMetrics(
            minScrollExtent: 0,
            maxScrollExtent: 400,
            pixels: 0,
            viewportDimension: 300,
            axisDirection: AxisDirection.right,
            devicePixelRatio: 1,
          );
          ScrollStartNotification(metrics: metrics, context: target).dispatch(target);
          await tester.pump();
          OverscrollNotification(metrics: metrics, context: target, overscroll: -50).dispatch(target);
          await tester.pump();
          ScrollUpdateNotification(metrics: metrics, context: target, scrollDelta: 5).dispatch(target);
          await tester.pump();
          ScrollEndNotification(metrics: metrics, context: target).dispatch(target);
          await tester.pump();

          expect(_value(tester), before);
          expect(refresh.calls, 0);
          await gesture.up();
          await _settle(tester);
          expect(refresh.calls, armed ? 1 : 0);
          await _unmount(tester);
        });
      }
    }
  });

  group('disabled', () {
    testWidgets('a disabled pull refresh never leaves idle and never refreshes', (tester) async {
      final refresh = _Refresh();
      await tester.pumpWidget(_app(FrostPullRefresh(enabled: false, onRefresh: refresh.call, child: _scroll())));
      final gesture = await _beginPull(tester);
      for (final extent in [30.0, 90.0, 400.0]) {
        await _pullBy(tester, gesture, extent);
        expect(_value(tester).phase, FrostPullRefreshPhase.idle);
        expect(_value(tester).extent, 0);
      }
      await gesture.up();
      await _settle(tester);
      expect(_value(tester).phase, FrostPullRefreshPhase.idle);
      expect(_value(tester).extent, 0);
      expect(refresh.calls, 0);
      await _unmount(tester);
    });

    testWidgets('a refresh view without onRefresh shows no pull header', (tester) async {
      await tester.pumpWidget(
        _app(
          FrostRefreshView(
            builder: (context, physics, locators) => CustomScrollView(
              physics: physics,
              slivers: [?locators.sliverHeader, const SliverToBoxAdapter(child: SizedBox(height: 2000))],
            ),
          ),
        ),
      );
      final gesture = await _beginPull(tester);
      for (final distance in [60.0, 300.0]) {
        await _pullBy(tester, gesture, distance);
        expect(find.text('L.pullToRefresh'), findsNothing);
        expect(find.text('L.releaseToRefresh'), findsNothing);
        expect(find.text('L.refreshing'), findsNothing);
        expect(find.byType(FrostPullRefresh), findsOneWidget);
        expect(_value(tester).phase, FrostPullRefreshPhase.idle);
      }
      await gesture.up();
      await _settle(tester);
      expect(find.text('L.refreshing'), findsNothing);
      await _unmount(tester);
    });
  });

  group('refresh view header', () {
    testWidgets('the header labels follow pulling, refreshing, success and failure', (tester) async {
      final refresh = _Refresh();
      await tester.pumpWidget(
        _app(
          FrostRefreshView(
            onRefresh: refresh.call,
            builder: (context, physics, locators) => CustomScrollView(
              physics: physics,
              slivers: [?locators.sliverHeader, const SliverToBoxAdapter(child: SizedBox(height: 2000))],
            ),
          ),
        ),
      );
      final gesture = await _beginPull(tester);
      await _pullTo(tester, gesture, 30);
      expect(find.text('L.pullToRefresh'), findsOneWidget);
      await _pullTo(tester, gesture, 90);
      expect(find.text('L.releaseToRefresh'), findsOneWidget);
      await gesture.up();
      await _settle(tester);
      expect(refresh.calls, 1);
      expect(find.text('L.refreshing'), findsOneWidget);
      refresh.last.complete(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('L.refreshFailed'), findsOneWidget);
      await tester.pump(FrostPullRefresh.failedHold + const Duration(seconds: 1));
      await _settle(tester);
      expect(find.text('L.refreshFailed'), findsNothing);
      await _unmount(tester);
    });

    testWidgets('a nested refresh view arms from a pull on the body of a nested scroll view', (tester) async {
      final refresh = _Refresh();
      await tester.pumpWidget(
        _app(
          FrostNestedRefreshView(
            onRefresh: refresh.call,
            builder: (context, nestedRefresh) => NestedScrollView(
              physics: nestedRefresh.physics,
              headerSliverBuilder: (context, innerBoxIsScrolled) => const [SliverToBoxAdapter(child: SizedBox(height: 100))],
              body: nestedRefresh.body(
                builder: (context, locators) => CustomScrollView(
                  physics: nestedRefresh.physics,
                  slivers: [?locators.sliverHeader, const SliverToBoxAdapter(child: SizedBox(height: 2000))],
                ),
              ),
            ),
          ),
        ),
      );
      final gesture = await _beginPull(tester);
      await _pullBy(tester, gesture, 300);
      expect(find.text('L.releaseToRefresh'), findsOneWidget);
      await gesture.up();
      await _settle(tester);
      expect(refresh.calls, 1);
      expect(find.text('L.refreshing'), findsOneWidget);
      refresh.last.complete(true);
      await tester.pump();
      await _settle(tester);
      await _unmount(tester);
    });
  });
}

Widget _app(Widget child, {bool reduced = false}) => frostTestApp(
  Builder(
    builder: (context) {
      final body = Scaffold(body: child);
      return reduced ? MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: body) : body;
    },
  ),
);

Widget _scroll() => CustomScrollView(
  physics: frostRefreshPhysics,
  slivers: const [SliverToBoxAdapter(child: SizedBox(height: 2000))],
);

FrostPullRefreshState _state(WidgetTester tester) => tester.state<FrostPullRefreshState>(find.byType(FrostPullRefresh));

FrostPullRefreshValue _value(WidgetTester tester) => _state(tester).value.value;

/// Puts a finger down in the middle of the scroll view and moves it past the
/// touch slop. What the slop absorbs is the pull's own business, so later
/// assertions measure from the extent this leaves behind.
Future<TestGesture> _beginPull(WidgetTester tester) async {
  final gesture = await tester.startGesture(tester.getCenter(find.byType(CustomScrollView).first));
  await gesture.moveBy(const Offset(0, 25));
  await tester.pump();
  return gesture;
}

/// Moves the finger down by [distance] (up when negative).
Future<void> _pullBy(WidgetTester tester, TestGesture gesture, double distance) async {
  await gesture.moveBy(Offset(0, distance));
  await tester.pump();
}

/// Moves the finger so the extent, which is half the finger distance, becomes [extent].
Future<void> _pullTo(WidgetTester tester, TestGesture gesture, double extent) => _pullBy(tester, gesture, 2 * (extent - _value(tester).extent));

Future<void> _pullAndRelease(WidgetTester tester, double extent) async {
  final gesture = await _beginPull(tester);
  await _pullTo(tester, gesture, extent);
  await gesture.up();
  await tester.pump();
}

/// Lets a motion finish without crossing the failed hold.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 800));
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(FrostPullRefresh.failedHold + const Duration(seconds: 1));
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

/// The phases (without repeats) and the extents a state published.
class _Recorder {
  _Recorder(FrostPullRefreshState state) {
    void record() {
      final value = state.value.value;
      if (phases.isEmpty || phases.last != value.phase) phases.add(value.phase);
      extents.add(value.extent);
    }

    record();
    state.value.addListener(record);
  }
  final phases = <FrostPullRefreshPhase>[];
  final extents = <double>[];
}
