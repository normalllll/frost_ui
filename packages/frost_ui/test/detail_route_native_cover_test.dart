import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'page_support.dart';
import 'support.dart';

void main() {
  testWidgets('an Android detail page over a bright media page covers it gradually and settles without a jump', (tester) async {
    tester.view.physicalSize = const Size(411, 960);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 32);
    addTearDown(tester.view.reset);
    final navigator = GlobalKey<NavigatorState>();
    final capture = GlobalKey();
    await tester.pumpWidget(
      FrostScope(
        config: testConfig,
        child: MaterialApp(
          navigatorKey: navigator,
          theme: FrostTheme.build(config: testConfig, brightness: Brightness.dark, platform: TargetPlatform.android, locale: const Locale('en')),
          // As in an app: the window backdrop lies behind the routes, which
          // paint no page background of their own.
          builder: (context, child) => RepaintBoundary(
            key: capture,
            child: FrostMediaSystemChromeHost(
              child: Stack(fit: StackFit.expand, children: [const FrostAmbientBackdrop(), child!]),
            ),
          ),
          home: const SizedBox.expand(),
        ),
      ),
    );

    // Mean luma of the status band and of the middle of the screen.
    Future<(double, double)> sample() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(capture));
      final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: .25)))!;
      final bytes = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
      double mean(int top, int bottom) {
        var sum = 0.0;
        var count = 0;
        for (var y = top; y < bottom; y++) {
          for (var x = image.width ~/ 4; x < image.width * 3 ~/ 4; x++) {
            final i = (y * image.width + x) * 4;
            sum += .2126 * bytes.getUint8(i) + .7152 * bytes.getUint8(i + 1) + .0722 * bytes.getUint8(i + 2);
            count++;
          }
        }
        return sum / count;
      }

      final result = (mean(0, 8), mean(image.height * 2 ~/ 5, image.height * 3 ~/ 5));
      image.dispose();
      return result;
    }

    navigator.currentState!.push(
      FrostDetailPage<void>.media(
        child: const FrostMediaSystemChrome(
          child: ColoredBox(color: Color(0xFFF4F0E8), child: SizedBox.expand()),
        ),
      ).createRoute(navigator.currentContext!),
    );
    await tester.pumpAndSettle();
    final scroll = ScrollController(initialScrollOffset: 400);
    addTearDown(scroll.dispose);
    final results = FrostDetailPage<void>(
      child: pinnedPage(
        controller: scroll,
        header: const FrostPageHeader(title: Text('Results')),
        slivers: [
          SliverList.list(children: [for (var i = 0; i < 40; i++) SizedBox(height: 56, child: Text('Row $i'))]),
        ],
      ),
    );

    Future<List<(double, double)>> transition(void Function() start) async {
      final samples = [await sample()];
      start();
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        samples.add(await sample());
      }
      await tester.pumpAndSettle();
      samples.add(await sample());
      return samples;
    }

    final push = await transition(() => navigator.currentState!.push(results.createRoute(navigator.currentContext!)));
    final pop = await transition(() => navigator.currentState!.pop());

    for (final (name, samples) in [('push', push), ('pop', pop)]) {
      for (final (area, pick) in <(String, double Function((double, double)))>[('status band', (s) => s.$1), ('middle', (s) => s.$2)]) {
        final values = samples.map(pick).toList();
        final steps = [for (var i = 1; i < values.length; i++) (values[i] - values[i - 1]).abs()];
        // A lone jump is one step far larger than every other.
        final sorted = [...steps]..sort();
        final limit = sorted[sorted.length - 2] * 2 > 4 ? sorted[sorted.length - 2] * 2 : 4.0;
        expect(sorted.last, lessThanOrEqualTo(limit), reason: '$name $area: ${values.map((v) => v.round()).toList()}');
      }
    }
    expect(push.first.$2 - push.last.$2, greaterThan(60), reason: 'the results page covers the bright media page');
    expect(tester.takeException(), isNull);
  });
}
