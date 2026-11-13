import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/foundation/color_math.dart' show colorContrast;
import 'package:material_ui/material_ui.dart';

import 'support.dart';

Map<String, Color> surfaces(FrostThemeTokens t) => {
  'canvas': t.canvas,
  'surface': t.surface,
  'raised': t.surfaceRaised,
  'inset': t.surfaceInset,
  'muted': t.surfaceMuted,
  'tint': t.surfaceTint,
  'hover': t.hoverSurface,
  'pressed': t.pressedSurface,
};

double lstar(Color c) {
  final y = c.computeLuminance();
  return y > 216 / 24389 ? 116 * math.pow(y, 1 / 3) - 16 : y * 24389 / 27;
}

void main() {
  test('surface lightness aligns all tones with the neutral targets', () {
    final p = FrostPalettes.pink;
    expect(p.darkNeutral.canvas, const Color(0xFF141518));
    expect(p.darkNeutral.surface, const Color(0xFF1B1C20));
    expect(p.darkNeutral.surfaceRaised, const Color(0xFF24252A));
    expect(p.lightNeutral.canvas, const Color(0xFFEFEFF2));
    final targets = surfaces(p.darkNeutral);
    for (final tone in FrostTone.values) {
      final t = p.palette(Brightness.dark, tone, p.darkDefaultAccent);
      for (final entry in surfaces(t).entries) {
        // A single final 8-bit conversion can shift CIE L* by up to .21 here.
        expect(lstar(entry.value), closeTo(lstar(targets[entry.key]!), .5), reason: '$tone ${entry.key}');
      }
      expect(lstar(t.surfaceInset), greaterThan(lstar(t.canvas)));
      expect(lstar(t.surfaceInset), lessThan(lstar(t.surface)));
      expect(lstar(t.surfaceMuted), greaterThan(lstar(t.surface)));
      expect(lstar(t.surfaceMuted), lessThan(lstar(t.surfaceRaised)));
      final light = p.palette(Brightness.light, tone, p.lightDefaultAccent);
      expect(lstar(light.canvas), closeTo(lstar(p.lightNeutral.canvas), .25));
      expect(light.surface, light.surfaceRaised);
    }
  });

  test('all six palettes preserve normal and semantic 4.5 contrast on every surface', () {
    for (final brightness in Brightness.values) {
      for (final tone in FrostTone.values) {
        final t = FrostPalettes.pink.palette(brightness, tone, FrostPalettes.pink.defaultAccent(brightness));
        for (final surface in surfaces(t).entries) {
          for (final ink in [t.textPrimary, t.textSecondary, t.accentInk, t.infoInk, t.positiveInk, t.cautionInk, t.negativeInk]) {
            final painted = Color.alphaBlend(ink, surface.value);
            expect(colorContrast(painted, surface.value), greaterThanOrEqualTo(4.5), reason: '$brightness $tone ${surface.key} $ink');
            expect(colorContrast(Color(painted.toARGB32()), surface.value), greaterThanOrEqualTo(4.5), reason: '8-bit $brightness $tone ${surface.key} $ink');
          }
          expect(
            colorContrast(Color.alphaBlend(t.textTertiary, surface.value), surface.value),
            greaterThan(colorContrast(Color.alphaBlend(t.textPrimary.withValues(alpha: .35), surface.value), surface.value)),
          );
        }
        expect(t.textTertiary.a, 1);
        for (final surface in surfaces(t).values) {
          expect(colorContrast(t.textTertiary, surface), greaterThanOrEqualTo(4.5));
        }
        expect(t.textQuaternary, t.textTertiary);
        expect(t.edgeHairline.a, .06);
        expect(t.fill.a, .05);
        expect(t.fillStrong.a, brightness == Brightness.dark ? .08 : .085);
      }
    }
  });

  for (final tone in FrostTone.values) {
    for (final opaque in [false, true]) {
      testWidgets('dark raised shared hairline and shadows $tone opaque=$opaque', (tester) async {
        final theme = FrostTheme.build(
          config: testConfig,
          brightness: Brightness.dark,
          tone: tone,
          platform: TargetPlatform.windows,
          locale: const Locale('en'),
        );
        final t = theme.extension<FrostThemeTokens>()!;
        for (final role in [FrostSurfaceRole.glassPanel, FrostSurfaceRole.overlay, FrostSurfaceRole.sheet]) {
          await tester.pumpWidget(
            FrostScope(
              config: testConfig,
              reduceTransparency: opaque,
              child: MaterialApp(
                theme: theme,
                home: MediaQuery(
                  data: const MediaQueryData(devicePixelRatio: 2),
                  child: Center(
                    child: FrostSurface(role: role, child: const SizedBox(width: 40, height: 40)),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final shapes = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).map((w) => w.decoration).whereType<ShapeDecoration>();
          expect(shapes.any((d) => (d.shape as OutlinedBorder).side.color == t.edgeHairline && (d.shape as OutlinedBorder).side.width == .5), true);
          expect(shapes.any((d) => d.shadows?.length == 2), true);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
