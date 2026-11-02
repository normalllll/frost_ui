import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/feedback/refresh_indicator.dart' show FrostRefreshSliverHeader;
import 'package:pull_to_refresh_notification/pull_to_refresh_notification.dart';

import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final platform in TargetPlatform.values) {
    testWidgets('refresh header maps modes using the host icons on $platform', (tester) async {
      final key = GlobalKey<_HeaderFeedState>();
      await tester.pumpWidget(
        frostTestApp(
          Scaffold(body: _HeaderFeed(key: key)),
          platform: platform,
        ),
      );
      Future<void> mode(PullToRefreshIndicatorMode value) async {
        key.currentState!.emit(value);
        await tester.pump();
        await tester.pump();
      }

      await mode(PullToRefreshIndicatorMode.drag);
      expect(find.text('L.pullToRefresh'), findsOneWidget);
      expect(_icon(testIcons.arrowDown), findsOneWidget);
      expect(find.byType(FrostRefreshDots), findsNothing);
      expect(_turns(tester), 0);
      final arrow = tester.element(find.byType(AnimatedRotation));

      await mode(PullToRefreshIndicatorMode.armed);
      expect(find.text('L.releaseToRefresh'), findsOneWidget);
      expect(tester.element(find.byType(AnimatedRotation)), same(arrow));
      await tester.pump(const Duration(milliseconds: 70));
      expect(_turns(tester), allOf(greaterThan(0), lessThan(.5)));
      await tester.pump(const Duration(milliseconds: 70));
      expect(_turns(tester), .5);

      await mode(PullToRefreshIndicatorMode.drag);
      expect(find.text('L.pullToRefresh'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 70));
      expect(_turns(tester), allOf(greaterThan(0), lessThan(.5)));
      await tester.pump(const Duration(milliseconds: 70));
      expect(_turns(tester), 0);

      for (final value in [PullToRefreshIndicatorMode.snap, PullToRefreshIndicatorMode.refresh]) {
        await mode(value);
        expect(find.text('L.refreshing'), findsOneWidget);
        expect(find.byType(FrostRefreshDots), findsOneWidget);
        expect(_icon(testIcons.arrowDown), findsNothing);
      }
      await mode(PullToRefreshIndicatorMode.done);
      expect(find.text('L.refreshComplete'), findsOneWidget);
      expect(_icon(testIcons.check), findsOneWidget);
      expect(_icon(testIcons.success), findsNothing);
      expect(find.byType(FrostRefreshDots), findsNothing);

      await mode(PullToRefreshIndicatorMode.error);
      expect(find.text('L.refreshFailed'), findsOneWidget);
      expect(_icon(testIcons.error), findsOneWidget);
      final icon = tester.widget<FrostIcon>(_icon(testIcons.error));
      expect(icon.color, FrostThemeTokens.of(tester.element(_icon(testIcons.error))).negativeInk);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('arrow reversal continues from its current angle', (tester) async {
    final key = GlobalKey<_HeaderFeedState>();
    await tester.pumpWidget(frostTestApp(Scaffold(body: _HeaderFeed(key: key))));
    key.currentState!.emit(PullToRefreshIndicatorMode.drag);
    await tester.pump();
    await tester.pump();
    key.currentState!.emit(PullToRefreshIndicatorMode.armed);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final before = _turns(tester);
    key.currentState!.emit(PullToRefreshIndicatorMode.drag);
    await tester.pump();
    await tester.pump();
    expect(_turns(tester), closeTo(before, .000001));
    await tester.pump(const Duration(milliseconds: 70));
    expect(_turns(tester), allOf(greaterThan(0), lessThan(before)));
    await tester.pump(const Duration(milliseconds: 70));
    expect(_turns(tester), 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion sets the arrow angle without rotation', (tester) async {
    final key = GlobalKey<_HeaderFeedState>();
    await tester.pumpWidget(
      frostTestApp(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(body: _HeaderFeed(key: key)),
        ),
      ),
    );
    for (final value in [PullToRefreshIndicatorMode.drag, PullToRefreshIndicatorMode.armed, PullToRefreshIndicatorMode.drag]) {
      key.currentState!.emit(value);
      await tester.pump();
      await tester.pump();
      expect(_turns(tester), value == PullToRefreshIndicatorMode.armed ? .5 : 0);
    }
    await tester.pumpWidget(const SizedBox());
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
      final state = tester.state<PullToRefreshNotificationState>(find.byType(PullToRefreshNotification));
      final pending = state.show(notificationDragOffset: FrostRefreshSliverHeader.reachToRefreshOffset)!;
      await tester.pump();
      expect(find.byType(FrostRefreshDots), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(calls, 1);
      expect(state.refreshIndicatorMode, PullToRefreshIndicatorMode.refresh);
      expect(state.notificationDragOffset, FrostRefreshSliverHeader.refreshOffset);
      await tester.pump(const Duration(seconds: 3));
      expect(state.notificationDragOffset, FrostRefreshSliverHeader.refreshOffset);
      expect(find.byType(FrostRefreshDots), findsOneWidget);
      expect(find.text('L.refreshing'), findsOneWidget);
      expect(find.text('Existing content'), findsOneWidget);
      result.complete(true);
      await tester.pump();
      await pending;
      // The dependency publishes done on the first retraction animation tick.
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('L.refreshComplete'), findsOneWidget);
      expect(_icon(testIcons.check), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(state.notificationDragOffset, isNull);
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

// Feed controlled notification modes through the dependency's public stream.
// This isolates header presentation from its gesture recognizer's state rules.
class _HeaderFeed extends PullToRefreshNotification {
  const _HeaderFeed({super.key})
    : super(
        onRefresh: _unusedRefresh,
        child: const CustomScrollView(slivers: [FrostRefreshSliverHeader()]),
      );
  @override
  _HeaderFeedState createState() => _HeaderFeedState();
}

Future<bool> _unusedRefresh() async => true;

class _HeaderFeedState extends PullToRefreshNotificationState {
  final _notices = StreamController<PullToRefreshScrollNotificationInfo>.broadcast();
  @override
  Stream<PullToRefreshScrollNotificationInfo> get onNoticed => _notices.stream;
  void emit(PullToRefreshIndicatorMode mode) => _notices.add(PullToRefreshScrollNotificationInfo(mode, 56, null, this));
  @override
  void dispose() {
    _notices.close();
    super.dispose();
  }
}

class _Devices extends ScrollBehavior {
  const _Devices(this.devices);
  final Set<PointerDeviceKind> devices;
  @override
  Set<PointerDeviceKind> get dragDevices => devices;
}
