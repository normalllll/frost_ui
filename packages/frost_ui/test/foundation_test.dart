import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'support.dart';

const _fonts = testFonts;
final _config = testConfig;

void main() {
  group('FrostFonts', () {
    test('Simplified Chinese draws Traditional when no TC family is bundled', () {
      final chain = _fonts.resolve(
        platform: TargetPlatform.windows,
        locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      );
      expect(chain.family, 'SC');
      expect(chain.fallbacks.first, 'JP');
      expect(chain.fallbacks, containsAllInOrder(['Microsoft JhengHei UI', 'Microsoft YaHei UI', 'Yu Gothic UI', 'Segoe UI Emoji']));
    });

    test('a bundled TC family is used for Traditional Chinese locales', () {
      const fonts = FrostFonts(japanese: 'JP', simplifiedChinese: 'SC', traditionalChinese: 'TC', defaultScript: FrostContentScript.japanese);
      expect(fonts.resolve(platform: TargetPlatform.windows, locale: const Locale('zh', 'TW')).family, 'TC');
      expect(fonts.resolve(platform: TargetPlatform.windows, locale: const Locale('zh', 'CN')).family, 'SC');
    });

    test('non-CJK locales follow the default script', () {
      final chain = _fonts.resolve(platform: TargetPlatform.linux, locale: const Locale('en'));
      expect(chain.family, 'JP');
      expect(chain.fallbacks.take(4), ['SC', 'Noto Sans CJK JP', 'Noto Sans CJK SC', 'Noto Sans CJK TC']);
    });

    test('content script detection', () {
      expect(detectContentScript('ひらがな'), FrostContentScript.japanese);
      expect(detectContentScript('这是简体'), FrostContentScript.simplifiedChinese);
      expect(detectContentScript('這是繁體'), FrostContentScript.traditionalChinese);
      expect(detectContentScript('hello'), isNull);
      expect(detectContentScript('ｶﾀｶﾅ'), FrostContentScript.japanese);
    });

    test('undecidable content follows the default script, else the interface language', () {
      const followsInterface = FrostFonts(japanese: 'JP', simplifiedChinese: 'SC', traditionalChinese: 'TC');
      const hant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
      expect(followsInterface.contentStyle(TargetPlatform.windows, hant, '漢字').fontFamily, 'TC');
      expect(followsInterface.contentStyle(TargetPlatform.windows, hant, 'ひらがな').fontFamily, 'JP');
      expect(testFonts.contentStyle(TargetPlatform.windows, hant, '漢字').fontFamily, 'JP');
    });
  });

  group('accent', () {
    test('presets are all applicable on both brightnesses', () {
      for (final accent in FrostPalettes.pink.accentPresets) {
        for (final brightness in Brightness.values) {
          expect(validateAccent(accent, brightness, FrostPalettes.pink).canApply, isTrue, reason: '$accent $brightness');
        }
      }
    });

    test('near-canvas colours are rejected', () {
      for (final color in const [Color(0xFFFFFFFF), Color(0xFFFFFFFE), Color(0xFFF6F6F6)]) {
        expect(validateAccent(color, Brightness.light, FrostPalettes.pink).canApply, isFalse);
      }
      for (final color in const [Color(0xFF000000), Color(0xFF202124)]) {
        expect(validateAccent(color, Brightness.dark, FrostPalettes.pink).canApply, isFalse);
      }
    });

    test('pure black and white are rejected even where they contrast', () {
      expect(validateAccent(const Color(0xFFFFFFFF), Brightness.dark, FrostPalettes.pink).canApply, isFalse);
      expect(validateAccent(const Color(0xFF000000), Brightness.light, FrostPalettes.pink).canApply, isFalse);
    });

    test('copyWith moves each default accent into its brightness', () {
      const cyan = Color(0xFF087F9C);
      const lightCyan = Color(0xFF79DCF4);
      final palettes = FrostPalettes.pink.copyWith(lightDefaultAccent: cyan, darkDefaultAccent: lightCyan);
      expect(palettes.lightCool.accent, cyan);
      expect(palettes.darkWarm.accent, lightCyan);
      expect(palettes.defaultAccent(Brightness.dark), lightCyan);
      expect(FrostAppearance.initial(palettes).darkAccent, lightCyan);
      expect(palettes.palette(Brightness.light, FrostTone.cool, cyan).canvas, FrostPalettes.pink.lightCool.canvas);
    });
  });

  group('FrostAppearance', () {
    test('round-trips through its record', () {
      final appearance = FrostAppearance.initial(
        FrostPalettes.pink,
      ).copyWith(mode: ThemeMode.dark, darkTone: FrostTone.cool, darkAccent: const Color(0xFF4C8DFF), lightCustomAccent: const Color(0xFF00A68C));
      expect(FrostAppearance.fromRecord(appearance.toRecord(), FrostPalettes.pink), appearance);
    });

    test('invalid stored accents fall back to the default', () {
      final record = FrostAppearance.initial(FrostPalettes.pink).toRecord()..['lightAccent'] = 'FFFFFF';
      expect(FrostAppearance.fromRecord(record, FrostPalettes.pink).lightAccent, FrostPalettes.pink.lightDefaultAccent);
      expect(FrostAppearance.fromRecord(null, FrostPalettes.pink, fallbackMode: ThemeMode.light).mode, ThemeMode.light);
    });
  });

  testWidgets('FrostTheme carries the palette tokens and the font chain', (tester) async {
    final theme = FrostTheme.build(
      config: _config,
      brightness: Brightness.dark,
      platform: TargetPlatform.windows,
      locale: const Locale('ja'),
      tone: FrostTone.warm,
    );
    expect(theme.extension<FrostThemeTokens>()!.canvas, FrostPalettes.pink.darkWarm.canvas);
    expect(theme.colorScheme.primary, FrostPalettes.pink.darkDefaultAccent);
    expect(theme.textTheme.bodyMedium!.fontFamily, 'JP');
  });

  testWidgets('FrostSurface renders opaque under reduce transparency', (tester) async {
    Widget surface({required bool reduce}) => MaterialApp(
      theme: FrostTheme.build(config: _config, brightness: Brightness.light, platform: TargetPlatform.windows, locale: const Locale('en')),
      home: FrostScope(
        config: _config,
        reduceTransparency: reduce,
        child: const FrostSurface(role: FrostSurfaceRole.chrome, child: SizedBox(width: 40, height: 40)),
      ),
    );
    await tester.pumpWidget(surface(reduce: false));
    expect(tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled, isTrue);
    await tester.pumpWidget(surface(reduce: true));
    expect(tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled, isFalse);
  });
}
