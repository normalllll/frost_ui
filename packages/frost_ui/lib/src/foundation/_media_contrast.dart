import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'color_math.dart';
import 'tokens.dart';

// A small glyph shadow supports a shared video gradient without drawing a
// separate backing rectangle behind every icon or word.
const frostMediaInkShadows = [Shadow(color: Color(0x66000000), offset: Offset(0, 1), blurRadius: 3)];

// Match other foundation caches and retain eight-bit framebuffer precision.
const _contrastCacheLimit = 64;
const _contrastSearchSteps = 18;
const _mediaTextContrast = 4.5;
const _lightMediaScrimMinimum = .6;
// Dark media backgrounds must stay visually recessed, beyond the text-only
// contrast threshold. This does not change the window ambient host intensity.
const _darkMediaScrimMinimum = .88;
const _onMediaChromeMinimum = .5;
// A black scrim cannot separate a media band over black. Lift it with existing
// media ink so the full band remains visible, without a second surface/token.
const _mediaChromeInkLift = .08;
final _mediaScrims = <(Color, Color, Color, double), double>{};
final _lightnessScrims = <(Color, double, Color), double>{};

/// OKLab/OKLCH lightness, independent of hue and the sRGB gamma curve.
double frostBackdropLightness(Color color) {
  double linear(double c) => c <= .04045 ? c / 12.92 : math.pow((c + .055) / 1.055, 2.4).toDouble();
  final r = linear(color.r), g = linear(color.g), b = linear(color.b);
  final l = math.pow(.4122214708 * r + .5363325363 * g + .0514459929 * b, 1 / 3).toDouble();
  final m = math.pow(.2119034982 * r + .6806995451 * g + .1073969566 * b, 1 / 3).toDouble();
  final s = math.pow(.0883024619 * r + .2817188376 * g + .6299787005 * b, 1 / 3).toDouble();
  return .2104542553 * l + .793617785 * m - .0040720468 * s;
}

// Leave half of the existing canvas/surface separation for raised content.
// Interpolate perceptual L itself, rather than gamma-encoded RGB channels.
double frostBackdropLightnessLimit(FrostThemeTokens tokens) =>
    math.min((frostBackdropLightness(tokens.canvas) + frostBackdropLightness(tokens.surface)) / 2, frostBackdropLightness(tokens.surface) - .022);

Color frostMediaBackdropBase(FrostThemeTokens tokens) => tokens.isDark ? tokens.canvas : tokens.surface;

/// Keep decorative image light inside the existing surface hierarchy. Text
/// contrast alone still permits a large grey field in a dark window. Check
/// framebuffer quantization too, as a single RGB step matters near the canvas.
double frostLightnessScrimOpacity({required Color surface, required double maximumLightness, required Color worst}) {
  final key = (surface, maximumLightness, worst);
  if (_lightnessScrims[key] case final cached?) return cached;
  if (_lightnessScrims.length >= _contrastCacheLimit) _lightnessScrims.clear();
  final maximum = math.max(frostBackdropLightness(surface), maximumLightness);
  bool passes(double opacity) {
    final background = Color.alphaBlend(surface.withValues(alpha: opacity), worst);
    return frostBackdropLightness(background) <= maximum && frostBackdropLightness(Color(background.toARGB32())) <= maximum;
  }

  if (passes(0)) return _lightnessScrims[key] = 0;
  var low = 0.0, high = 1.0;
  for (var step = 0; step < _contrastSearchSteps; step++) {
    final mid = (low + high) / 2;
    if (passes(mid)) {
      high = mid;
    } else {
      low = mid;
    }
  }
  return _lightnessScrims[key] = high;
}

/// Shared by ambient surfaces and video controls. Cache the actual theme
/// colors, including intermediate tones, rather than solving in each build.
double frostContrastScrimOpacity({required Color surface, required Color ink, required Color worst, required double minimum}) {
  final key = (surface, ink, worst, minimum);
  if (_mediaScrims[key] case final cached?) return cached;
  if (_mediaScrims.length >= _contrastCacheLimit) _mediaScrims.clear();
  bool passes(double opacity) {
    final background = Color.alphaBlend(surface.withValues(alpha: opacity), worst);
    final foreground = Color.alphaBlend(ink, background);
    // Semantic inks may be translucent. Check the painted colour, including
    // framebuffer quantization, rather than the uncomposited primary RGB.
    return colorContrast(foreground, background) >= _mediaTextContrast &&
        colorContrast(Color(foreground.toARGB32()), Color(background.toARGB32())) >= _mediaTextContrast;
  }

  if (passes(minimum)) return _mediaScrims[key] = minimum;
  var low = minimum, high = 1.0;
  for (var step = 0; step < _contrastSearchSteps; step++) {
    final mid = (low + high) / 2;
    if (passes(mid)) {
      high = mid;
    } else {
      low = mid;
    }
  }
  return _mediaScrims[key] = high;
}

double frostMediaScrimOpacity(FrostThemeTokens tokens) {
  final base = frostMediaBackdropBase(tokens);
  final contrast = frostContrastScrimOpacity(
    surface: base,
    ink: tokens.textPrimary,
    worst: tokens.isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
    minimum: tokens.isDark ? _darkMediaScrimMinimum : _lightMediaScrimMinimum,
  );
  if (!tokens.isDark) return contrast;
  // Media surrounds belong to the canvas, below adjacent content surfaces.
  // The same bound applies to the blurred texture and reduced-transparency mean.
  return math.max(contrast, frostLightnessScrimOpacity(surface: base, maximumLightness: frostBackdropLightnessLimit(tokens), worst: const Color(0xFFFFFFFF)));
}

/// One readable media-control material, independent of the page brightness.
/// Respect the configured scrim alpha as a floor and solve over a white frame.
Color frostOnMediaChromeBase(FrostThemeTokens tokens) =>
    Color.alphaBlend(tokens.onMediaInk.withValues(alpha: _mediaChromeInkLift), tokens.onMediaScrim.withValues(alpha: 1));

double frostOnMediaChromeOpacity(FrostThemeTokens tokens) => frostContrastScrimOpacity(
  surface: frostOnMediaChromeBase(tokens),
  ink: tokens.onMediaInk,
  worst: const Color(0xFFFFFFFF),
  minimum: tokens.onMediaScrim.a.clamp(_onMediaChromeMinimum, 1.0),
);

Color frostOnMediaChromeColor(FrostThemeTokens tokens) => frostOnMediaChromeBase(tokens).withValues(alpha: frostOnMediaChromeOpacity(tokens));

/// The opacity at which [FrostThemeTokens.onMediaInk] stays readable over a
/// white frame on the [FrostThemeTokens.onMediaScrim] colour, never below
/// [minimum].
double frostOnMediaScrimOpacity(FrostThemeTokens tokens, {required double minimum}) => frostContrastScrimOpacity(
  surface: tokens.onMediaScrim.withValues(alpha: 1),
  ink: tokens.onMediaInk,
  worst: const Color(0xFFFFFFFF),
  minimum: minimum,
);
