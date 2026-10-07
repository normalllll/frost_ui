import 'package:flutter/material.dart';

import 'color_math.dart';

/// Background tone of a palette. Each brightness has a neutral, cool and
/// warm palette; follow-system mode always uses the neutral one.
enum FrostTone { neutral, cool, warm }

/// Semantic colours of one palette with its accent applied.
@immutable
class FrostThemeTokens extends ThemeExtension<FrostThemeTokens> {
  const FrostThemeTokens({
    required this.brightness,
    required this.tone,
    required this.accent,
    required this.canvas,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceInset,
    required this.surfaceMuted,
    required this.surfaceTint,
    required this.textPrimary,
    required this.textSecondary,
    required this.disabledText,
    required this.line,
    required this.hoverSurface,
    required this.pressedSurface,
    required this.separator,
    required this.threadLine,
    required this.shadow,
  });

  final Brightness brightness;
  final FrostTone tone;
  final Color accent;

  /// Solid action fill (primary buttons): exactly the chosen accent, never
  /// darkened toward a wine shade.
  Color get actionFill => accent;

  /// Its label: white where it reads, else a deep (or pale) tone of the
  /// accent's own hue rather than generic black or white, see [solidLabelTone].
  Color get onAction => solidLabelTone(accent);

  /// Glyphs drawn directly on the raw accent (checkbox check, switch thumb,
  /// colorScheme.onPrimary).
  Color get onAccent => readableOnAccent(accent);

  /// Keyboard focus ring: shown only while navigating by keyboard, so it
  /// may be strong.
  Color get focus => textPrimary;

  /// Outline of a text field being typed in. The caret already shows where
  /// input goes, so the outline marks the active field in the accent at the
  /// 3:1 a focus indicator needs, not with the dark keyboard ring.
  Color get fieldFocus => keyGraphicOn(surfaceRaised);

  /// Edge of an opaque floating panel (reduce transparency). Its solid fill
  /// already separates it from the canvas, so the line sits halfway between
  /// the canvas and [line] and is felt rather than drawn.
  Color get panelEdge => Color.lerp(canvas, line, .5)!;
  final Color canvas, surface, surfaceRaised, surfaceInset, surfaceMuted, surfaceTint;
  final Color textPrimary, textSecondary, disabledText;

  /// [separator] divides items of a list; [threadLine] connects nested replies.
  final Color line, hoverSurface, pressedSurface, separator, threadLine, shadow;
  bool get isDark => brightness == Brightness.dark;

  /// Accent tone for text and links on the palette's surfaces (4.5:1).
  Color get accentInk => readableAccentTone(accent, surface, 4.5);

  /// Translucent accent wash for persistent selection. It stays translucent
  /// so a selected item on glass still shows the material behind it.
  Color get selectionFill => accent.withValues(alpha: isDark ? .20 : .14);

  /// Opaque equivalent of [selectionFill] over a raised surface, for menus
  /// and reduced-transparency rendering.
  Color get selectionSurface => Color.alphaBlend(selectionFill, surfaceRaised);
  Color get selectionInk => readableAccentTone(accent, selectionSurface, 4.5);
  Color get selectionLine => keyGraphicOn(selectionSurface);

  /// Accent tone for key graphics such as indicators and icons (3:1).
  Color keyGraphicOn(Color background) => readableAccentTone(accent, background, 3);

  /// Tokens of the nearest [Theme], or the light neutral pink palette when the
  /// theme was not built by [FrostTheme].
  static FrostThemeTokens of(BuildContext context) => Theme.of(context).extension<FrostThemeTokens>() ?? FrostPalettes.pink.lightNeutral;

  @override
  FrostThemeTokens copyWith({
    Brightness? brightness,
    FrostTone? tone,
    Color? accent,
    Color? canvas,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceInset,
    Color? surfaceMuted,
    Color? surfaceTint,
    Color? textPrimary,
    Color? textSecondary,
    Color? disabledText,
    Color? line,
    Color? hoverSurface,
    Color? pressedSurface,
    Color? separator,
    Color? threadLine,
    Color? shadow,
  }) => FrostThemeTokens(
    brightness: brightness ?? this.brightness,
    tone: tone ?? this.tone,
    accent: accent ?? this.accent,
    canvas: canvas ?? this.canvas,
    surface: surface ?? this.surface,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    surfaceInset: surfaceInset ?? this.surfaceInset,
    surfaceMuted: surfaceMuted ?? this.surfaceMuted,
    surfaceTint: surfaceTint ?? this.surfaceTint,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    disabledText: disabledText ?? this.disabledText,
    line: line ?? this.line,
    hoverSurface: hoverSurface ?? this.hoverSurface,
    pressedSurface: pressedSurface ?? this.pressedSurface,
    separator: separator ?? this.separator,
    threadLine: threadLine ?? this.threadLine,
    shadow: shadow ?? this.shadow,
  );

  @override
  FrostThemeTokens lerp(ThemeExtension<FrostThemeTokens>? other, double t) {
    if (other is! FrostThemeTokens) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return FrostThemeTokens(
      brightness: t < .5 ? brightness : other.brightness,
      tone: t < .5 ? tone : other.tone,
      accent: mix(accent, other.accent),
      canvas: mix(canvas, other.canvas),
      surface: mix(surface, other.surface),
      surfaceRaised: mix(surfaceRaised, other.surfaceRaised),
      surfaceInset: mix(surfaceInset, other.surfaceInset),
      surfaceMuted: mix(surfaceMuted, other.surfaceMuted),
      surfaceTint: mix(surfaceTint, other.surfaceTint),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      disabledText: mix(disabledText, other.disabledText),
      line: mix(line, other.line),
      hoverSurface: mix(hoverSurface, other.hoverSurface),
      pressedSurface: mix(pressedSurface, other.pressedSurface),
      separator: mix(separator, other.separator),
      threadLine: mix(threadLine, other.threadLine),
      shadow: mix(shadow, other.shadow),
    );
  }
}

/// The six base palettes (light/dark × neutral/cool/warm) of an app together
/// with its default accents and accent presets.
@immutable
class FrostPalettes {
  const FrostPalettes({
    required this.lightDefaultAccent,
    required this.darkDefaultAccent,
    required this.accentPresets,
    required this.lightNeutral,
    required this.lightCool,
    required this.lightWarm,
    required this.darkNeutral,
    required this.darkCool,
    required this.darkWarm,
  });

  /// Initial accent of each brightness, also what "reset" restores. A brand
  /// colour often needs a lighter variant to stay readable on dark surfaces.
  final Color lightDefaultAccent, darkDefaultAccent;

  /// Preset accents offered by the appearance settings, usually the default
  /// accent first.
  final List<Color> accentPresets;
  final FrostThemeTokens lightNeutral, lightCool, lightWarm, darkNeutral, darkCool, darkWarm;

  Color defaultAccent(Brightness brightness) => brightness == Brightness.light ? lightDefaultAccent : darkDefaultAccent;

  /// The palette for [brightness] and [tone] with [accent] applied.
  FrostThemeTokens palette(Brightness brightness, FrostTone tone, Color accent) {
    final base = switch ((brightness, tone)) {
      (Brightness.light, FrostTone.neutral) => lightNeutral,
      (Brightness.light, FrostTone.cool) => lightCool,
      (Brightness.light, FrostTone.warm) => lightWarm,
      (Brightness.dark, FrostTone.neutral) => darkNeutral,
      (Brightness.dark, FrostTone.cool) => darkCool,
      (Brightness.dark, FrostTone.warm) => darkWarm,
    };
    return base.copyWith(accent: accent);
  }

  FrostPalettes copyWith({Color? lightDefaultAccent, Color? darkDefaultAccent, List<Color>? accentPresets}) {
    final light = lightDefaultAccent ?? this.lightDefaultAccent;
    final dark = darkDefaultAccent ?? this.darkDefaultAccent;
    return FrostPalettes(
      lightDefaultAccent: light,
      darkDefaultAccent: dark,
      accentPresets: accentPresets ?? this.accentPresets,
      lightNeutral: lightNeutral.copyWith(accent: light),
      lightCool: lightCool.copyWith(accent: light),
      lightWarm: lightWarm.copyWith(accent: light),
      darkNeutral: darkNeutral.copyWith(accent: dark),
      darkCool: darkCool.copyWith(accent: dark),
      darkWarm: darkWarm.copyWith(accent: dark),
    );
  }

  static const _pink = Color(0xFFFC619D);

  /// The standard palettes with the default pink accent.
  static const pink = FrostPalettes(
    lightDefaultAccent: _pink,
    darkDefaultAccent: _pink,
    accentPresets: [_pink, Color(0xFF4C8DFF), Color(0xFF00A68C), Color(0xFF9B7AF6), Color(0xFFC58A15), Color(0xFFE97640)],
    lightNeutral: FrostThemeTokens(
      brightness: Brightness.light,
      tone: FrostTone.neutral,
      accent: _pink,
      canvas: Color(0xFFF6F6F6),
      surface: Color(0xFFFFFFFF),
      surfaceRaised: Color(0xFFFFFFFF),
      surfaceInset: Color(0xFFECECEC),
      surfaceMuted: Color(0xFFF1F1F1),
      surfaceTint: Color(0xFFF6F6F6),
      textPrimary: Color(0xFF242424),
      textSecondary: Color(0xFF606060),
      disabledText: Color(0xFF777777),
      line: Color(0xFFD6D6D6),
      hoverSurface: Color(0xFFE7E7E7),
      pressedSurface: Color(0xFFDBDBDB),
      separator: Color(0xFFD0D0D0),
      threadLine: Color(0xFFBABABA),
      shadow: Color(0x10000000),
    ),
    lightCool: FrostThemeTokens(
      brightness: Brightness.light,
      tone: FrostTone.cool,
      accent: _pink,
      canvas: Color(0xFFF4F7FA),
      surface: Color(0xFFFFFFFF),
      surfaceRaised: Color(0xFFFFFFFF),
      surfaceInset: Color(0xFFEBF0F5),
      surfaceMuted: Color(0xFFF0F4F8),
      surfaceTint: Color(0xFFF4F7FA),
      textPrimary: Color(0xFF202832),
      textSecondary: Color(0xFF52606D),
      disabledText: Color(0xFF697582),
      line: Color(0xFFD6DEE7),
      hoverSurface: Color(0xFFE9EEF4),
      pressedSurface: Color(0xFFDDE5EE),
      separator: Color(0xFFCCD5DF),
      threadLine: Color(0xFFAEBBC9),
      shadow: Color(0x10000000),
    ),
    lightWarm: FrostThemeTokens(
      brightness: Brightness.light,
      tone: FrostTone.warm,
      accent: _pink,
      canvas: Color(0xFFF7F7F4),
      surface: Color(0xFFFFFFFF),
      surfaceRaised: Color(0xFFFFFFFF),
      surfaceInset: Color(0xFFEEEEEA),
      surfaceMuted: Color(0xFFF2F2EE),
      surfaceTint: Color(0xFFF7F7F4),
      textPrimary: Color(0xFF242421),
      textSecondary: Color(0xFF61615B),
      disabledText: Color(0xFF787870),
      line: Color(0xFFD6D6CF),
      hoverSurface: Color(0xFFE8E8E3),
      pressedSurface: Color(0xFFDDDDD6),
      separator: Color(0xFFD0D0C8),
      threadLine: Color(0xFFBCBCB3),
      shadow: Color(0x10000000),
    ),
    darkNeutral: FrostThemeTokens(
      brightness: Brightness.dark,
      tone: FrostTone.neutral,
      accent: _pink,
      canvas: Color(0xFF202124),
      surface: Color(0xFF292A2D),
      surfaceRaised: Color(0xFF303134),
      surfaceInset: Color(0xFF252629),
      surfaceMuted: Color(0xFF36373A),
      surfaceTint: Color(0xFF303134),
      textPrimary: Color(0xFFE8EAED),
      textSecondary: Color(0xFFB9BDC4),
      disabledText: Color(0xFF858991),
      line: Color(0xFF4A4D51),
      hoverSurface: Color(0xFF3A3B3F),
      pressedSurface: Color(0xFF45464B),
      separator: Color(0xFF565A60),
      threadLine: Color(0xFF747A82),
      shadow: Color(0x52000000),
    ),
    darkCool: FrostThemeTokens(
      brightness: Brightness.dark,
      tone: FrostTone.cool,
      accent: _pink,
      canvas: Color(0xFF1B2026),
      surface: Color(0xFF232A32),
      surfaceRaised: Color(0xFF2C3540),
      surfaceInset: Color(0xFF1F262E),
      surfaceMuted: Color(0xFF333F4B),
      surfaceTint: Color(0xFF2C3540),
      textPrimary: Color(0xFFECF1F7),
      textSecondary: Color(0xFFBECBD9),
      disabledText: Color(0xFF8A98A8),
      line: Color(0xFF465464),
      hoverSurface: Color(0xFF354351),
      pressedSurface: Color(0xFF414F5F),
      separator: Color(0xFF536477),
      threadLine: Color(0xFF70859B),
      shadow: Color(0x52000000),
    ),
    darkWarm: FrostThemeTokens(
      brightness: Brightness.dark,
      tone: FrostTone.warm,
      accent: _pink,
      canvas: Color(0xFF20201E),
      surface: Color(0xFF292927),
      surfaceRaised: Color(0xFF33332F),
      surfaceInset: Color(0xFF252523),
      surfaceMuted: Color(0xFF393934),
      surfaceTint: Color(0xFF33332F),
      textPrimary: Color(0xFFF5F4F1),
      textSecondary: Color(0xFFC3C1BA),
      disabledText: Color(0xFF929087),
      line: Color(0xFF4F4F46),
      hoverSurface: Color(0xFF3D3D37),
      pressedSurface: Color(0xFF484840),
      separator: Color(0xFF5C5C52),
      threadLine: Color(0xFF7B7B6D),
      shadow: Color(0x52000000),
    ),
  );
}

/// Window caption button colours, fixed across palettes and accents.
abstract final class FrostCaptionColors {
  static const closeHover = Color(0xFFE81123);
  static const closePressed = Color(0xFFC50F1F);
  static const onClose = Colors.white;
}
