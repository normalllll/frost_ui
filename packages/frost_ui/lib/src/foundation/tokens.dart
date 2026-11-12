import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart' show Theme, ThemeExtension;
import 'package:flutter/widgets.dart';

import '_glass_material.dart';
import '_missing_theme.dart';
import 'color_math.dart';

const _defaultCategorical = <Color>[
  Color(0xFF3B82F6),
  Color(0xFF14B8A6),
  Color(0xFF22C55E),
  Color(0xFFF59E0B),
  Color(0xFFF97316),
  Color(0xFFEF4444),
  Color(0xFF8B5CF6),
  Color(0xFFEC4899),
];

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
    required this.threadLine,
    required this.shadow,
    Color? textTertiary,
    Color? textQuaternary,
    Color? textSecondaryGlass,
    Color? textTertiaryGlass,
    Color? fillSubtle,
    Color? fill,
    Color? fillStrong,
    Color? separator,
    Color? positiveInk,
    Color? positiveTint,
    Color? cautionInk,
    Color? cautionTint,
    Color? negativeInk,
    Color? negativeTint,
    Color? infoInk,
    Color? infoTint,
    Color? onMediaScrim,
    Color? onMediaInk,
    Color? edgeHairline,
    Color? edgeHighlight,
    Color? mediaInnerStroke,
    List<BoxShadow>? shadowAmbient,
    List<BoxShadow>? shadowContact,
    this.categorical = _defaultCategorical,
  }) : _overrides = (
         textTertiary: textTertiary,
         textQuaternary: textQuaternary,
         textSecondaryGlass: textSecondaryGlass,
         textTertiaryGlass: textTertiaryGlass,
         fillSubtle: fillSubtle,
         fill: fill,
         fillStrong: fillStrong,
         separator: separator,
         positiveInk: positiveInk,
         positiveTint: positiveTint,
         cautionInk: cautionInk,
         cautionTint: cautionTint,
         negativeInk: negativeInk,
         negativeTint: negativeTint,
         infoInk: infoInk,
         infoTint: infoTint,
         onMediaScrim: onMediaScrim,
         onMediaInk: onMediaInk,
         edgeHairline: edgeHairline,
         edgeHighlight: edgeHighlight,
         mediaInnerStroke: mediaInnerStroke,
         shadowAmbient: shadowAmbient,
         shadowContact: shadowContact,
       );

  final Brightness brightness;
  final FrostTone tone;
  final Color accent;

  /// Solid actions use the original accent without darkening or recolouring.
  Color get actionFill => accent;

  /// White labels are a product choice, without a minimum contrast threshold.
  Color get onAction => solidLabelTone(actionFill);

  /// Destructive fills retain their independent semantic contrast rule.
  Color get negativeFill => readableAccentTone(_negative, Color(0xFFFFFFFF), 4.5);
  Color get onNegative => solidLabelTone(negativeFill);

  /// Glyphs drawn directly on the raw accent (checkbox check, switch thumb,
  /// colorScheme.onPrimary).
  Color get onAccent => readableOnAccent(accent);

  /// Neutral keyboard ring, distinct from accent selection and the caret.
  Color get focus => textPrimary.withValues(alpha: isDark ? .60 : .55);

  /// Neutral active-field hairline; the caret alone uses the accent.
  Color get fieldFocus => textPrimary.withValues(alpha: isDark ? .34 : .40);

  /// Edge of an opaque floating panel (reduce transparency). Its solid fill
  /// already separates it from the canvas, so the line sits halfway between
  /// the canvas and [line] and is felt rather than drawn.
  Color get panelEdge => Color.lerp(canvas, line, .5)!;
  final Color canvas, surface, surfaceRaised, surfaceInset, surfaceMuted, surfaceTint;
  final Color textPrimary, textSecondary, disabledText;

  /// [separator] divides items of a list; [threadLine] connects nested replies.
  final Color line, hoverSurface, pressedSurface, threadLine, shadow;
  final ({
    Color? textTertiary,
    Color? textQuaternary,
    Color? textSecondaryGlass,
    Color? textTertiaryGlass,
    Color? fillSubtle,
    Color? fill,
    Color? fillStrong,
    Color? separator,
    Color? positiveInk,
    Color? positiveTint,
    Color? cautionInk,
    Color? cautionTint,
    Color? negativeInk,
    Color? negativeTint,
    Color? infoInk,
    Color? infoTint,
    Color? onMediaScrim,
    Color? onMediaInk,
    Color? edgeHairline,
    Color? edgeHighlight,
    Color? mediaInnerStroke,
    List<BoxShadow>? shadowAmbient,
    List<BoxShadow>? shadowContact,
  })
  _overrides;

  static const _positive = Color(0xFF22A060);
  static const _caution = Color(0xFFD98A00);
  static const _negative = Color(0xFFE5484D);
  static const _info = Color(0xFF3B82F6);

  // Compare every opaque surface rather than assuming which palette role is
  // darkest or lightest. Preserve the source hue when adjusting its tone.
  Color _readableOnOpaqueSurfaces(Color colour, double minimum, {Color? overlay}) {
    final worst = [canvas, surface, surfaceRaised, surfaceMuted, surfaceInset, surfaceTint, hoverSurface, pressedSurface]
        .expand((surface) => overlay == null ? [surface] : [Color.alphaBlend(overlay, surface), Color(Color.alphaBlend(overlay, surface).toARGB32())])
        .reduce((first, second) => colorContrast(colour, first) <= colorContrast(colour, second) ? first : second);
    return readableAccentTone(colour, worst, minimum);
  }

  /// Small metadata stays readable on every opaque elevation. The reference
  /// tertiary hue is retained, with only the tone raised/lowered as necessary.
  Color get textTertiary => _overrides.textTertiary ?? _readableOnOpaqueSurfaces(isDark ? const Color(0xFF6F707A) : const Color(0xFF7A7B86), 4.5);
  Color get textQuaternary => _overrides.textQuaternary ?? textTertiary;
  Color get textSecondaryGlass => _overrides.textSecondaryGlass ?? frostGlassInk(surfaceRaised, textPrimary, isDark, .64, 4.5);
  Color get textTertiaryGlass => _overrides.textTertiaryGlass ?? frostGlassInk(surfaceRaised, textPrimary, isDark, isDark ? .44 : .47, 4.5);
  Color get fillSubtle => _overrides.fillSubtle ?? textPrimary.withValues(alpha: isDark ? .03 : .025);
  Color get fill => _overrides.fill ?? textPrimary.withValues(alpha: .05);
  Color get fillStrong => _overrides.fillStrong ?? textPrimary.withValues(alpha: isDark ? .08 : .085);
  Color get separator => _overrides.separator ?? (isDark ? Color(0xFFFFFFFF) : Color(0xFF000000)).withValues(alpha: .06);
  Color get positiveInk => _overrides.positiveInk ?? _readableOnOpaqueSurfaces(_positive, 4.5, overlay: positiveTint);
  Color get positiveTint => _overrides.positiveTint ?? _positive.withValues(alpha: isDark ? .20 : .12);
  Color get cautionInk => _overrides.cautionInk ?? _readableOnOpaqueSurfaces(_caution, 4.5, overlay: cautionTint);
  Color get cautionTint => _overrides.cautionTint ?? _caution.withValues(alpha: isDark ? .20 : .12);
  Color get negativeInk => _overrides.negativeInk ?? _readableOnOpaqueSurfaces(_negative, 4.5, overlay: negativeTint);
  Color get negativeTint => _overrides.negativeTint ?? _negative.withValues(alpha: isDark ? .20 : .12);
  Color get infoInk => _overrides.infoInk ?? _readableOnOpaqueSurfaces(_info, 4.5, overlay: infoTint);
  Color get infoTint => _overrides.infoTint ?? _info.withValues(alpha: isDark ? .20 : .12);

  /// Every scrim a component draws over media takes this colour at its own
  /// opacity.
  Color get onMediaScrim => _overrides.onMediaScrim ?? Color(0xFF000000).withValues(alpha: .54);

  /// Every ink a component draws over media derives from this colour.
  Color get onMediaInk => _overrides.onMediaInk ?? Color(0xFFFFFFFF);

  /// Opaque white material shared by switch and slider thumbs in both themes.
  /// Do not reuse onMediaInk: its app override must not recolour controls.
  Color get controlThumbFill => Color(0xFFFFFFFF);
  Color get edgeHairline => _overrides.edgeHairline ?? (isDark ? Color(0xFFFFFFFF) : Color(0xFF000000)).withValues(alpha: .06);
  Color get edgeHighlight => _overrides.edgeHighlight ?? Color(0xFFFFFFFF).withValues(alpha: isDark ? .06 : .45);
  Color get mediaInnerStroke => _overrides.mediaInnerStroke ?? (isDark ? Color(0xFFFFFFFF) : Color(0xFF000000)).withValues(alpha: isDark ? .08 : .06);
  List<BoxShadow> get shadowAmbient =>
      _overrides.shadowAmbient ??
      [
        BoxShadow(
          color: Color(0xFF000000).withValues(alpha: isDark ? .42 : .10),
          blurRadius: isDark ? 24 : 28,
          offset: const Offset(0, 8),
        ),
      ];
  List<BoxShadow> get shadowContact =>
      _overrides.shadowContact ??
      [
        BoxShadow(
          color: Color(0xFF000000).withValues(alpha: isDark ? .32 : .06),
          blurRadius: isDark ? 4 : 2,
          offset: const Offset(0, 1),
        ),
      ];

  /// App-configured categorical colours, copied from FrostPalettes.
  final List<Color> categorical;
  Color sequential(double t) => Color.lerp(fillSubtle, accent, t.clamp(0.0, 1.0))!;

  bool get isDark => brightness == Brightness.dark;

  /// Accent tone for text and links on the palette's surfaces (4.5:1).
  Color get accentInk => _readableOnOpaqueSurfaces(accent, 4.5);

  /// Translucent accent wash for persistent selection. It stays translucent
  /// so a selected item on glass still shows the material behind it.
  Color get selectionFill => accent.withValues(alpha: .14);

  /// Opaque equivalent of [selectionFill] over a raised surface, for menus
  /// and reduced-transparency rendering.
  Color get selectionSurface => Color.alphaBlend(selectionFill, surfaceRaised);
  Color get selectionInk => _readableOnOpaqueSurfaces(accent, 4.5, overlay: selectionFill);
  Color get selectionLine => keyGraphicOn(selectionSurface);

  /// Accent tone for key graphics such as indicators and icons (3:1).
  Color keyGraphicOn(Color background) => readableAccentTone(accent, background, 3);

  /// Tokens of the nearest [Theme], which must be built by `FrostTheme.build`.
  static FrostThemeTokens of(BuildContext context) {
    final tokens = Theme.of(context).extension<FrostThemeTokens>();
    if (tokens == null) throw frostMissingThemeError('FrostThemeTokens');
    return tokens;
  }

  // What the overridable roles resolve to, so an override equal to its derived
  // value compares equal, as at the end of a theme animation.
  List<Object> get _resolved => [
    textTertiary,
    textQuaternary,
    textSecondaryGlass,
    textTertiaryGlass,
    fillSubtle,
    fill,
    fillStrong,
    separator,
    positiveInk,
    positiveTint,
    cautionInk,
    cautionTint,
    negativeInk,
    negativeTint,
    infoInk,
    infoTint,
    onMediaScrim,
    onMediaInk,
    edgeHairline,
    edgeHighlight,
    mediaInnerStroke,
    ...shadowAmbient,
    shadowAmbient.length,
    ...shadowContact,
  ];

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FrostThemeTokens &&
        brightness == other.brightness &&
        tone == other.tone &&
        accent == other.accent &&
        canvas == other.canvas &&
        surface == other.surface &&
        surfaceRaised == other.surfaceRaised &&
        surfaceInset == other.surfaceInset &&
        surfaceMuted == other.surfaceMuted &&
        surfaceTint == other.surfaceTint &&
        textPrimary == other.textPrimary &&
        textSecondary == other.textSecondary &&
        disabledText == other.disabledText &&
        line == other.line &&
        hoverSurface == other.hoverSurface &&
        pressedSurface == other.pressedSurface &&
        threadLine == other.threadLine &&
        shadow == other.shadow &&
        listEquals(categorical, other.categorical) &&
        (_overrides == other._overrides || listEquals(_resolved, other._resolved));
  }

  // Only what is stored directly: the overridable roles may compare equal
  // through different overrides.
  @override
  int get hashCode => Object.hash(
    brightness,
    tone,
    accent,
    canvas,
    surface,
    surfaceRaised,
    surfaceInset,
    surfaceMuted,
    surfaceTint,
    textPrimary,
    textSecondary,
    disabledText,
    line,
    hoverSurface,
    pressedSurface,
    threadLine,
    shadow,
    Object.hashAll(categorical),
  );

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
    Color? threadLine,
    Color? shadow,
    Color? textTertiary,
    Color? textQuaternary,
    Color? textSecondaryGlass,
    Color? textTertiaryGlass,
    Color? fillSubtle,
    Color? fill,
    Color? fillStrong,
    Color? separator,
    Color? positiveInk,
    Color? positiveTint,
    Color? cautionInk,
    Color? cautionTint,
    Color? negativeInk,
    Color? negativeTint,
    Color? infoInk,
    Color? infoTint,
    Color? onMediaScrim,
    Color? onMediaInk,
    Color? edgeHairline,
    Color? edgeHighlight,
    Color? mediaInnerStroke,
    List<BoxShadow>? shadowAmbient,
    List<BoxShadow>? shadowContact,
    List<Color>? categorical,
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
    threadLine: threadLine ?? this.threadLine,
    shadow: shadow ?? this.shadow,
    textTertiary: textTertiary ?? _overrides.textTertiary,
    textQuaternary: textQuaternary ?? _overrides.textQuaternary,
    textSecondaryGlass: textSecondaryGlass ?? _overrides.textSecondaryGlass,
    textTertiaryGlass: textTertiaryGlass ?? _overrides.textTertiaryGlass,
    fillSubtle: fillSubtle ?? _overrides.fillSubtle,
    fill: fill ?? _overrides.fill,
    fillStrong: fillStrong ?? _overrides.fillStrong,
    separator: separator ?? _overrides.separator,
    positiveInk: positiveInk ?? _overrides.positiveInk,
    positiveTint: positiveTint ?? _overrides.positiveTint,
    cautionInk: cautionInk ?? _overrides.cautionInk,
    cautionTint: cautionTint ?? _overrides.cautionTint,
    negativeInk: negativeInk ?? _overrides.negativeInk,
    negativeTint: negativeTint ?? _overrides.negativeTint,
    infoInk: infoInk ?? _overrides.infoInk,
    infoTint: infoTint ?? _overrides.infoTint,
    onMediaScrim: onMediaScrim ?? _overrides.onMediaScrim,
    onMediaInk: onMediaInk ?? _overrides.onMediaInk,
    edgeHairline: edgeHairline ?? _overrides.edgeHairline,
    edgeHighlight: edgeHighlight ?? _overrides.edgeHighlight,
    mediaInnerStroke: mediaInnerStroke ?? _overrides.mediaInnerStroke,
    shadowAmbient: shadowAmbient ?? _overrides.shadowAmbient,
    shadowContact: shadowContact ?? _overrides.shadowContact,
    categorical: categorical ?? this.categorical,
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
      threadLine: mix(threadLine, other.threadLine),
      shadow: mix(shadow, other.shadow),
      textTertiary: mix(textTertiary, other.textTertiary),
      textQuaternary: mix(textQuaternary, other.textQuaternary),
      textSecondaryGlass: mix(textSecondaryGlass, other.textSecondaryGlass),
      textTertiaryGlass: mix(textTertiaryGlass, other.textTertiaryGlass),
      fillSubtle: mix(fillSubtle, other.fillSubtle),
      fill: mix(fill, other.fill),
      fillStrong: mix(fillStrong, other.fillStrong),
      separator: mix(separator, other.separator),
      positiveInk: mix(positiveInk, other.positiveInk),
      positiveTint: mix(positiveTint, other.positiveTint),
      cautionInk: mix(cautionInk, other.cautionInk),
      cautionTint: mix(cautionTint, other.cautionTint),
      negativeInk: mix(negativeInk, other.negativeInk),
      negativeTint: mix(negativeTint, other.negativeTint),
      infoInk: mix(infoInk, other.infoInk),
      infoTint: mix(infoTint, other.infoTint),
      onMediaScrim: mix(onMediaScrim, other.onMediaScrim),
      onMediaInk: mix(onMediaInk, other.onMediaInk),
      edgeHairline: mix(edgeHairline, other.edgeHairline),
      edgeHighlight: mix(edgeHighlight, other.edgeHighlight),
      mediaInnerStroke: mix(mediaInnerStroke, other.mediaInnerStroke),
      shadowAmbient: BoxShadow.lerpList(shadowAmbient, other.shadowAmbient, t),
      shadowContact: BoxShadow.lerpList(shadowContact, other.shadowContact, t),
      categorical: categorical.length != other.categorical.length
          ? (t < .5 ? categorical : other.categorical)
          : List.generate(categorical.length, (i) => i < other.categorical.length ? mix(categorical[i], other.categorical[i]) : categorical[i]),
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
    this.categorical = _defaultCategorical,
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
  final List<Color> categorical;
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
    return base.copyWith(accent: accent, categorical: List.unmodifiable(categorical));
  }

  FrostPalettes copyWith({Color? lightDefaultAccent, Color? darkDefaultAccent, List<Color>? accentPresets, List<Color>? categorical}) {
    final light = lightDefaultAccent ?? this.lightDefaultAccent;
    final dark = darkDefaultAccent ?? this.darkDefaultAccent;
    return FrostPalettes(
      lightDefaultAccent: light,
      darkDefaultAccent: dark,
      accentPresets: accentPresets ?? this.accentPresets,
      categorical: categorical ?? this.categorical,
      lightNeutral: lightNeutral.copyWith(accent: light),
      lightCool: lightCool.copyWith(accent: light),
      lightWarm: lightWarm.copyWith(accent: light),
      darkNeutral: darkNeutral.copyWith(accent: dark),
      darkCool: darkCool.copyWith(accent: dark),
      darkWarm: darkWarm.copyWith(accent: dark),
    );
  }

  static const _pink = Color(0xFFF0729F);

  /// The standard palettes with the default pink accent.
  static const pink = FrostPalettes(
    lightDefaultAccent: _pink,
    darkDefaultAccent: _pink,
    accentPresets: [_pink, Color(0xFF4C8DFF), Color(0xFF00A68C), Color(0xFF9B7AF6), Color(0xFFC58A15), Color(0xFFE97640)],
    lightNeutral: FrostThemeTokens(
      brightness: Brightness.light,
      tone: FrostTone.neutral,
      accent: _pink,
      canvas: Color(0xFFEFEFF2),
      surface: Color(0xFFFFFFFF),
      surfaceRaised: Color(0xFFFFFFFF),
      surfaceInset: Color(0xFFF1F1F4),
      surfaceMuted: Color(0xFFF8F8FA),
      surfaceTint: Color(0xFFEFEFF2),
      textPrimary: Color(0xFF17181C),
      textSecondary: Color(0xA317181C),
      disabledText: Color(0x4017181C),
      line: Color(0xFFD6D6D6),
      hoverSurface: Color(0xFFF9F9F9),
      pressedSurface: Color(0xFFEBEBEC),
      threadLine: Color(0xFFBABABA),
      shadow: Color(0x10000000),
    ),
    lightCool: FrostThemeTokens(
      brightness: Brightness.light,
      tone: FrostTone.cool,
      accent: _pink,
      canvas: Color(0xFFE9F0F9),
      surface: Color(0xFFFFFFFF),
      surfaceRaised: Color(0xFFFFFFFF),
      surfaceInset: Color(0xFFEBF2FC),
      surfaceMuted: Color(0xFFF5F9FF),
      surfaceTint: Color(0xFFE9F0F9),
      textPrimary: Color(0xFF151B24),
      textSecondary: Color(0xA3151B24),
      disabledText: Color(0x40151B24),
      line: Color(0xFFD6DEE7),
      hoverSurface: Color(0xFFF9F9FA),
      pressedSurface: Color(0xFFEBECEC),
      threadLine: Color(0xFFAEBBC9),
      shadow: Color(0x10000000),
    ),
    lightWarm: FrostThemeTokens(
      brightness: Brightness.light,
      tone: FrostTone.warm,
      accent: _pink,
      canvas: Color(0xFFF5EFE5),
      surface: Color(0xFFFFFDFA),
      surfaceRaised: Color(0xFFFFFDFA),
      surfaceInset: Color(0xFFF7F0E6),
      surfaceMuted: Color(0xFFFDF8F0),
      surfaceTint: Color(0xFFF5EFE5),
      textPrimary: Color(0xFF1C1915),
      textSecondary: Color(0xA31C1915),
      disabledText: Color(0x401C1915),
      line: Color(0xFFD6D6CF),
      hoverSurface: Color(0xFFF9F7F4),
      pressedSurface: Color(0xFFECEAE7),
      threadLine: Color(0xFFBCBCB3),
      shadow: Color(0x10000000),
    ),
    darkNeutral: FrostThemeTokens(
      brightness: Brightness.dark,
      tone: FrostTone.neutral,
      accent: _pink,
      canvas: Color(0xFF141518),
      surface: Color(0xFF1B1C20),
      surfaceRaised: Color(0xFF24252A),
      surfaceInset: Color(0xFF16171B),
      surfaceMuted: Color(0xFF202126),
      surfaceTint: Color(0xFF2C2D33),
      textPrimary: Color(0xFFECECF0),
      textSecondary: Color(0xFFA3A4AC),
      disabledText: Color(0x40F1F2F4),
      line: Color(0xFF4A4D51),
      hoverSurface: Color(0xFF24252A),
      pressedSurface: Color(0xFF2C2D33),
      threadLine: Color(0xFF747A82),
      shadow: Color(0x52000000),
    ),
    darkCool: FrostThemeTokens(
      brightness: Brightness.dark,
      tone: FrostTone.cool,
      accent: _pink,
      // Match the neutral OKLCH L while retaining existing tone chroma/hue.
      canvas: Color(0xFF12151A),
      surface: Color(0xFF171D24),
      surfaceRaised: Color(0xFF1D2631),
      surfaceInset: Color(0xFF121720),
      surfaceMuted: Color(0xFF1B222C),
      surfaceTint: Color(0xFF252E3A),
      textPrimary: Color(0xFFE8EDF5),
      textSecondary: Color(0xFFA0A5AC),
      disabledText: Color(0x40EDF2FA),
      line: Color(0xFF465464),
      hoverSurface: Color(0xFF1F262E),
      pressedSurface: Color(0xFF282E35),
      threadLine: Color(0xFF70859B),
      shadow: Color(0x52000000),
    ),
    darkWarm: FrostThemeTokens(
      brightness: Brightness.dark,
      tone: FrostTone.warm,
      accent: _pink,
      canvas: Color(0xFF171412),
      surface: Color(0xFF201B17),
      surfaceRaised: Color(0xFF2B241C),
      surfaceInset: Color(0xFF1A1613),
      surfaceMuted: Color(0xFF262018),
      surfaceTint: Color(0xFF332C24),
      textPrimary: Color(0xFFF0ECE5),
      textSecondary: Color(0xFFA8A49E),
      disabledText: Color(0x40F5F1EA),
      line: Color(0xFF4F4F46),
      hoverSurface: Color(0xFF29241F),
      pressedSurface: Color(0xFF312C28),
      threadLine: Color(0xFF7B7B6D),
      shadow: Color(0x52000000),
    ),
  );
}

/// Window caption button colours, fixed across palettes and accents.
abstract final class FrostCaptionColors {
  static const closeHover = Color(0xFFE81123);
  static const closePressed = Color(0xFFC50F1F);
  static const onClose = Color(0xFFFFFFFF);
}
