import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/foundation/_glass_material.dart';
import 'package:frost_ui/src/foundation/color_math.dart' show colorContrast;

import 'support.dart';

Color? chromeFill(WidgetTester tester) {
  for (final box in tester.renderObjectList<RenderDecoratedBox>(find.descendant(of: find.byType(FrostSurface), matching: find.byType(DecoratedBox)))) {
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
  test('chrome drops the navigation floor only while blur is active', () {
    for (final tokens in [FrostPalettes.pink.darkNeutral, FrostPalettes.pink.lightNeutral]) {
      final base = frostGlassFillOpacity(tokens.surface, tokens.textPrimary, tokens.isDark);
      final floor = frostNavigationGlassFillOpacity(tokens.surface, base);
      expect(floor, greaterThan(base));
      final both = math.max(base, frostGlassFillOpacity(tokens.surface, tokens.textSecondary, tokens.isDark));
      expect(frostChromeFillOpacity(tokens.surface, base, 18, secondary: tokens.textSecondary, dark: tokens.isDark), both);
      expect(both, lessThan(floor));
      expect(frostChromeFillOpacity(tokens.surface, base, 0), floor);
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets('chrome outside an ambient host: the black/white-safe alpha with blur, the floor without ($brightness)', (tester) async {
      final tokens = brightness == Brightness.dark ? FrostPalettes.pink.darkNeutral : FrostPalettes.pink.lightNeutral;
      final base = frostGlassFillOpacity(tokens.surface, tokens.textPrimary, tokens.isDark);
      final floor = frostNavigationGlassFillOpacity(tokens.surface, base);
      Widget chrome(bool solid) => frostTestApp(
        const Center(
          child: SizedBox(
            width: 200,
            height: 48,
            child: FrostSurface(role: FrostSurfaceRole.chrome, child: SizedBox.expand()),
          ),
        ),
        brightness: brightness,
        reduceTransparency: solid,
      );
      await tester.pumpWidget(chrome(false));
      await tester.pumpAndSettle();
      expect(chromeFill(tester)!.a, closeTo(math.max(base, frostGlassFillOpacity(tokens.surface, tokens.textSecondary, tokens.isDark)), 1e-6));
      await tester.pumpWidget(chrome(true));
      await tester.pumpAndSettle();
      // Solid surfaces paint opaque, at or above the floor.
      expect(chromeFill(tester)!.a, greaterThanOrEqualTo(floor));
      expect(tester.takeException(), isNull);
    });
  }

  test('black/white-safe chrome inks stay readable over white, black and stripes', () {
    for (final brightness in Brightness.values) {
      for (final tone in FrostTone.values) {
        final tokens = FrostPalettes.pink.palette(brightness, tone, const Color(0xFFFC619D));
        final base = frostGlassFillOpacity(tokens.surface, tokens.textPrimary, tokens.isDark);
        final fill = tokens.surface.withValues(
          alpha: frostChromeFillOpacity(tokens.surface, base, 18, secondary: tokens.textSecondary, dark: tokens.isDark),
        );
        // A blurred stripe pattern mixes the two extremes, so its pixels lie
        // between white and black; check both ends and the mix.
        for (final backdrop in [Colors.white, Colors.black, const Color(0xFF808080)]) {
          final background = Color.alphaBlend(fill, backdrop);
          for (final ink in [tokens.textPrimary, tokens.textSecondary]) {
            final painted = Color.alphaBlend(ink, background);
            expect(colorContrast(painted, background), greaterThanOrEqualTo(4.5), reason: '$brightness $tone $backdrop');
          }
        }
      }
    }
  });
}
