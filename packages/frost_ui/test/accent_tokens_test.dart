import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/foundation/_media_contrast.dart';
import 'package:frost_ui/src/foundation/color_math.dart' show colorContrast, readableOnAccent, solidLabelTone, solidOverlayAlpha, solidWashColor;

import 'support.dart';

void main() {
  test('solid actions preserve original accents, white labels and black feedback', () {
    for (var red = 0; red <= 255; red += 17) {
      for (var green = 0; green <= 255; green += 17) {
        for (var blue = 0; blue <= 255; blue += 17) {
          final fill = Color.fromARGB(255, red, green, blue);
          final action = FrostPalettes.pink.lightNeutral.copyWith(accent: fill);
          expect(action.onAction, Colors.white);
          expect(action.actionFill, fill);
          expect(readableOnAccent(fill), Colors.white);
          expect(solidLabelTone(fill), Colors.white);
          expect(solidWashColor(fill), Colors.black);
          for (final requested in [0.0, .04, .08, .2]) {
            final background = Color.alphaBlend(
              solidWashColor(action.actionFill).withValues(alpha: solidOverlayAlpha(action.actionFill, requested)),
              action.actionFill,
            );
            expect(solidOverlayAlpha(fill, requested), requested);
            expect(background.computeLuminance(), lessThanOrEqualTo(fill.computeLuminance()));
          }
          final ink = solidLabelTone(fill);
          expect(ink, readableOnAccent(fill));
          for (final requested in [0.0, .04, .08, .2]) {
            final wash = solidWashColor(fill).withValues(alpha: solidOverlayAlpha(fill, requested));
            final background = Color.alphaBlend(wash, fill);
            expect(background, Color.alphaBlend(Colors.black.withValues(alpha: requested), fill));
          }
        }
      }
    }
  });

  test('presets retain original fills and remain selectable without a white-label contrast gate', () {
    for (final accent in FrostPalettes.pink.accentPresets) {
      expect(FrostPalettes.pink.lightNeutral.copyWith(accent: accent).actionFill, accent);
      for (final brightness in Brightness.values) {
        expect(validateAccent(accent, brightness, FrostPalettes.pink).canApply, isTrue);
      }
    }
  });

  test('scrim solver measures translucent ink after painting', () {
    for (final brightness in Brightness.values) {
      for (final tone in FrostTone.values) {
        final tokens = FrostPalettes.pink.palette(brightness, tone, FrostPalettes.pink.defaultAccent(brightness));
        final worst = tokens.isDark ? Colors.white : Colors.black;
        final ink = tokens.textSecondary;
        final opacity = frostContrastScrimOpacity(surface: tokens.canvas, ink: ink, worst: worst, minimum: 0);
        final background = Color.alphaBlend(tokens.canvas.withValues(alpha: opacity), worst);
        final paintedInk = Color.alphaBlend(ink, background);
        expect(colorContrast(paintedInk, background), greaterThanOrEqualTo(4.5));
        expect(colorContrast(Color(paintedInk.toARGB32()), Color(background.toARGB32())), greaterThanOrEqualTo(4.5));
      }
    }
  });

  for (final tone in FrostTone.values) {
    for (final opaque in [false, true]) {
      testWidgets('white raised materials share a physical hairline and shadows: $tone opaque=$opaque', (tester) async {
        final theme = FrostTheme.build(
          config: testConfig,
          brightness: Brightness.light,
          tone: tone,
          platform: TargetPlatform.windows,
          locale: const Locale('en'),
        );
        final tokens = theme.extension<FrostThemeTokens>()!;
        expect(tokens.surface, tokens.surfaceRaised);
        for (final role in [FrostSurfaceRole.glassPanel, FrostSurfaceRole.overlay, FrostSurfaceRole.sheet]) {
          await tester.pumpWidget(
            FrostScope(
              config: testConfig,
              reduceTransparency: opaque,
              child: MaterialApp(
                theme: theme,
                home: MediaQuery(
                  data: const MediaQueryData(devicePixelRatio: 2),
                  child: FrostSurface(role: role, child: const SizedBox(width: 40, height: 40)),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final shapes = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).map((box) => box.decoration).whereType<ShapeDecoration>();
          expect(shapes.any((shape) => shape.shadows?.length == 2), isTrue);
          expect(
            shapes.any(
              (shape) =>
                  shape.shape is OutlinedBorder &&
                  (shape.shape as OutlinedBorder).side.color == tokens.edgeHairline &&
                  (shape.shape as OutlinedBorder).side.width == .5,
            ),
            isTrue,
          );
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  for (final brightness in Brightness.values) {
    for (final tone in FrostTone.values) {
      testWidgets('nested panel stays at least as light as its module: $brightness $tone', (tester) async {
        late Color module, panel;
        final theme = FrostTheme.build(config: testConfig, brightness: brightness, tone: tone, platform: TargetPlatform.windows, locale: const Locale('en'));
        await tester.pumpWidget(
          FrostScope(
            config: testConfig,
            child: MaterialApp(
              theme: theme,
              home: FrostSurface(
                role: FrostSurfaceRole.module,
                child: Builder(
                  builder: (context) {
                    module = FrostSurfaceScope.maybeOf(context)!.background;
                    return FrostSurface(
                      role: FrostSurfaceRole.panel,
                      child: Builder(
                        builder: (context) {
                          panel = FrostSurfaceScope.maybeOf(context)!.background;
                          return const SizedBox(width: 40, height: 40);
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(panel.computeLuminance(), greaterThanOrEqualTo(module.computeLuminance()));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
