import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/foundation/color_math.dart' show colorContrast, readableOnAccent;
import 'package:material_ui/material_ui.dart';

import 'support.dart';

void main() {
  testWidgets('controls remain usable at 200 percent text in both density and shape modes', (tester) async {
    for (final density in FrostDensity.values) {
      for (final continuous in [true, false]) {
        for (final brightness in Brightness.values) {
          final config = testConfig.copyWith(continuousCorners: continuous);
          late double fieldHeight;
          late double group, section, panel;
          await tester.pumpWidget(
            FrostScope(
              config: config,
              child: MaterialApp(
                theme: FrostTheme.build(config: config, brightness: brightness, platform: TargetPlatform.windows, locale: const Locale('en'), density: density),
                home: MediaQuery(
                  data: const MediaQueryData(size: Size(320, 700), textScaler: TextScaler.linear(2)),
                  child: Scaffold(
                    body: Center(
                      child: SizedBox(
                        width: 320,
                        child: SingleChildScrollView(
                          child: Builder(
                            builder: (context) {
                              final gaps = FrostGap.of(context);
                              group = gaps.group;
                              section = gaps.section;
                              panel = gaps.panelInset;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  FrostButton(label: 'Action', onPressed: () {}),
                                  const FrostTextField(label: 'Name', placeholder: 'Input'),
                                  FrostPicker<int>.menu(
                                    value: 1,
                                    options: const [
                                      FrostPickerOption(value: 1, label: 'One'),
                                      FrostPickerOption(value: 2, label: 'Two'),
                                    ],
                                    onChanged: (_) {},
                                    label: 'Choice',
                                  ),
                                  FrostPicker<int>.segmented(
                                    options: const [
                                      FrostPickerOption(value: 1, label: 'One'),
                                      FrostPickerOption(value: 2, label: 'Two'),
                                    ],
                                    value: 1,
                                    onChanged: (_) {},
                                    label: 'Choice',
                                  ),
                                  const FrostTag(label: 'Tag'),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(group, density == FrostDensity.compact ? 8 : 12);
          expect(section, 24);
          expect(panel, density == FrostDensity.compact ? 12 : 16);
          fieldHeight = tester.getSize(find.byType(TextField).first).height;
          expect(fieldHeight, greaterThanOrEqualTo(density.pointerFieldHeight));
          expect(tester.takeException(), isNull);
          await tester.tap(find.byType(TextField).first);
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
      }
    }
  });

  test('fallback shapes, fills and elevation follow configuration', () {
    for (final continuous in [true, false]) {
      final theme = FrostTheme.build(
        config: testConfig.copyWith(continuousCorners: continuous),
        brightness: Brightness.light,
        platform: TargetPlatform.windows,
        locale: const Locale('en'),
      );
      final t = theme.extension<FrostThemeTokens>()!;
      final iconShape = theme.iconButtonTheme.style!.shape!.resolve({})!;
      expect(iconShape, continuous ? isA<RoundedSuperellipseBorder>() : isA<RoundedRectangleBorder>());
      final iconRadius = switch (iconShape) {
        RoundedSuperellipseBorder(:final borderRadius) => borderRadius,
        RoundedRectangleBorder(:final borderRadius) => borderRadius,
        _ => throw StateError('Unexpected button shape'),
      };
      expect(iconRadius.resolve(TextDirection.ltr).topLeft.x, FrostRadius.forHeight(FrostDensity.comfortable.controlHeight));
      expect(theme.inputDecorationTheme.fillColor, t.fill);
      expect(theme.inputDecorationTheme.enabledBorder!.borderSide.width, 0);
      expect(frostFeedbackSurface(t, {WidgetState.hovered}), t.textPrimary.withValues(alpha: .04));
      expect(frostFeedbackSurface(t, {WidgetState.pressed}), t.textPrimary.withValues(alpha: .08));
      expect(theme.colorScheme.error, t.negativeInk);
    }
  });

  test('size radii stay within the 30 percent limit and inner clamps at xs', () {
    for (final size in FrostControlSize.values) {
      for (final touch in [false, true]) {
        final h = size.visualHeight(touch: touch);
        expect(FrostRadius.forHeight(h), lessThanOrEqualTo(h * .30));
      }
    }
    expect(FrostRadius.inner(8, 20), FrostRadius.xs);
    expect(FrostRadius.inner(24, 8), 16);
    expect(FrostRadius.forHeight(8), FrostRadius.xs);
  });
  testWidgets('density selects columns and shapes follow configuration', (tester) async {
    for (final platform in TargetPlatform.values) {
      for (final density in FrostDensity.values) {
        final resolved = density.forPlatform(platform);
        final pointer = [TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux].contains(platform);
        final touchColumn = !pointer;
        expect(resolved.controlHeight, FrostControlSize.regular.visualHeight(touch: touchColumn));
        expect(resolved.pointerFieldHeight, resolved.controlHeight);
        expect(resolved.targetHeight, pointer ? 36 : 44);
      }
    }
    for (final continuous in [true, false]) {
      late ShapeBorder shape;
      await tester.pumpWidget(
        FrostScope(
          config: testConfig.copyWith(continuousCorners: continuous),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                shape = FrostRadius.shape(context, FrostRadius.md);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(shape, continuous ? isA<RoundedSuperellipseBorder>() : isA<RoundedRectangleBorder>());
    }
  });

  test('typography uses the exact role weights and platform columns', () {
    for (final platform in TargetPlatform.values) {
      final type = FrostTypography(platform: platform);
      for (final role in FrostTextRole.values) {
        final weight = type.style(role).fontWeight!;
        expect([FontWeight.w300, FontWeight.w400, FontWeight.w500, FontWeight.w600], contains(weight));
        expect(weight == FontWeight.w300, role == FrostTextRole.hero);
        expect(type.style(role, numeric: true).fontFeatures!.single.feature, 'tnum');
      }
      expect(type.style(FrostTextRole.caption).letterSpacing, 0);
      final wide = [TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux].contains(platform);
      expect(type.style(FrostTextRole.hero).fontSize, wide ? 48 : 40);
      expect(type.style(FrostTextRole.hero).height, 1.1);
      expect(type.style(FrostTextRole.value).fontSize, 28);
      expect(type.style(FrostTextRole.value).height, 1.15);
      expect(type.style(FrostTextRole.title1).fontSize, wide ? 24 : 28);
      expect(type.style(FrostTextRole.title1).height, 1.25);
      expect(type.style(FrostTextRole.title2).fontSize, 18);
      expect(type.style(FrostTextRole.title2).height, 1.4);
      expect(type.style(FrostTextRole.headline).fontSize, 16);
      expect(type.style(FrostTextRole.headline).height, 1.4);
      expect(type.style(FrostTextRole.body).fontSize, 13);
      expect(type.style(FrostTextRole.body).height, 1.45);
      expect(type.style(FrostTextRole.callout).fontSize, 14);
      expect(type.style(FrostTextRole.callout).height, 1.4);
      expect(type.style(FrostTextRole.subheadline).fontSize, 13.5);
      expect(type.style(FrostTextRole.subheadline).height, 1.45);
      expect(type.style(FrostTextRole.footnote).fontSize, 12);
      expect(type.style(FrostTextRole.footnote).height, 1.45);
      expect(type.style(FrostTextRole.caption).fontSize, 11.5);
      expect(type.style(FrostTextRole.caption).height, 1.45);
    }
  });
  test('all Material text slots map to the specified semantic roles', () {
    final theme = FrostTheme.build(config: testConfig, brightness: Brightness.light, platform: TargetPlatform.windows, locale: const Locale('en'));
    final type = theme.extension<FrostTypography>()!;
    TextStyle materialStyle(FrostTextRole role) => type.style(role).copyWith(color: theme.colorScheme.onSurface);
    expect(theme.textTheme.displayLarge, materialStyle(FrostTextRole.hero));
    expect(theme.textTheme.displayMedium, materialStyle(FrostTextRole.hero));
    expect(theme.textTheme.displaySmall, materialStyle(FrostTextRole.value));
    expect(theme.textTheme.headlineLarge, materialStyle(FrostTextRole.value));
    expect(theme.textTheme.headlineMedium, materialStyle(FrostTextRole.title1));
    expect(theme.textTheme.headlineSmall, materialStyle(FrostTextRole.title1));
    expect(theme.textTheme.titleLarge, materialStyle(FrostTextRole.title2));
    expect(theme.textTheme.titleMedium, materialStyle(FrostTextRole.headline));
    expect(theme.textTheme.titleSmall, materialStyle(FrostTextRole.headline));
    expect(theme.textTheme.bodyLarge, materialStyle(FrostTextRole.body));
    expect(theme.textTheme.bodyMedium, materialStyle(FrostTextRole.body));
    expect(theme.textTheme.bodySmall, materialStyle(FrostTextRole.subheadline));
    expect(theme.textTheme.labelLarge, materialStyle(FrostTextRole.callout));
    expect(theme.textTheme.labelMedium, materialStyle(FrostTextRole.footnote));
    expect(theme.textTheme.labelSmall, materialStyle(FrostTextRole.caption));
  });

  test('six palettes have safe primary, secondary and semantic inks on opaque surfaces', () {
    for (final brightness in Brightness.values) {
      for (final tone in FrostTone.values) {
        final t = FrostPalettes.pink.palette(brightness, tone, FrostPalettes.pink.defaultAccent(brightness));
        final surfaces = {
          'canvas': t.canvas,
          'surface': t.surface,
          'surfaceRaised': t.surfaceRaised,
          'surfaceMuted': t.surfaceMuted,
          'surfaceInset': t.surfaceInset,
        };
        final inks = {
          'textPrimary': t.textPrimary,
          'textSecondary': t.textSecondary,
          'positiveInk': t.positiveInk,
          'cautionInk': t.cautionInk,
          'negativeInk': t.negativeInk,
          'infoInk': t.infoInk,
        };
        for (final surface in surfaces.entries) {
          for (final ink in inks.entries) {
            expect(
              colorContrast(Color.alphaBlend(ink.value, surface.value), surface.value),
              greaterThanOrEqualTo(4.5),
              reason: '$brightness $tone ${surface.key} ${ink.key}',
            );
          }
        }
        expect(t.textSecondary.a, t.isDark ? 1 : closeTo(.64, .001));
        if (!t.isDark) expect(t.textSecondary.withValues(alpha: 1), t.textPrimary);
        expect(t.textTertiary.a, 1);
        expect(t.textQuaternary, t.textTertiary);
        expect(t.disabledText.a, closeTo(.25, 1 / 255));
        expect(t.textSecondaryGlass.a, inInclusiveRange(.64, 1));
        expect(t.textTertiaryGlass.a, inInclusiveRange(t.isDark ? .44 : .47, 1));
      }
    }
  });

  test('derived opaque inks follow the worst surface even when palette roles change', () {
    for (final brightness in Brightness.values) {
      final base = FrostPalettes.pink.palette(brightness, FrostTone.neutral, FrostPalettes.pink.defaultAccent(brightness));
      for (var worstIndex = 0; worstIndex < 4; worstIndex++) {
        final surfaces = List.filled(4, brightness == Brightness.light ? Colors.white : const Color(0xFF222222));
        surfaces[worstIndex] = brightness == Brightness.light ? const Color(0xFFDDDDDD) : const Color(0xFF444444);
        final t = base.copyWith(surface: surfaces[0], surfaceRaised: surfaces[1], surfaceMuted: surfaces[2], surfaceInset: surfaces[3]);
        for (final surface in surfaces) {
          for (final ink in [t.positiveInk, t.cautionInk, t.negativeInk, t.infoInk]) {
            expect(colorContrast(ink, surface), greaterThanOrEqualTo(4.5), reason: '$brightness worst role $worstIndex');
          }
        }
      }
    }
  });

  test('solid actions keep exact accents and white labels without a contrast gate', () {
    final p = FrostPalettes.pink;
    expect(p.accentPresets, hasLength(6));
    for (final brightness in Brightness.values) {
      for (final accent in p.accentPresets) {
        final t = p.palette(brightness, FrostTone.neutral, accent);
        expect(t.onAction, Colors.white, reason: '$brightness $accent');
        expect(t.onAction, readableOnAccent(t.actionFill));
        expect(t.actionFill, accent);
      }
    }
    expect(colorContrast(p.darkNeutral.onNegative, p.darkNeutral.negativeFill), greaterThanOrEqualTo(4.5));
    expect(p.darkNeutral.onNegative, Colors.white);
  });
  test('palette configuration follows the applied accent and data colours', () {
    final p = FrostPalettes.pink.copyWith(categorical: const [Color(0xFF123456)]);
    final t = p.palette(Brightness.dark, FrostTone.warm, const Color(0xFF00FF00));
    expect(t.categorical, p.categorical);
    expect(t.sequential(0), t.fillSubtle);
    expect(t.sequential(1), t.accent);
    expect(t.copyWith(accent: const Color(0xFF0000FF)).sequential(1), const Color(0xFF0000FF));
    final mixed = t.lerp(t.copyWith(fill: const Color(0xFFFFFFFF)), .5);
    expect(mixed.fill, Color.lerp(t.fill, const Color(0xFFFFFFFF), .5));
    expect(t.shadowAmbient.single.blurRadius, 24);
    expect(t.shadowContact.single.offset, const Offset(0, 1));
  });
}
