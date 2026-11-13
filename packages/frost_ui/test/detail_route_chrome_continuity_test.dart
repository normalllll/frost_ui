import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'page_support.dart';
import 'support.dart';

void main() {
  testWidgets('the pushed page chrome fill changes gradually as its blur turns on and off', (tester) async {
    tester.view.physicalSize = const Size(1080, 2520);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    late BuildContext home;
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) {
            home = context;
            return const ColoredBox(color: Colors.black, child: SizedBox.expand());
          },
        ),
        brightness: Brightness.dark,
        platform: TargetPlatform.android,
      ),
    );
    final scroll = ScrollController(initialScrollOffset: 400);
    addTearDown(scroll.dispose);
    // Scrolled, so the header glass is shown.
    final page = FrostDetailPage<void>(
      child: pinnedPage(
        controller: scroll,
        header: const FrostPageHeader(title: Text('Results')),
        slivers: [
          SliverList.list(children: [for (var i = 0; i < 30; i++) SizedBox(height: 56, child: Text('Row $i'))]),
        ],
      ),
    );

    // The fill alpha of the pushed page's chrome, sampled every frame.
    double fill() {
      final boxes = find.descendant(of: find.byType(FrostPinnedChromeGlass), matching: find.byType(DecoratedBox));
      var alpha = 0.0;
      for (final box in tester.widgetList<DecoratedBox>(boxes)) {
        final color = switch (box.decoration) {
          BoxDecoration(:final color) || ShapeDecoration(:final color) => color,
          _ => null,
        };
        if (color != null && color.a > alpha) alpha = color.a;
      }
      return alpha;
    }

    Future<List<double>> frames() async {
      final samples = <double>[];
      for (var i = 0; i < 90; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (find.byType(FrostPinnedChromeGlass).evaluate().isEmpty) break;
        samples.add(fill());
      }
      return samples;
    }

    Navigator.of(home).push(page.createRoute(home));
    await tester.pump();
    final push = await frames();
    await tester.pumpAndSettle();
    Navigator.of(home).pop();
    await tester.pump();
    final pop = await frames();

    for (final (name, samples) in [('push', push), ('pop', pop)]) {
      final range = samples.reduce((a, b) => a > b ? a : b) - samples.reduce((a, b) => a < b ? a : b);
      expect(range, greaterThan(0), reason: '$name: the fill moves between the unblurred and blurred alphas');
      var step = 0.0;
      for (var i = 1; i < samples.length; i++) {
        final change = (samples[i] - samples[i - 1]).abs();
        if (change > step) step = change;
      }
      expect(step, lessThan(range / 3), reason: '$name: no single frame carries the whole change ($samples)');
    }
    expect(tester.takeException(), isNull);
  });
}
