import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/desktop.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/overlays/_modal_frame.dart';
import 'package:material_ui/material_ui.dart';

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
