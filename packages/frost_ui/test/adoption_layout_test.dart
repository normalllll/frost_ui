import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/desktop.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/overlays/_modal_frame.dart';
import 'support.dart';

void main() {
  for (final sample in [(width: 1000.0, dialog: true), (width: 600.0, dialog: true), (width: 500.0, dialog: false)]) {
    testWidgets('touch overview uses its local content width ${sample.width}', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final tabs = FrostTabsController<String>(initial: 'Home')..open('Messages', activate: false);
      addTearDown(tabs.dispose);
      final overview = FrostShellTabs<String>(
        controller: tabs,
        label: (_, label) => FrostTabLabel(title: label),
        countLabel: (n) => '$n tabs',
        closeTooltip: 'Close',
        newTabTooltip: 'New',
        onNewTab: () {},
      );
      final region = GlobalKey();
      await tester.pumpWidget(
        frostTestApp(
          Center(
            child: SizedBox(
              key: region,
              width: sample.width,
              height: 800,
              child: TestOverlayRegion(
                child: Builder(
                  builder: (context) => Center(
                    child: FrostButton(label: 'Overview', onPressed: () => overview.showOverview(context)),
                  ),
                ),
              ),
            ),
          ),
          platform: TargetPlatform.android,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Overview'));
      await tester.pumpAndSettle();
      final content = tester.getRect(find.byType(FrostModalFrame));
      final bounds = tester.getRect(find.byKey(region));
      expect(content.width, lessThanOrEqualTo(720));
      expect(content.center.dx, closeTo(bounds.center.dx, .01));
      if (sample.dialog) {
        expect(content.center.dy, closeTo(bounds.center.dy, .01));
      } else {
        expect(content.bottom, closeTo(bounds.bottom, .01));
      }
      await tester.tap(find.text('Messages'));
      await tester.pumpAndSettle();
      expect(tabs.active, 'Messages');
      expect(find.byType(FrostModalFrame), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final size in [const Size(411, 960), const Size(411, 640), const Size(411, 280)]) {
    for (final ratio in [16 / 9, .75, .2]) {
      testWidgets('adaptive detail fixes ratio $ratio above information at $size', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        const pixels = ValueKey('media pixels');
        await tester.pumpWidget(
          frostTestApp(
            FrostDetailLayout(
              header: const SizedBox(height: 48),
              stage: FrostMediaStage(
                aspectRatio: ratio,
                child: const SizedBox.expand(key: pixels),
              ),
              primary: const Text('Information'),
              sections: const [SizedBox(height: 2000)],
            ),
            platform: TargetPlatform.android,
          ),
        );
        await tester.pumpAndSettle();
        final media = tester.getRect(find.byKey(pixels));
        final scroll = tester.state<ScrollableState>(find.byType(Scrollable).last);
        final available = size.height - 48;
        final reserved = math.min(available, math.max(300, available * .42));
        final stageRoom = math.min(available, math.max(240, available - reserved));
        expect(scroll.position.viewportDimension, greaterThanOrEqualTo(available - stageRoom - .01));
        expect(media.height, closeTo(math.min(size.width / ratio, stageRoom), .01));
        if (media.height > 0) expect(media.width / media.height, closeTo(ratio, .00001));
        scroll.position.jumpTo(200);
        await tester.pumpAndSettle();
        expect(tester.getRect(find.byKey(pixels)), media);
        expect(find.byType(CustomScrollView), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('fixed media keeps on-media Back and State while only information scrolls', (tester) async {
    tester.view.physicalSize = const Size(411, 960);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 47);
    addTearDown(tester.view.reset);
    var ratio = 16 / 9;
    late StateSetter update;
    final media = GlobalKey();
    final pastValues = <bool>[];
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return FrostDetailLayout(
              header: const SizedBox(height: 48),
              mediaHeader: (_, past) {
                pastValues.add(past);
                return Row(
                  children: [FrostButton.icon(label: 'Back', icon: testIcons.back, onPressed: () {})],
                );
              },
              stage: FrostMediaStage(
                aspectRatio: ratio,
                child: SizedBox.expand(key: media),
              ),
              primary: const Text('Information'),
              sections: const [SizedBox(height: 2000)],
            );
          },
        ),
        platform: TargetPlatform.android,
      ),
    );
    await tester.pumpAndSettle();
    final retained = media.currentContext;
    final initial = tester.getRect(find.byKey(media));
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).last);
    scroll.position.jumpTo(500);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(media)), initial);
    final back = find.byWidgetPredicate((widget) => widget is FrostButton && widget.label == 'Back');
    expect(back.hitTestable(), findsOneWidget);
    expect(tester.getCenter(back).dy, greaterThan(47));
    expect(pastValues.every((past) => !past), isTrue);
    update(() => ratio = .2);
    await tester.pumpAndSettle();
    expect(media.currentContext, same(retained));
    expect(scroll.position.pixels, 500);
    expect(scroll.position.viewportDimension, closeTo(960 * .42, .01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('page header keeps its baseline height through 1.3 then grows for accessibility', (tester) async {
    for (final scale in [1.0, 1.3, 2.0]) {
      await tester.pumpWidget(
        frostTestApp(
          MediaQuery(
            data: MediaQueryData(size: const Size(411, 960), textScaler: TextScaler.linear(scale)),
            child: const Align(
              alignment: Alignment.topLeft,
              child: FrostPageHeader(title: FrostText('Title')),
            ),
          ),
        ),
      );
      final height = tester.getSize(find.byType(FrostPageHeader)).height;
      expect(height, scale <= 1.3 ? equals(48) : greaterThan(48));
      expect(tester.takeException(), isNull);
    }
  });
}
