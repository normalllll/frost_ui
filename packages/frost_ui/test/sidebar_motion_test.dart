import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrintSynchronously;
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'shell_test.dart' show shell;
import 'support.dart';
import 'window_caption_test.dart' show FakeWindow;

void main() {
  for (final direction in TextDirection.values) {
    testWidgets('sidebar fixed expanded layout $direction', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final window = FakeWindow();
      addTearDown(window.dispose);
      var initializations = 0;
      await tester.pumpWidget(
        frostTestApp(
          Directionality(
            textDirection: direction,
            child: FrostWindowCaptionScope(
              window: window,
              child: FrostShell(
                destinations: [FrostNavDestination(icon: testIcons.image, label: 'Browse destination')],
                selectedIndex: 0,
                onDestinationSelected: (_) {},
                atDestinationRoot: true,
                showsMobileNavigation: true,
                canGoBack: false,
                onBack: () {},
                brand: const FrostShellBrand(expanded: SizedBox(key: ValueKey('brand'), width: 120, height: 20)),
                child: _StateProbe(onInit: () => initializations++),
              ),
            ),
          ),
        ),
      );
      final nav = find.byType(FrostNavItem);
      final hit = find.descendant(of: nav, matching: find.byType(FrostClickSurface));
      final graphic = find.descendant(of: nav, matching: find.byType(FrostIcon)).first;
      final label = find.text('Browse destination');
      final samples = <Map<String, double>>[];
      // The sidebar lies on the reading start, so right-to-left is the mirror
      // image of left-to-right: positions are measured from the start edge.
      final rtl = direction == TextDirection.rtl;
      double fromStart(double x) => rtl ? 1440 - x : x;
      double startOf(Rect rect) => rtl ? 1440 - rect.right : rect.left;
      Map<String, double> sample() {
        final pane = tester.getRect(find.byType(FrostContentViewport));
        final ink = tester.getRect(hit);
        return {
          'pane': rtl ? 1440 - pane.right : pane.left,
          'inkX': startOf(ink),
          'inkWidth': ink.width,
          'iconX': fromStart(tester.getCenter(graphic).dx),
          'toggleX': fromStart(tester.getCenter(find.byType(FrostButton)).dx),
          'backX': fromStart(tester.getCenter(find.byKey(const ValueKey('frost-shell-back'))).dx),
          'brandX': startOf(tester.getRect(find.byKey(const ValueKey('brand')))),
          if (label.evaluate().isNotEmpty) 'textX': startOf(tester.getRect(label)),
          if (label.evaluate().isNotEmpty) 'textWidth': tester.getSize(label).width,
        };
      }

      await tester.tap(findFrostTooltip('L.expandNavigation'));
      await tester.pump();
      for (var frame = 0; frame < 60; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        samples.add(sample());
      }
      final expanded = sample();
      expect(expanded['pane'], 240);
      await tester.tap(findFrostTooltip('L.collapseNavigation'));
      await tester.pump();
      for (var frame = 0; frame < 60; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        samples.add(sample());
      }
      debugPrintSynchronously('sidebar frame trace: ${jsonEncode(samples)}');
      for (var index = 0; index < samples.length; index++) {
        final current = samples[index];
        expect(current['toggleX'], closeTo(30, .001));
        expect(current['backX'], expanded['backX']);
        expect(current['brandX'], expanded['brandX']);
        expect(current['iconX'], closeTo(30, .001));
        if (index > 0 && index != 60) {
          expect(index < 60 ? current['pane']! >= samples[index - 1]['pane']! : current['pane']! <= samples[index - 1]['pane']!, isTrue);
        }
        // The long label caps the expanded sidebar at 240.
        if (current['pane']! > 60 && current['pane']! < 240) {
          // Collapsed, the 40 tile is centred in the rail's 44 item column (10);
          // expanded it starts at the item inset (8).
          expect(current['inkX'], inInclusiveRange(8, 10), reason: 'The highlight must not shift sideways while the rail expands.');
          expect(current['textX'], closeTo(expanded['textX']!, .001));
          expect(current['textWidth'], closeTo(expanded['textWidth']!, .001), reason: 'Clip the fixed expanded text layout instead of compressing it.');
        }
      }
      expect(initializations, 1);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('reduced sidebar motion switches directly and preserves content', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var initializations = 0;
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: shell(child: _StateProbe(onInit: () => initializations++)),
          ),
        ),
      ),
    );
    await tester.tap(findFrostTooltip('L.expandNavigation'));
    await tester.pump();
    expect(tester.getTopLeft(find.byType(_StateProbe)).dx, 176);
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.getTopLeft(find.byType(_StateProbe)).dx, 176);
    await tester.tap(findFrostTooltip('L.collapseNavigation'));
    await tester.pump();
    expect(tester.getTopLeft(find.byType(_StateProbe)).dx, 60);
    expect(initializations, 1);
    expect(tester.takeException(), isNull);
  });
}

class _StateProbe extends StatefulWidget {
  const _StateProbe({required this.onInit});
  final VoidCallback onInit;
  @override
  State<_StateProbe> createState() => _StateProbeState();
}

class _StateProbeState extends State<_StateProbe> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
