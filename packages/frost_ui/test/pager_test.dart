import 'dart:ui' show PointerDeviceKind;

import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/media.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

void main() {
  Widget app(Widget child, {bool reduced = false, TextDirection direction = TextDirection.ltr, bool touch = false}) => frostTestApp(
    Theme(
      data: FrostTheme.build(
        config: testConfig,
        brightness: Brightness.light,
        platform: touch ? TargetPlatform.android : TargetPlatform.windows,
        locale: const Locale('en'),
        density: FrostDensity.compact,
      ),
      child: MediaQuery(
        data: MediaQueryData(size: const Size(800, 600), disableAnimations: reduced),
        child: Directionality(
          textDirection: direction,
          child: Center(child: SizedBox(width: 500, height: 300, child: child)),
        ),
      ),
    ),
  );
  void focus(WidgetTester tester) => Focus.of(tester.element(find.byType(PageView))).requestFocus();
  PageController pages(WidgetTester tester) => tester.widget<PageView>(find.byType(PageView)).controller!;
  Widget overlayPager(int count) =>
      FrostPager(itemCount: count, itemBuilder: (_, i) => Text('page $i'), indicatorPlacement: FrostPageIndicatorPlacement.overlay);
  Finder plate(WidgetTester tester) => find.descendant(
    of: find.byType(FrostPageIndicator),
    matching: find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          w.decoration is ShapeDecoration &&
          (w.decoration as ShapeDecoration).color == FrostThemeTokens.of(tester.element(find.byType(FrostPageIndicator))).onMediaScrim,
    ),
  );

  test('unbound controller requests are nonnegative and complete immediately', () async {
    final controller = FrostPagerController();
    addTearDown(controller.dispose);
    expect(controller.page, 0);
    controller.jumpTo(900);
    expect(controller.page, 900);
    await controller.animateTo(-4);
    expect(controller.page, 0);
  });

  testWidgets('initial controller priority, clamping, empty count and lazy first frame', (tester) async {
    final controller = FrostPagerController()..jumpTo(450);
    addTearDown(controller.dispose);
    final built = <int>{};
    var count = 900;
    late StateSetter update;
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return FrostPager(
              controller: controller,
              itemCount: count,
              initialPage: 2,
              itemBuilder: (_, i) {
                built.add(i);
                return Text('page $i');
              },
            );
          },
        ),
      ),
    );
    expect(controller.page, 450);
    expect(find.text('page 450'), findsOneWidget);
    expect(built.length, lessThan(8));
    update(() => count = 2);
    await tester.pump();
    expect(controller.page, 1);
    expect(find.text('page 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    update(() => count = 0);
    await tester.pump();
    expect(controller.page, 0);
    expect(find.byType(PageView), findsNothing);
    expect(find.byType(FrostPageIndicator), findsNothing);
    update(() => count = 10);
    await tester.pump();
    expect(find.text('page 0'), findsOneWidget);
    controller.jumpTo(1000);
    await tester.pump();
    expect(controller.page, 9);
    expect(find.text('page 9'), findsOneWidget);
  });

  testWidgets('initialPage without controller and replacement controller first frame', (tester) async {
    FrostPagerController? controller;
    final replacement = FrostPagerController()..jumpTo(4);
    addTearDown(replacement.dispose);
    late StateSetter update;
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return FrostPager(itemCount: 6, initialPage: 2, controller: controller, itemBuilder: (_, i) => Text('page $i'));
          },
        ),
      ),
    );
    expect(find.text('page 2'), findsOneWidget);
    controller = replacement;
    update(() {});
    await tester.pump();
    expect(find.text('page 4'), findsOneWidget);
  });

  testWidgets('standard spring frames, redirected motion, callback and reduced jump', (tester) async {
    final controller = FrostPagerController();
    addTearDown(controller.dispose);
    final changed = <int>[];
    await tester.pumpWidget(app(FrostPager(itemCount: 6, itemBuilder: (_, i) => Text('page $i'), controller: controller, onPageChanged: changed.add)));
    final completion = controller.animateTo(4);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final position = pages(tester).page!;
    expect(position, greaterThan(0));
    expect(position, lessThan(4));
    final redirected = controller.animateTo(1);
    expect(pages(tester).page, position);
    await tester.pumpAndSettle();
    await completion;
    await redirected;
    expect(controller.page, 1);
    expect(changed.last, 1);
    await tester.pumpWidget(app(FrostPager(itemCount: 6, itemBuilder: (_, i) => Text('page $i'), controller: controller), reduced: true));
    await controller.animateTo(5);
    await tester.pump();
    expect(pages(tester).page, 5);
    expect(controller.page, 5);
  });

  for (final direction in TextDirection.values) {
    testWidgets('all keyboard rules and drag in $direction', (tester) async {
      final controller = FrostPagerController()..jumpTo(1);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        app(
          FrostPager(controller: controller, itemCount: 5, itemBuilder: (_, i) => Text('page $i')),
          reduced: true,
          direction: direction,
        ),
      );
      focus(tester);
      await tester.pump();
      for (final (key, expected) in [
        (LogicalKeyboardKey.arrowRight, direction == TextDirection.ltr ? 2 : 0),
        (LogicalKeyboardKey.arrowLeft, 1),
        (LogicalKeyboardKey.pageDown, 2),
        (LogicalKeyboardKey.pageUp, 1),
        (LogicalKeyboardKey.end, 4),
        (LogicalKeyboardKey.home, 0),
      ]) {
        await tester.sendKeyEvent(key);
        await tester.pump();
        expect(controller.page, expected);
      }
      await tester.drag(find.byType(PageView), Offset(direction == TextDirection.ltr ? -400 : 400, 0));
      await tester.pumpAndSettle();
      expect(controller.page, 1);
    });
  }

  testWidgets('pointer hover controls, shared edge inset, endpoints and touch suppression', (tester) async {
    final controller = FrostPagerController();
    addTearDown(controller.dispose);
    Widget pager() => FrostPager(controller: controller, itemCount: 3, itemBuilder: (_, i) => Text('page $i'));
    await tester.pumpWidget(app(pager()));
    expect(findFrostTooltip('L.next'), findsNothing);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(PageView)));
    await tester.pumpAndSettle();
    expect(findFrostTooltip('L.previous'), findsNothing);
    expect(findFrostTooltip('L.next'), findsOneWidget);
    final next = find.byWidgetPredicate((w) => w is FrostButton && w.label == 'L.next');
    expect(tester.getRect(find.byType(PageView)).right - tester.getRect(next).right, 12);
    await tester.tap(next, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(controller.page, 1);
    expect(findFrostTooltip('L.previous'), findsOneWidget);
    controller.jumpTo(2);
    await tester.pumpAndSettle();
    expect(findFrostTooltip('L.next'), findsNothing);
    // A touch platform with a mouse gets the same arrows, until a finger is used.
    await tester.pumpWidget(app(pager(), touch: true));
    await mouse.moveTo(Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(PageView)));
    await tester.pumpAndSettle();
    expect(find.byType(FrostButton), findsOneWidget);
    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    await tester.pumpAndSettle();
    expect(find.byType(FrostButton), findsNothing);
    await mouse.removePointer();
  });

  testWidgets('below and overlay geometry, onMedia colors and localized counter', (tester) async {
    Widget pager(FrostPageIndicatorPlacement placement, int count) =>
        FrostPager(itemCount: count, itemBuilder: (_, i) => Text('page $i'), indicatorPlacement: placement);
    await tester.pumpWidget(app(pager(FrostPageIndicatorPlacement.below, 3)));
    expect(tester.getRect(find.byType(FrostPageIndicator)).top - tester.getRect(find.byType(PageView)).bottom, 8);
    await tester.pumpWidget(app(pager(FrostPageIndicatorPlacement.overlay, 3)));
    final indicator = find.byType(FrostPageIndicator);
    expect(tester.widget<FrostPageIndicator>(indicator).onMedia, isTrue);
    final tokens = FrostThemeTokens.of(tester.element(indicator));
    expect(tester.widget<DecoratedBox>(plate(tester)).decoration, isA<ShapeDecoration>().having((d) => d.color, 'color', tokens.onMediaScrim));
    expect(tester.getRect(find.byType(PageView)).bottom - tester.getRect(plate(tester)).bottom, 12);
    await tester.pumpWidget(app(pager(FrostPageIndicatorPlacement.below, 15)));
    expect(find.text('1 of 15'), findsOneWidget);
    expect(plate(tester), findsNothing);
  });

  for (final touch in [false, true]) {
    for (final count in [2, 10]) {
      testWidgets('overlay plate fits the dots with $count pages, touch $touch', (tester) async {
        await tester.pumpWidget(app(overlayPager(count), touch: touch));
        final band = tester.getRect(find.byType(FrostPageIndicator));
        final box = tester.getRect(plate(tester));
        expect(band.height, touch ? 44 : 36);
        expect(box.height, 14);
        expect(box.center.dy, band.center.dy);
        expect(box.width, greaterThan(box.height));
        expect(band.bottom, lessThanOrEqualTo(tester.getRect(find.byType(PageView)).bottom));
        expect(tester.getRect(find.byType(PageView)).bottom - box.bottom, touch ? 15 : 12);
      });
    }

    testWidgets('a tap in the band above or below the plate selects the nearest dot, touch $touch', (tester) async {
      await tester.pumpWidget(app(overlayPager(3), touch: touch));
      final band = tester.getRect(find.byType(FrostPageIndicator));
      final box = tester.getRect(plate(tester));
      final page = find.byType(PageView);
      await tester.tapAt(Offset(box.right - 12, band.top + 1));
      await tester.pumpAndSettle();
      expect(tester.widget<PageView>(page).controller!.page, 2);
      await tester.tapAt(Offset(box.left + 12, band.bottom - 1));
      await tester.pumpAndSettle();
      expect(tester.widget<PageView>(page).controller!.page, 0);
    });
  }

  testWidgets('overlay plate has small corners and text sets its counter height', (tester) async {
    await tester.pumpWidget(app(overlayPager(3)));
    final shape = (tester.widget<DecoratedBox>(plate(tester)).decoration as ShapeDecoration).shape;
    expect(shape, isNot(isA<StadiumBorder>()));
    expect(
      shape,
      anyOf(
        isA<RoundedRectangleBorder>().having((s) => s.borderRadius, 'radius', BorderRadius.circular(4)),
        isA<RoundedSuperellipseBorder>().having((s) => s.borderRadius, 'radius', BorderRadius.circular(4)),
      ),
    );
    await tester.pumpWidget(app(overlayPager(15), touch: true));
    expect(tester.getSize(plate(tester)).height, tester.getSize(find.text('1 of 15')).height + 8);
    expect(tester.getRect(find.byType(PageView)).bottom - tester.getRect(plate(tester)).bottom, 12);
  });

  testWidgets('keyboard focus paints the shared focus ring', (tester) async {
    final previous = FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = previous);
    await tester.pumpWidget(app(FrostPager(itemCount: 3, itemBuilder: (_, i) => Text('page $i'))));
    focus(tester);
    await tester.pumpAndSettle();
    final container = find
        .ancestor(of: find.byType(PageView), matching: find.byWidgetPredicate((w) => w is AnimatedContainer && w.foregroundDecoration != null))
        .first;
    final border = (tester.widget<AnimatedContainer>(container).foregroundDecoration! as BoxDecoration).border! as Border;
    expect(border.top.color, FrostThemeTokens.of(tester.element(container)).focus);
    expect(border.top.width, FrostMetrics.focusBorderWidth);
  });
  testWidgets('thumbnail focus owns keys inside a page', (tester) async {
    final controller = FrostPagerController();
    addTearDown(controller.dispose);
    var selected = 1;
    await tester.pumpWidget(
      app(
        FrostPager(
          controller: controller,
          itemCount: 3,
          itemBuilder: (_, _) => Column(
            children: [
              FrostThumbnailStrip(itemCount: 5, itemBuilder: (_, _) => const SizedBox(), selectedIndex: selected, onSelected: (value) => selected = value),
            ],
          ),
        ),
      ),
    );
    final strip = find.byType(FrostThumbnailStrip);
    final focusWidget = find
        .descendant(of: strip, matching: find.byWidgetPredicate((widget) => widget is Focus && (widget.focusNode?.canRequestFocus ?? false)))
        .first;
    tester.widget<Focus>(focusWidget).focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(selected, 2);
    expect(controller.page, 0);
  });

  testWidgets('empty bound requests finish, duplicate binding asserts and disposal ends motion', (tester) async {
    final controller = FrostPagerController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(FrostPager(itemCount: 0, itemBuilder: (_, _) => const SizedBox(), controller: controller)));
    await controller.animateTo(8);
    controller.jumpTo(3);
    await tester.pump();
    expect(controller.page, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      app(
        Column(
          children: [
            Expanded(
              child: FrostPager(controller: controller, itemCount: 3, itemBuilder: (_, i) => Text('first $i')),
            ),
            Expanded(
              child: FrostPager(controller: controller, itemCount: 3, itemBuilder: (_, i) => Text('second $i')),
            ),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isAssertionError);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app(FrostPager(itemCount: 10, itemBuilder: (_, _) => const SizedBox(), controller: controller)));
    final pending = controller.animateTo(8);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pumpWidget(const SizedBox());
    await pending;
    expect(tester.takeException(), isNull);
    controller.jumpTo(30);
    expect(controller.page, 30);
  });

  testWidgets('count shrink redirects a pending request and notifies outside build', (tester) async {
    final controller = FrostPagerController();
    addTearDown(controller.dispose);
    var count = 10;
    late StateSetter update;
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return ListenableBuilder(
              listenable: controller,
              builder: (_, _) => FrostPager(controller: controller, itemCount: count, itemBuilder: (_, i) => Text('page $i')),
            );
          },
        ),
      ),
    );
    final pending = controller.animateTo(9);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    update(() => count = 5);
    await tester.pumpAndSettle();
    await pending;
    expect(controller.page, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('runtime reduced motion and count clamp report the visible page safely', (tester) async {
    final controller = FrostPagerController();
    addTearDown(controller.dispose);
    var reduced = false, count = 10, reported = 0;
    late StateSetter update;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (_, setState) {
          update = setState;
          return app(
            FrostPager(
              controller: controller,
              itemCount: count,
              itemBuilder: (_, i) => Text('page $i'),
              onPageChanged: (value) => setState(() => reported = value),
            ),
            reduced: reduced,
          );
        },
      ),
    );
    final motion = controller.animateTo(9);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    update(() => reduced = true);
    await tester.pump();
    expect(pages(tester).page, 9);
    expect(reported, 9);
    expect(tester.takeException(), isNull);
    await motion;
    update(() => count = 3);
    await tester.pump();
    expect(pages(tester).page, 2);
    expect(controller.page, 2);
    expect(reported, 2);
    expect(tester.takeException(), isNull);
  });
  testWidgets('pinch inside a page preserves zoom and reset restores drag paging', (tester) async {
    final controller = FrostPagerController();
    final viewport = FrostMediaViewportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      app(
        FrostPager(
          controller: controller,
          itemCount: 3,
          itemBuilder: (_, i) => FrostMediaViewport(controller: i == 0 ? viewport : null, child: Text('media $i')),
        ),
      ),
    );
    final center = tester.getCenter(find.byType(FrostMediaViewport));
    final a = await tester.startGesture(center - const Offset(30, 0), pointer: 1);
    final b = await tester.startGesture(center + const Offset(30, 0), pointer: 2);
    await tester.pump();
    await a.moveBy(const Offset(-80, 0));
    await b.moveBy(const Offset(80, 0));
    await tester.pump();
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    final transform = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer)).transformationController!;
    expect(transform.value.getMaxScaleOnAxis(), greaterThan(1));
    expect(controller.page, 0);
    expect(pages(tester).position.physics.shouldAcceptUserOffset(pages(tester).position), isFalse);
    viewport.reset();
    await tester.pumpAndSettle();
    expect(pages(tester).position.physics.shouldAcceptUserOffset(pages(tester).position), isTrue);
    await tester.drag(find.byType(FrostMediaViewport), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(controller.page, 1);
  });
  testWidgets('media drag pages at base scale and pans only after zoom', (tester) async {
    final controller = FrostPagerController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      app(
        FrostPager(
          controller: controller,
          itemCount: 3,
          itemBuilder: (_, i) => FrostMediaViewport(child: Text('media $i')),
        ),
      ),
    );
    await tester.drag(find.byType(FrostMediaViewport).first, const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(controller.page, 1);
    final viewport = find.byType(FrostMediaViewport).first;
    final center = tester.getCenter(viewport);
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    final transform = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer).first).transformationController!;
    expect(transform.value.getMaxScaleOnAxis(), greaterThan(1));
    final before = transform.value.storage[12];
    await tester.drag(viewport, const Offset(100, 0));
    await tester.pumpAndSettle();
    expect(controller.page, 1);
    expect(transform.value.storage[12], isNot(before));
  });
  testWidgets('an autofocus pager pages with the arrow keys without a click first', (tester) async {
    final controller = FrostPagerController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      app(FrostPager(itemCount: 3, showsIndicator: false, autofocus: true, controller: controller, itemBuilder: (_, i) => Text('page $i')), reduced: true),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(controller.page, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(controller.page, 0);
    expect(tester.takeException(), isNull);
  });
}
