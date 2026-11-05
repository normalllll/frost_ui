import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

void main() {
  testWidgets('system protection paints over Navigator overlay and follows return', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 47);
    addTearDown(tester.view.reset);
    final navigator = GlobalKey<NavigatorState>();
    final capture = GlobalKey();
    await tester.pumpWidget(
      FrostScope(
        config: testConfig,
        child: MaterialApp(
          navigatorKey: navigator,
          theme: FrostTheme.build(config: testConfig, brightness: Brightness.light, platform: TargetPlatform.android, locale: const Locale('en')),
          builder: (context, child) => RepaintBoundary(
            key: capture,
            child: FrostMediaSystemChromeHost(child: child!),
          ),
          home: const ColoredBox(color: Colors.white),
        ),
      ),
    );
    double? initial;
    Future<double> sample() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(capture));
      final image = (await tester.runAsync(() => boundary.toImage()))!;
      final bytes = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
      final red = bytes.getUint8((10 * image.width + 195) * 4) / 255;
      image.dispose();
      return red;
    }

    initial = await sample();
    expect(initial, 1);
    navigator.currentState!.push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, _, _) => const FrostMediaSystemChrome(child: ColoredBox(color: Colors.white)),
      ),
    );
    await tester.pumpAndSettle();
    final entry = OverlayEntry(
      builder: (_) => const Positioned.fill(child: ColoredBox(color: Colors.white)),
    );
    navigator.currentState!.overlay!.insert(entry);
    await tester.pump();
    final stable = await sample();
    expect(stable, lessThan(.4), reason: 'an opaque overlay cannot cover the host gradient');
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(capture));
    final annotation = boundary.debugLayer!.find<SystemUiOverlayStyle>(const Offset(195, 10));
    expect(annotation!.statusBarIconBrightness, Brightness.light);
    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final middle = await sample();
    expect(middle, greaterThan(stable));
    expect(middle, lessThan(initial));
    await tester.pumpAndSettle();
    expect(await sample(), 1);
    entry.remove();
    entry.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  group('protection over edge-to-edge media', () {
    final navigator = GlobalKey<NavigatorState>();
    final capture = GlobalKey();

    Future<double> strength(WidgetTester tester) async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(capture));
      final image = (await tester.runAsync(() => boundary.toImage()))!;
      final bytes = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
      final red = bytes.getUint8((10 * image.width + 195) * 4) / 255;
      image.dispose();
      return 1 - red;
    }

    bool lightIcons(WidgetTester tester) {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(capture));
      return boundary.debugLayer!.find<SystemUiOverlayStyle>(const Offset(195, 10))?.statusBarIconBrightness == Brightness.light;
    }

    Future<void> app(WidgetTester tester, Widget home) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 47);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        FrostScope(
          config: testConfig,
          child: MaterialApp(
            navigatorKey: navigator,
            theme: FrostTheme.build(config: testConfig, brightness: Brightness.light, platform: TargetPlatform.android, locale: const Locale('en')),
            builder: (context, child) => RepaintBoundary(
              key: capture,
              child: FrostMediaSystemChromeHost(child: child!),
            ),
            home: home,
          ),
        ),
      );
    }

    // Records protection frame by frame and checks it never jumps and the
    // icons switch at most once.
    Future<List<double>> follow(WidgetTester tester, {required double maxStep, int frames = 28}) async {
      final values = [await strength(tester)];
      final icons = [lightIcons(tester)];
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        values.add(await strength(tester));
        icons.add(lightIcons(tester));
        expect((values.last - values[values.length - 2]).abs(), lessThanOrEqualTo(maxStep), reason: 'frame $i of $values');
      }
      var switches = 0;
      for (var i = 1; i < icons.length; i++) {
        if (icons[i] != icons[i - 1]) switches++;
      }
      expect(switches, lessThanOrEqualTo(1), reason: '$icons');
      return values;
    }

    testWidgets('it follows an opaque page pushed over the media and popped again', (tester) async {
      await app(tester, const FrostMediaSystemChrome(child: ColoredBox(color: Colors.white)));
      await tester.pumpAndSettle();
      final full = await strength(tester);
      expect(full, greaterThan(.3));
      expect(lightIcons(tester), isTrue);

      navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => const ColoredBox(color: Colors.white)));
      await tester.pump();
      final out = await follow(tester, maxStep: full * .12);
      expect(out.first, closeTo(full, .02));
      await tester.pumpAndSettle();
      expect(await strength(tester), 0);
      expect(lightIcons(tester), isFalse);

      navigator.currentState!.pop();
      await tester.pump();
      final back = await follow(tester, maxStep: full * .12);
      expect(back.first, lessThan(full * .12));
      await tester.pumpAndSettle();
      expect(await strength(tester), closeTo(full, .02));
      expect(lightIcons(tester), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });

    testWidgets('it fades when scrolling media passes under the header', (tester) async {
      final scrolled = <bool>[];
      await app(
        tester,
        StatefulBuilder(
          builder: (context, setState) => NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              final past = notification.metrics.pixels > 250;
              if (scrolled.isEmpty || scrolled.last != past) setState(() => scrolled.add(past));
              return false;
            },
            child: FrostMediaSystemChrome(
              active: scrolled.isEmpty || !scrolled.last,
              child: ListView(
                padding: EdgeInsets.zero,
                children: const [
                  ColoredBox(color: Colors.white, child: SizedBox(height: 300)),
                  SizedBox(height: 2000, child: ColoredBox(color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final full = await strength(tester);
      expect(full, greaterThan(.3));
      final gesture = await tester.startGesture(const Offset(195, 600));
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -400));
      await tester.pump();
      expect(scrolled.last, isTrue);
      final fading = await follow(tester, maxStep: full * .3, frames: 20);
      expect(fading.first, greaterThan(full * .5));
      expect(fading.last, lessThan(.02));
      await gesture.moveBy(const Offset(0, 440));
      await tester.pump();
      expect(scrolled.last, isFalse);
      final returning = await follow(tester, maxStep: full * .3, frames: 20);
      expect(returning.first, lessThan(full * .5));
      expect(returning.last, closeTo(full, .02));
      await gesture.up();
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  });
}
