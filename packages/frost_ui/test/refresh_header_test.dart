import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/feedback/_pull_refresh.dart';
import 'package:frost_ui/src/feedback/refresh_indicator.dart' show FrostRefreshSliverHeader;

import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final platform in TargetPlatform.values) {
    testWidgets('refresh header maps phases using the host icons on $platform', (tester) async {
      final pull = await _pumpHeader(tester, platform: platform);

      await pull.to(30);
      expect(find.text('L.pullToRefresh'), findsOneWidget);
      expect(_icon(testIcons.arrowDown), findsOneWidget);
      expect(find.byType(FrostRefreshDots), findsNothing);
      expect(_turns(tester), 0);
      final arrow = tester.element(find.byType(AnimatedRotation));

      await pull.to(90);
      expect(find.text('L.releaseToRefresh'), findsOneWidget);
      expect(tester.element(find.byType(AnimatedRotation)), same(arrow));
      await tester.pump(const Duration(milliseconds: 70));
      expect(_turns(tester), allOf(greaterThan(0), lessThan(.5)));
      await tester.pump(const Duration(milliseconds: 70));
      expect(_turns(tester), .5);

      await pull.to(30);
      expect(find.text('L.pullToRefresh'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 70));
      expect(_turns(tester), allOf(greaterThan(0), lessThan(.5)));
      await tester.pump(const Duration(milliseconds: 70));
      expect(_turns(tester), 0);

      await pull.to(90);
      await pull.release();
      expect(find.text('L.refreshing'), findsOneWidget);
      expect(find.byType(FrostRefreshDots), findsOneWidget);
      expect(_icon(testIcons.arrowDown), findsNothing);

      pull.refresh.last.complete(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('L.refreshComplete'), findsOneWidget);
      expect(_icon(testIcons.check), findsOneWidget);
      expect(_icon(testIcons.success), findsNothing);
      expect(find.byType(FrostRefreshDots), findsNothing);
      await tester.pump(const Duration(seconds: 1));

      await pull.to(90);
      await pull.release();
      pull.refresh.last.complete(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('L.refreshFailed'), findsOneWidget);
      expect(_icon(testIcons.error), findsOneWidget);
      final icon = tester.widget<FrostIcon>(_icon(testIcons.error));
      expect(icon.color, FrostThemeTokens.of(tester.element(_icon(testIcons.error))).negativeInk);
      await _unmount(tester);
    });
  }

  testWidgets('arrow reversal continues from its current angle', (tester) async {
    final pull = await _pumpHeader(tester);
    await pull.to(30);
    await pull.to(90);
    await tester.pump(const Duration(milliseconds: 50));
    final before = _turns(tester);
    await pull.to(30);
    expect(_turns(tester), closeTo(before, .000001));
    await tester.pump(const Duration(milliseconds: 70));
    expect(_turns(tester), allOf(greaterThan(0), lessThan(before)));
    await tester.pump(const Duration(milliseconds: 70));
    expect(_turns(tester), 0);
    await _unmount(tester);
  });

  testWidgets('reduced motion sets the arrow angle without rotation', (tester) async {
    final pull = await _pumpHeader(tester, reduced: true);
    for (final extent in [30.0, 90.0, 30.0]) {
      await pull.to(extent);
      expect(_turns(tester), extent == 90 ? .5 : 0);
    }
    await _unmount(tester);
  });

  for (final nested in [false, true]) {
    testWidgets('refresh dots remain at the held extent until the Future completes, nested=$nested', (tester) async {
      final result = Completer<bool>();
      var calls = 0;
      Future<bool> refresh() {
        calls++;
        return result.future;
      }

      Widget scroll(ScrollPhysics? physics, FrostRefreshLocators locators) => CustomScrollView(
        physics: physics,
        slivers: [
          ?locators.sliverHeader,
          const SliverToBoxAdapter(child: SizedBox(height: 2000, child: Text('Existing content'))),
        ],
      );
      await tester.pumpWidget(
        frostTestApp(
          Scaffold(
            body: nested
                ? FrostNestedRefreshView(onRefresh: refresh, builder: (_, context) => scroll(context.physics, context.locators))
                : FrostRefreshView(onRefresh: refresh, builder: (_, physics, locators) => scroll(physics, locators)),
          ),
        ),
      );
      final state = tester.state<FrostPullRefreshState>(find.byType(FrostPullRefresh));
      final pending = state.refresh();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(FrostRefreshDots), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(calls, 1);
      expect(state.value.value.phase, FrostPullRefreshPhase.refreshing);
      expect(state.value.value.extent, FrostRefreshSliverHeader.refreshOffset);
      await tester.pump(const Duration(seconds: 3));
      expect(state.value.value.extent, FrostRefreshSliverHeader.refreshOffset);
      expect(find.byType(FrostRefreshDots), findsOneWidget);
      expect(find.text('L.refreshing'), findsOneWidget);
      expect(find.text('Existing content'), findsOneWidget);
      result.complete(true);
      await tester.pump();
      await pending;
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('L.refreshComplete'), findsOneWidget);
      expect(_icon(testIcons.check), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(state.value.value, const FrostPullRefreshValue(phase: FrostPullRefreshPhase.idle, extent: 0));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('a refresh view takes drag devices from the surrounding scroll behaviour', (tester) async {
    const devices = {PointerDeviceKind.touch, PointerDeviceKind.stylus};
    await tester.pumpWidget(
      frostTestApp(
        ScrollConfiguration(
          behavior: const _Devices(devices),
          child: FrostRefreshView(
            builder: (context, physics, locators) => CustomScrollView(
              physics: physics,
              slivers: const [SliverToBoxAdapter(child: SizedBox(height: 3000))],
            ),
          ),
        ),
      ),
    );
    expect(ScrollConfiguration.of(tester.element(find.byType(Viewport))).dragDevices, devices);
  });
}

Finder _icon(FrostIconData icon) => find.byWidgetPredicate((widget) => widget is FrostIcon && widget.icon == icon);

double _turns(WidgetTester tester) =>
    tester.widget<RotationTransition>(find.descendant(of: find.byType(AnimatedRotation), matching: find.byType(RotationTransition))).turns.value;

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(FrostPullRefresh.failedHold + const Duration(seconds: 1));
}

/// Mounts a real [FrostPullRefresh] with the header and returns a driver that
/// feeds it the scroll notifications of a pull at the top.
Future<_Pull> _pumpHeader(WidgetTester tester, {TargetPlatform platform = TargetPlatform.android, bool reduced = false}) async {
  final refresh = _Refresh();
  late BuildContext context;
  final child = FrostPullRefresh(
    onRefresh: refresh.call,
    child: Builder(
      builder: (inner) {
        context = inner;
        return const CustomScrollView(
          physics: frostRefreshPhysics,
          slivers: [
            FrostRefreshSliverHeader(),
            SliverToBoxAdapter(child: SizedBox(height: 2000)),
          ],
        );
      },
    ),
  );
  await tester.pumpWidget(
    frostTestApp(
      Scaffold(
        body: reduced ? MediaQuery(data: const MediaQueryData(disableAnimations: true), child: child) : child,
      ),
      platform: platform,
    ),
  );
  return _Pull(tester, refresh, () => context);
}

class _Pull {
  _Pull(this.tester, this.refresh, this.context);

  final WidgetTester tester;
  final _Refresh refresh;
  final BuildContext Function() context;
  var _extent = 0.0;
  var _started = false;

  static final _metrics = FixedScrollMetrics(
    minScrollExtent: 0,
    maxScrollExtent: 1400,
    pixels: 0,
    viewportDimension: 600,
    axisDirection: AxisDirection.down,
    devicePixelRatio: 1,
  );

  /// Moves the pulled extent to [extent], starting the pull on the first call.
  Future<void> to(double extent) async {
    final target = context();
    if (!_started) {
      ScrollStartNotification(metrics: _metrics, context: target).dispatch(target);
      _started = true;
    }
    OverscrollNotification(metrics: _metrics, context: target, overscroll: -2 * (extent - _extent)).dispatch(target);
    _extent = extent;
    await tester.pump();
  }

  Future<void> release() async {
    final target = context();
    ScrollEndNotification(metrics: _metrics, context: target).dispatch(target);
    _started = false;
    _extent = 0;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
  }
}

/// A refresh whose results the test completes by hand.
class _Refresh {
  final completers = <Completer<bool>>[];
  Completer<bool> get last => completers.last;
  Future<bool> call() {
    final completer = Completer<bool>();
    completers.add(completer);
    return completer.future;
  }
}

class _Devices extends ScrollBehavior {
  const _Devices(this.devices);
  final Set<PointerDeviceKind> devices;
  @override
  Set<PointerDeviceKind> get dragDevices => devices;
}
