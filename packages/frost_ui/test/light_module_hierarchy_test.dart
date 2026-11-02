import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/foundation/color_math.dart' show colorContrast;

import 'support.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final tone in FrostTone.values) {
      testWidgets('module separates from its actual parent: $brightness $tone', (tester) async {
        final theme = FrostTheme.build(config: testConfig, brightness: brightness, tone: tone, platform: TargetPlatform.windows, locale: const Locale('en'));
        final tokens = theme.extension<FrostThemeTokens>()!;
        for (final parent in [tokens.canvas, tokens.surface]) {
          late Color background;
          await tester.pumpWidget(
            FrostScope(
              config: testConfig,
              child: MaterialApp(
                theme: theme,
                home: FrostSurfaceScope(
                  isGlass: false,
                  background: parent,
                  child: FrostSurface(
                    role: FrostSurfaceRole.module,
                    child: Builder(
                      builder: (context) {
                        background = FrostSurfaceScope.maybeOf(context)!.background;
                        return const SizedBox(width: 300, height: 100);
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (tokens.isDark || parent == tokens.canvas) {
            expect(background.computeLuminance(), greaterThan(parent.computeLuminance()));
          } else {
            expect(background, Color.alphaBlend(Color.lerp(tokens.surface, tokens.canvas, .6)!, parent));
            expect(background.computeLuminance(), lessThan(parent.computeLuminance()));
            expect(background.computeLuminance(), greaterThan(tokens.canvas.computeLuminance()));
          }
          for (final ink in [tokens.textPrimary, tokens.textSecondary]) {
            expect(colorContrast(Color.alphaBlend(ink, background), background), greaterThanOrEqualTo(4.5));
          }
          for (final accent in FrostPalettes.pink.accentPresets) {
            final accentInk = tokens.copyWith(accent: accent).accentInk;
            expect(colorContrast(accentInk, background), greaterThanOrEqualTo(4.5));
          }
          final decorations = tester
              .renderObjectList<RenderDecoratedBox>(find.descendant(of: find.byType(FrostSurface), matching: find.byType(DecoratedBox)))
              .map((box) => box.decoration)
              .whereType<ShapeDecoration>();
          expect(decorations.expand((decoration) => decoration.shadows ?? <BoxShadow>[]), isEmpty);
          expect(decorations.every((decoration) => (decoration.shape as OutlinedBorder).side == BorderSide.none), isTrue);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
