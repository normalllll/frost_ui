import 'package:flutter/widgets.dart';


/// A palette check chooses between white and the palette's light-mode ink.
Color swatchCheckInk(Color fill, Color darkInk) => colorContrast(fill, Color(0xFFFFFFFF)) >= colorContrast(fill, darkInk) ? Color(0xFFFFFFFF) : darkInk;

double colorContrast(Color first, Color second) {
  final a = first.computeLuminance();
  final b = second.computeLuminance();
  return (a > b ? a + .05 : b + .05) / (a > b ? b + .05 : a + .05);
}

/// White foreground for raw accent graphics. Text actions use actionFill,
/// whose tone is resolved separately to preserve ordinary-text contrast.
Color readableOnAccent(Color accent) => solidLabelTone(accent);

/// Returns [accent] or the nearest tone of the same hue and saturation that
/// reaches [minimum] contrast on [background]. Lightness moves away from the
/// background, so pink stays pink instead of being mixed with black or white.
Color readableAccentTone(Color accent, Color background, double minimum) {
  final key = (accent.toARGB32(), background.toARGB32(), minimum);
  if (_readableToneCache[key] case final cached?) return cached;
  if (_readableToneCache.length > 64) _readableToneCache.clear();
  return _readableToneCache[key] = _searchReadableTone(accent, background, minimum);
}

// Theme getters resolve these tones during build; palettes are few and fixed.
final _readableToneCache = <(int, int, double), Color>{};

Color _searchReadableTone(Color accent, Color background, double minimum) {
  if (colorContrast(accent, background) >= minimum) return accent;
  final hsl = HSLColor.fromColor(accent);
  final darken = background.computeLuminance() > .18;
  var low = darken ? 0.0 : hsl.lightness;
  var high = darken ? hsl.lightness : 1.0;
  // The extreme end (near black or near white) always passes on the neutral
  // palette surfaces; search the tone closest to the original that passes.
  for (var i = 0; i < 18; i++) {
    final middle = (low + high) / 2;
    final passes = colorContrast(Color(hsl.withLightness(middle).toColor().toARGB32()), background) >= minimum;
    if (darken == passes) {
      low = middle;
    } else {
      high = middle;
    }
  }
  return Color(hsl.withLightness(darken ? low : high).toColor().toARGB32()).withValues(alpha: accent.a);
}

/// Product rule: always white, including custom accents and destructive fills.
Color solidLabelTone(Color fill) => Color(0xFFFFFFFF);

/// Hover and press deepen the original fill without recolouring it at rest.
Color solidWashColor(Color fill) => Color(0xFF000000);

/// Feedback retains its requested strength on the already-resolved fill.
double solidOverlayAlpha(Color fill, double requested) => requested;
