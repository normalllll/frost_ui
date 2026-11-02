import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'support.dart';

Widget page({required TargetPlatform platform, required VoidCallback onTap, required ScrollController controller}) {
  final config = testConfig;
  return FrostScope(
    config: config,
    child: MaterialApp(
      theme: FrostTheme.build(config: config, brightness: Brightness.light, platform: platform, locale: const Locale('en')),
      builder: (_, child) => FrostToastHost(child: child!),
      home: Scaffold(
        body: Column(
          children: [
            FrostButton(label: 'Show', onPressed: () => FrostToast.info('Saved')),
            Align(
              alignment: Alignment.centerLeft,
              child: FrostButton(label: 'Outside', onPressed: onTap),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                children: [for (var i = 0; i < 80; i++) SizedBox(height: 40, child: Text('row $i'))],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    group('$platform', () {
      testWidgets('page taps and wheel reach the page outside the toast', (tester) async {
        tester.view.physicalSize = const Size(1147, 717);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var taps = 0;
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(page(platform: platform, onTap: () => taps++, controller: controller));
        await tester.tap(find.text('Show'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 900));
        expect(find.text('Saved'), findsOneWidget);

        await tester.tap(find.text('Outside'));
        expect(taps, 1);

        final pointer = TestPointer(1, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(pointer.hover(const Offset(300, 300)));
        await tester.sendEventToBinding(pointer.scroll(const Offset(0, 200)));
        await tester.pump();
        expect(controller.offset, greaterThan(0));
        expect(find.text('Saved'), findsOneWidget);
        await tester.pump(const Duration(seconds: 10));
        await tester.pumpAndSettle();
      });

      testWidgets('a tap on the card is not passed to the page', (tester) async {
        tester.view.physicalSize = const Size(1147, 717);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var taps = 0;
        final controller = ScrollController();
        addTearDown(controller.dispose);
        // The whole page is one tap target behind the card.
        await tester.pumpWidget(
          FrostScope(
            config: testConfig,
            child: MaterialApp(
              theme: FrostTheme.build(config: testConfig, brightness: Brightness.light, platform: platform, locale: const Locale('en')),
              builder: (_, child) => FrostToastHost(child: child!),
              home: Scaffold(
                body: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => taps++, child: const SizedBox.expand()),
              ),
            ),
          ),
        );
        FrostToast.info('Saved');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 900));
        final card = tester.getRect(find.text('Saved'));
        await tester.tapAt(card.center);
        expect(taps, 0);
        await tester.pump(const Duration(seconds: 10));
        await tester.pumpAndSettle();
      });
    });
  }
}
