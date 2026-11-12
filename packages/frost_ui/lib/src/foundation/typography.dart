import 'package:flutter/material.dart' show Theme, ThemeExtension;
import 'package:flutter/widgets.dart';

import '_missing_theme.dart';

/// Semantic text hierarchy; desktop and touch platform defaults stay stable
/// across window widths. Text metrics never follow control density.
enum FrostTextRole { hero, value, title1, title2, headline, body, callout, subheadline, footnote, caption }

@immutable
class FrostTypography extends ThemeExtension<FrostTypography> {
  const FrostTypography._(this._styles, this._monospace, this._numeric);

  factory FrostTypography({required TargetPlatform platform, TextStyle base = const TextStyle(), String? monospace, String? numeric}) {
    final wide = switch (platform) {
      TargetPlatform.windows || TargetPlatform.macOS || TargetPlatform.linux => true,
      _ => false,
    };
    // Roles describe type metrics only; each component owns its foreground.
    // Construct an allow-list because copyWith(null) cannot clear paint fields.
    final fontBase = TextStyle(
      inherit: true,
      fontFamily: base.fontFamily,
      fontFamilyFallback: base.fontFamilyFallback,
      fontStyle: base.fontStyle,
      fontFeatures: base.fontFeatures,
      fontVariations: base.fontVariations,
      wordSpacing: base.wordSpacing,
      textBaseline: base.textBaseline,
      locale: base.locale,
      leadingDistribution: base.leadingDistribution,
    );
    return FrostTypography._(
      Map.unmodifiable({
        FrostTextRole.hero: fontBase.copyWith(fontSize: wide ? 48 : 40, fontWeight: FontWeight.w300, height: 1.1, letterSpacing: 0),
        FrostTextRole.value: fontBase.copyWith(fontSize: 28, fontWeight: FontWeight.w400, height: 1.15, letterSpacing: 0),
        FrostTextRole.title1: fontBase.copyWith(fontSize: wide ? 24 : 28, fontWeight: FontWeight.w600, height: 1.25, letterSpacing: 0),
        FrostTextRole.title2: fontBase.copyWith(fontSize: 18, fontWeight: FontWeight.w600, height: 1.4, letterSpacing: 0),
        FrostTextRole.headline: fontBase.copyWith(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4, letterSpacing: 0),
        FrostTextRole.body: fontBase.copyWith(fontSize: 13, fontWeight: FontWeight.w400, height: 1.45, letterSpacing: 0),
        FrostTextRole.callout: fontBase.copyWith(fontSize: 14, fontWeight: FontWeight.w500, height: 1.4, letterSpacing: 0),
        FrostTextRole.subheadline: fontBase.copyWith(fontSize: 13.5, fontWeight: FontWeight.w500, height: 1.45, letterSpacing: 0),
        FrostTextRole.footnote: fontBase.copyWith(fontSize: 12, fontWeight: FontWeight.w400, height: 1.45, letterSpacing: 0),
        FrostTextRole.caption: fontBase.copyWith(fontSize: 11.5, fontWeight: FontWeight.w500, height: 1.45, letterSpacing: 0),
      }),
      TextStyle(
        fontFamily:
            monospace ??
            switch (platform) {
              TargetPlatform.windows => 'Consolas',
              TargetPlatform.macOS || TargetPlatform.iOS => 'Menlo',
              _ => 'monospace',
            },
        fontFamilyFallback: [?base.fontFamily, ...?base.fontFamilyFallback],
      ),
      numeric == null ? null : TextStyle(fontFamily: numeric, fontFamilyFallback: [?base.fontFamily, ...?base.fontFamilyFallback]),
    );
  }

  final Map<FrostTextRole, TextStyle> _styles;
  final TextStyle _monospace;
  final TextStyle? _numeric;

  /// Numeric selects the App numeric family; tabular keeps body-font figures stable.
  TextStyle style(FrostTextRole role, {bool numeric = false, bool tabular = false, bool monospace = false}) {
    final font = monospace
        ? _monospace
        : numeric
        ? _numeric
        : null;
    final result = font == null ? _styles[role]! : _styles[role]!.copyWith(fontFamily: font.fontFamily, fontFamilyFallback: font.fontFamilyFallback);
    return numeric || tabular ? result.copyWith(fontFeatures: [...?result.fontFeatures, const FontFeature.tabularFigures()]) : result;
  }

  static FrostTypography of(BuildContext context) {
    final typography = Theme.of(context).extension<FrostTypography>();
    if (typography == null) throw frostMissingThemeError('FrostTypography');
    return typography;
  }

  @override
  FrostTypography copyWith() => this;

  @override
  FrostTypography lerp(covariant FrostTypography? other, double t) => other == null
      ? this
      : FrostTypography._(
          Map.unmodifiable({for (final role in FrostTextRole.values) role: TextStyle.lerp(style(role), other.style(role), t)!}),
          TextStyle.lerp(_monospace, other._monospace, t)!,
          TextStyle.lerp(_numeric, other._numeric, t),
        );
}
