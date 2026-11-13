import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/media.dart';
import 'package:frost_ui/src/foundation/_ambient_material.dart';
import 'package:frost_ui/src/foundation/_glass_material.dart';
import 'package:frost_ui/src/foundation/_media_contrast.dart';
import 'package:frost_ui/src/foundation/color_math.dart' show colorContrast;
import 'package:frost_ui/src/surface/_window_background.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

FrostAmbientSample image(int width, int height, Color Function(int x, int y) pixel) => FrostAmbientSample(width, height, [
  for (var y = 0; y < height; y++)
    for (var x = 0; x < width; x++) pixel(x, y),
]);

const _stops = [Color(0xff142463), Color(0xff5b3a9e), Color(0xffc8507a), Color(0xfff27a3c), Color(0xffffc46b), Color(0xff1f7a86), Color(0xff0b3440)];

Color? chromeFill(WidgetTester tester) {
  for (final box in tester.renderObjectList<RenderDecoratedBox>(
    find.descendant(of: find.byKey(const ValueKey('chrome')), matching: find.byType(DecoratedBox)),
  )) {
    final decoration = box.decoration;
    final color = decoration is ShapeDecoration
        ? decoration.color
        : decoration is BoxDecoration
        ? decoration.color
        : null;
    if (color != null) return color;
  }
  return null;
}

void main() {
  test('modelled chrome keeps both inks readable over every content backdrop, ambient extremes included', () {
    final scenes = {
      'none': null,
      'photo': image(48, 30, (x, y) => _stops[(y * _stops.length) ~/ 30]),
      'purple': image(48, 30, (_, _) => const Color(0xff7a00ff)),
      'white': image(48, 30, (_, _) => const Color(0xffffffff)),
    };
    for (final brightness in Brightness.values) {
      for (final tone in FrostTone.values) {
        final tokens = FrostPalettes.pink.palette(brightness, tone, const Color(0xFFFC619D));
        final surface = tokens.surface;
        final bw = frostChromeFillOpacity(
          surface,
          frostGlassFillOpacity(surface, tokens.textPrimary, tokens.isDark),
          18,
          secondary: tokens.textSecondary,
          dark: tokens.isDark,
        );
        for (final entry in scenes.entries) {
          final ambient = entry.value?.resolvePalette(tokens, 1).background;
          final backdrops = frostChromeContentBackdrops(tokens, ambient);
          final alpha = frostChromeModelFillOpacity(surface, backdrops, primary: tokens.textPrimary, secondary: tokens.textSecondary, dark: tokens.isDark);
          expect(alpha, lessThanOrEqualTo(bw), reason: '$brightness $tone ${entry.key}');
          expect(alpha, greaterThanOrEqualTo(tokens.isDark ? frostGlassDarkFillMinimum : frostGlassLightFillMinimum));
          for (final backdrop in backdrops) {
            final background = Color.alphaBlend(surface.withValues(alpha: alpha), backdrop);
            for (final ink in [tokens.textPrimary, tokens.textSecondary]) {
              final painted = Color.alphaBlend(ink, background);
              final reason = '$brightness $tone ${entry.key} $backdrop $ink';
              expect(colorContrast(painted, background), greaterThanOrEqualTo(4.5), reason: reason);
              expect(colorContrast(Color(painted.toARGB32()), Color(background.toARGB32())), greaterThanOrEqualTo(4.5), reason: reason);
            }
          }
        }
      }
    }
  });

  for (final reduceMotion in [false, true]) {
    testWidgets('chrome is black/white safe in the frame media arrives and eases back (reduce motion $reduceMotion)', (tester) async {
      final rects = ValueNotifier<List<Rect>>(const []);
      late final FrostAmbientCardRegistry media;
      media = FrostAmbientCardRegistry(() => rects.value = media.current);
      final cards = FrostAmbientCardRegistry(() {});
      addTearDown(() {
        media.dispose();
        cards.dispose();
        rects.dispose();
      });
      final top = ValueNotifier(300.0);
      await tester.pumpWidget(
        frostTestApp(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
              child: FrostAmbientCardScope(
                registry: cards,
                media: media,
                mediaRects: rects,
                child: Stack(
                  children: [
                    ValueListenableBuilder(
                      valueListenable: top,
                      builder: (context, y, _) => Positioned(
                        left: 0,
                        top: y,
                        width: 400,
                        height: 160,
                        child: const FrostMediaFrame(child: ColoredBox(color: Color(0xFFFFFFFF))),
                      ),
                    ),
                    const Positioned(
                      left: 0,
                      top: 0,
                      width: 400,
                      height: 52,
                      child: FrostSurface(key: ValueKey('chrome'), role: FrostSurfaceRole.chrome, child: SizedBox.expand()),
                    ),
                  ],
                ),
              ),
            ),
          ),
          brightness: Brightness.dark,
        ),
      );
      await tester.pumpAndSettle();
      final tokens = FrostPalettes.pink.darkNeutral;
      final surfaceColor = chromeFill(tester)!;
      final colour = surfaceColor.withValues(alpha: 1);
      final model = frostChromeModelFillOpacity(
        colour,
        frostChromeContentBackdrops(tokens, null),
        primary: tokens.textPrimary,
        secondary: tokens.textSecondary,
        dark: true,
      );
      final bw = frostChromeFillOpacity(colour, frostGlassFillOpacity(colour, tokens.textPrimary, true), 18, secondary: tokens.textSecondary, dark: true);
      expect(model, lessThan(bw));
      expect(surfaceColor.a, closeTo(model, 1e-6));

      // Media scrolled under the chrome, 20 px a frame: on every frame where
      // it overlaps, the composed fill is already black/white safe and the
      // secondary ink keeps 4.5:1 over white and black.
      final guard = tester.renderObject<FrostRenderChromeMediaGuard>(find.byType(FrostChromeMediaGuard));
      for (var y = 300.0; y >= 20; y -= 20) {
        top.value = y;
        await tester.pump(const Duration(milliseconds: 16));
        if (y < 52) {
          final effective = guard.debugEffectiveAlpha;
          expect(effective, greaterThanOrEqualTo(bw - 1e-6), reason: 'top $y');
          for (final backdrop in [Colors.white, Colors.black]) {
            final background = Color.alphaBlend(colour.withValues(alpha: effective), backdrop);
            expect(colorContrast(Color.alphaBlend(tokens.textSecondary, background), background), greaterThanOrEqualTo(4.5), reason: 'top $y $backdrop');
          }
        }
      }
      await tester.pump();
      expect(chromeFill(tester)!.a, closeTo(bw, 1e-6), reason: 'the surface takes the safe alpha itself');

      // And away again: the fall eases over 200 ms, unless motion is reduced.
      top.value = 300;
      await tester.pump();
      await tester.pump();
      if (!reduceMotion) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 100));
        expect(chromeFill(tester)!.a, inExclusiveRange(model, bw), reason: 'mid-fall');
      }
      await tester.pump(const Duration(milliseconds: 250));
      expect(chromeFill(tester)!.a, closeTo(model, 1e-6));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a custom loader marked with FrostMediaImage counts as media', (tester) async {
    final rects = ValueNotifier<List<Rect>>(const []);
    late final FrostAmbientCardRegistry media;
    media = FrostAmbientCardRegistry(() => rects.value = media.current);
    final cards = FrostAmbientCardRegistry(() {});
    addTearDown(() {
      media.dispose();
      cards.dispose();
      rects.dispose();
    });
    await tester.pumpWidget(
      frostTestApp(
        FrostAmbientCardScope(
          registry: cards,
          media: media,
          mediaRects: rects,
          child: const Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                width: 400,
                height: 160,
                child: FrostMediaImage(child: ColoredBox(color: Color(0xFFFFFFFF))),
              ),
              Positioned(
                left: 0,
                top: 0,
                width: 400,
                height: 52,
                child: FrostSurface(key: ValueKey('chrome'), role: FrostSurfaceRole.chrome, child: SizedBox.expand()),
              ),
            ],
          ),
        ),
        brightness: Brightness.dark,
      ),
    );
    await tester.pumpAndSettle();
    final colour = chromeFill(tester)!.withValues(alpha: 1);
    final tokens = FrostPalettes.pink.darkNeutral;
    final bw = frostChromeFillOpacity(colour, frostGlassFillOpacity(colour, tokens.textPrimary, true), 18, secondary: tokens.textSecondary, dark: true);
    expect(chromeFill(tester)!.a, closeTo(bw, 1e-6));
  });

  testWidgets('solid chrome keeps the floor', (tester) async {
    final tokens = FrostPalettes.pink.darkNeutral;
    await tester.pumpWidget(
      frostTestApp(
        const Center(
          child: SizedBox(
            width: 200,
            height: 48,
            child: FrostSurface(key: ValueKey('chrome'), role: FrostSurfaceRole.chrome, child: SizedBox.expand()),
          ),
        ),
        brightness: Brightness.dark,
        reduceTransparency: true,
      ),
    );
    await tester.pumpAndSettle();
    final floor = frostNavigationGlassFillOpacity(tokens.surface, frostGlassFillOpacity(tokens.surface, tokens.textPrimary, true));
    expect(chromeFill(tester)!.a, greaterThanOrEqualTo(floor));
  });

  test('window glows use r 0.80 up to L(surface) − .005; the detail surround keeps r 0.65', () {
    final tokens = FrostPalettes.pink.darkNeutral;
    final raw = image(48, 30, (_, _) => const Color(0xff7a00ff)).palette;
    final window = frostAmbientGlows(tokens, raw, window: true);
    final detail = frostAmbientGlows(tokens, raw);
    expect(window.glows.first.share, .80);
    expect(detail.glows.first.share, .65);
    final surface = frostBackdropLightness(tokens.surface);
    for (final peak in frostAmbientGlowPeaks(tokens, raw, free: true)) {
      expect(frostBackdropLightness(Color(peak.toARGB32())), lessThanOrEqualTo(surface - .005 + .001));
      for (final ink in [tokens.textPrimary, tokens.textSecondary]) {
        expect(colorContrast(Color.alphaBlend(ink, peak), peak), greaterThanOrEqualTo(4.5));
      }
    }
    expect(debugDefaultTargetPlatformOverride, isNull);
  });
}
