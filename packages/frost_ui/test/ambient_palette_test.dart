import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/foundation/_ambient_material.dart';
import 'package:frost_ui/src/foundation/_media_contrast.dart';
import 'package:frost_ui/src/foundation/color_math.dart' show colorContrast;

FrostAmbientSample image(int width, int height, Color Function(int x, int y) pixel) => FrostAmbientSample(width, height, [
  for (var y = 0; y < height; y++)
    for (var x = 0; x < width; x++) pixel(x, y),
]);

final samples = <String, FrostAmbientSample>{
  'white': image(16, 10, (_, _) => Colors.white),
  'black': image(16, 10, (_, _) => Colors.black),
  'red': image(16, 10, (_, _) => const Color(0xFFFF1A1A)),
  'two': image(16, 10, (x, _) => x < 8 ? const Color(0xFFE53935) : const Color(0xFF1E88E5)),
  'rainbow': image(48, 30, (x, _) => HSVColor.fromAHSV(1, (x ~/ 4 % 12) * 30.0, 1, 1).toColor()),
  'gray': image(16, 10, (x, y) => Color.from(alpha: 1, red: x / 15, green: x / 15, blue: x / 15)),
  'split': image(16, 10, (_, y) => y < 5 ? const Color(0xFFF6F2EA) : const Color(0xFF0C0C0C)),
};

(double, double, double) lab(Color c) {
  double linear(double v) => v <= .04045 ? v / 12.92 : math.pow((v + .055) / 1.055, 2.4).toDouble();
  final r = linear(c.r), g = linear(c.g), b = linear(c.b);
  final l = math.pow(.4122214708 * r + .5363325363 * g + .0514459929 * b, 1 / 3);
  final m = math.pow(.2119034982 * r + .6806995451 * g + .1073969566 * b, 1 / 3);
  final s = math.pow(.0883024619 * r + .2817188376 * g + .6299787005 * b, 1 / 3);
  return (
    .2104542553 * l + .793617785 * m - .0040720468 * s,
    1.9779984951 * l - 2.428592205 * m + .4505937099 * s,
    .0259040371 * l + .7827717662 * m - .808675766 * s,
  );
}

double chroma(Color c) {
  final (_, a, b) = lab(c);
  return math.sqrt(a * a + b * b);
}

double hue(Color c) {
  final (_, a, b) = lab(c);
  return (math.atan2(b, a) * 180 / math.pi + 360) % 360;
}

double hueSpread(Iterable<Color> colors, {double floor = .02}) {
  final hues = [
    for (final c in colors)
      if (chroma(c) >= floor) hue(c),
  ];
  var spread = 0.0;
  for (final a in hues) {
    for (final b in hues) {
      final d = (a - b).abs();
      spread = math.max(spread, math.min(d, 360 - d));
    }
  }
  return spread;
}

void main() => _cases();

void _cases() {
  test('two colour halves give two entries at their centroids', () {
    final palette = samples['two']!.palette;
    expect(palette, hasLength(2));
    final red = palette.firstWhere((e) => e.color.r > e.color.b);
    final blue = palette.firstWhere((e) => e.color.b > e.color.r);
    expect(red.centroid.dx, closeTo(.25, .01));
    expect(blue.centroid.dx, closeTo(.75, .01));
    expect(red.centroid.dy, closeTo(.5, .01));
    expect(red.weight, closeTo(.3, .01));
    expect(blue.weight, closeTo(.3, .01));
  });

  test('grayscale gives neutral entries that keep the theme tint', () {
    final palette = samples['gray']!.palette;
    expect(palette, isNotEmpty);
    for (final entry in palette) {
      expect(chroma(entry.color), lessThan(.02));
    }
    for (final tokens in [FrostPalettes.pink.darkNeutral, FrostPalettes.pink.lightNeutral]) {
      for (final entry in samples['gray']!.toned(tokens).palette) {
        expect(chroma(entry.color), lessThanOrEqualTo(chroma(tokens.canvas) + .004));
      }
    }
  });

  test('palette is deterministic and cached with the sample', () {
    for (final name in samples.keys) {
      final first = samples[name]!;
      final again = FrostAmbientSample(first.width, first.height, List.of(first.pixels));
      expect(identical(first.palette, first.palette), true);
      expect([for (final e in again.palette) (e.color, e.weight, e.centroid)], [for (final e in first.palette) (e.color, e.weight, e.centroid)]);
    }
    final transparent = FrostAmbientSample(4, 4, List.filled(16, const Color(0x00000000)));
    expect(transparent.palette, isEmpty);
  });

  test('every final colour is readable and inside the lightness bounds', () {
    for (final brightness in Brightness.values) {
      for (final tone in FrostTone.values) {
        final tokens = FrostPalettes.pink.palette(brightness, tone, const Color(0xFFFC619D));
        for (final entry in samples.entries) {
          final toned = entry.value.toned(tokens);
          for (final color in [...toned.palette.map((e) => e.color), toned.solid]) {
            final reason = '$brightness $tone ${entry.key} $color';
            for (final ink in [tokens.textSecondary, tokens.textPrimary]) {
              final painted = Color.alphaBlend(ink, color);
              expect(colorContrast(painted, color), greaterThanOrEqualTo(4.5), reason: reason);
              expect(colorContrast(Color(painted.toARGB32()), Color(color.toARGB32())), greaterThanOrEqualTo(4.5), reason: reason);
            }
            final lightness = frostBackdropLightness(Color(color.toARGB32()));
            if (tokens.isDark) {
              expect(lightness, lessThanOrEqualTo(frostBackdropLightnessLimit(tokens)), reason: reason);
            } else {
              expect(lightness, lessThanOrEqualTo(frostBackdropLightness(tokens.surface) - .02), reason: reason);
            }
          }
          // Dark: the most luminous endpoint. Light: their channel minimum.
          final background = entry.value.resolvePalette(tokens, 1).background;
          final painted = tokens.isDark ? frostAmbientGlowPeaks(tokens, entry.value.palette, free: true) : toned.palette.map((e) => e.color);
          for (final color in [tokens.canvas, ...painted]) {
            if (tokens.isDark) {
              expect(background.computeLuminance(), greaterThanOrEqualTo(color.computeLuminance()), reason: '${entry.key} $color');
            } else {
              for (final (worst, channel) in [(background.r, color.r), (background.g, color.g), (background.b, color.b)]) {
                expect(worst, lessThanOrEqualTo(channel), reason: '${entry.key} $color');
              }
            }
          }
          for (final ink in [tokens.textSecondary, tokens.textPrimary]) {
            if (tokens.isDark || toned.palette.length == 1) {
              expect(colorContrast(Color.alphaBlend(ink, background), background), greaterThanOrEqualTo(4.5), reason: entry.key);
            }
          }
        }
      }
    }
  });

  test('rainbow and two colour images keep their hue spread', () {
    for (final brightness in Brightness.values) {
      for (final tone in FrostTone.values) {
        final tokens = FrostPalettes.pink.palette(brightness, tone, const Color(0xFFFC619D));
        for (final name in ['rainbow', 'two']) {
          final colors = samples[name]!.toned(tokens).palette.map((e) => e.color);
          expect(hueSpread(colors, floor: .01), greaterThanOrEqualTo(60), reason: '$brightness $tone $name');
        }
      }
    }
  });

  test('palette material keeps the cached bucket semantics', () {
    final sample = samples['two']!;
    final tokens = FrostPalettes.pink.darkNeutral;
    final first = sample.resolvePalette(tokens, .51);
    expect(identical(first, sample.resolvePalette(tokens.copyWith(), .54)), true);
    expect(sample.resolvePalette(tokens, 0).background, tokens.canvas);
    expect(first.palette, hasLength(2));
  });

  test('multi-colour art keeps chromatic picks at least 30° apart', () {
    final clash = image(16, 10, (x, _) => x < 8 ? const Color(0xFF7A00FF) : const Color(0xFFFF7A00));
    final diagonal = image(16, 16, (x, y) => x > y ? const Color(0xFFFF0010) : const Color(0xFF0040FF));
    for (final sample in [samples['rainbow']!, samples['two']!, clash, diagonal]) {
      final hues = [for (final e in sample.palette) hue(e.color)];
      expect(hues.length, inInclusiveRange(2, 3));
      for (var i = 0; i < hues.length; i++) {
        for (var j = i + 1; j < hues.length; j++) {
          final d = (hues[i] - hues[j]).abs();
          expect(math.min(d, 360 - d), greaterThanOrEqualTo(30));
        }
      }
      expect(sample.palette.fold(0.0, (sum, e) => sum + e.weight), closeTo(.6, 1e-9), reason: '40% stays neutral canvas');
    }
    expect(samples['rainbow']!.palette, hasLength(3));
  });

  test('monochrome art gains two analogous stops at ±30° and 0.6× chroma', () {
    final palette = samples['red']!.palette;
    expect(palette, hasLength(3));
    final main = palette.first;
    for (final stop in palette.skip(1)) {
      final d = (hue(stop.color) - hue(main.color) + 540) % 360 - 180;
      expect(d.abs(), closeTo(30, 2));
      expect(chroma(stop.color), lessThanOrEqualTo(chroma(main.color) * .6 + .002));
      expect(stop.weight, closeTo(main.weight / 2, 1e-9));
    }
  });

  test('chroma is compressed below the ceiling', () {
    for (final tokens in [FrostPalettes.pink.darkNeutral, FrostPalettes.pink.lightNeutral]) {
      final ceiling = tokens.isDark ? .040 : .045;
      for (final c in [const Color(0xFF7A00FF), const Color(0xFF0040FF), const Color(0xFFFF0010), const Color(0xFF00FFF0)]) {
        expect(chroma(frostAmbientTone(tokens, c)), lessThanOrEqualTo(ceiling + .002));
      }
    }
  });

  test('no-image mesh stops stay readable, bounded and near-neutral', () {
    for (final brightness in Brightness.values) {
      for (final tone in FrostTone.values) {
        final tokens = FrostPalettes.pink.palette(brightness, tone, const Color(0xFFFC619D));
        final canvasL = frostBackdropLightness(tokens.canvas);
        for (final stop in frostAmbientMeshStops(tokens)) {
          final reason = '$brightness $tone $stop';
          for (final ink in [tokens.textSecondary, tokens.textPrimary]) {
            expect(colorContrast(Color.alphaBlend(ink, stop), stop), greaterThanOrEqualTo(4.5), reason: reason);
          }
          final l = frostBackdropLightness(Color(stop.toARGB32()));
          if (tokens.isDark) {
            expect(l, inInclusiveRange(canvasL - .005, math.min(canvasL + .012, frostBackdropLightnessLimit(tokens)) + .002), reason: reason);
            expect(chroma(stop), lessThanOrEqualTo(.014), reason: reason);
          } else {
            expect(l, inInclusiveRange(canvasL - .022, canvasL + .002), reason: reason);
            expect(chroma(stop), lessThanOrEqualTo(.017), reason: reason);
          }
        }
      }
    }
  });

  _glows();
  _glowField();
}

void _glows() {
  final tokens = FrostPalettes.pink.darkNeutral;
  Color pixel(Uint8List bytes, int width, int x, int y) {
    final at = (y * width + x) * 4;
    return Color.fromARGB(255, bytes[at], bytes[at + 1], bytes[at + 2]);
  }

  ({Uint8List bytes, FrostAmbientGlowBake bake}) field(List<Color> colours, List<Offset> centres) {
    final raw = [for (var i = 0; i < colours.length; i++) FrostAmbientPaletteEntry(colours[i], .3, const Offset(.5, .5))];
    final model = frostAmbientGlows(tokens, raw);
    final bake = frostAmbientGlowBakeFor(tokens, model, centres, const Size(240, 120), 150, 1);
    return (bytes: frostAmbientBakeGlowField(bake), bake: bake);
  }

  test('overlapping glows blend without jumps and stay under the peak', () {
    final (:bytes, :bake) = field([const Color(0xFFFF0010), const Color(0xFF0040FF)], [const Offset(70, 60), const Offset(170, 60)]);
    final peak = frostBackdropLightness(tokens.surface) - .02;
    double deltaE(Color a, Color b) {
      final (la, aa, ba) = lab(a);
      final (lb, ab, bb) = lab(b);
      return math.sqrt(math.pow(la - lb, 2) + math.pow(aa - ab, 2) + math.pow(ba - bb, 2));
    }

    for (var x = 1; x < bake.width; x++) {
      expect(deltaE(pixel(bytes, bake.width, x - 1, 60), pixel(bytes, bake.width, x, 60)), lessThanOrEqualTo(.01), reason: 'x=$x');
    }
    for (var y = 0; y < bake.height; y += 3) {
      for (var x = 0; x < bake.width; x += 3) {
        final c = pixel(bytes, bake.width, x, y);
        final (l, a, b) = lab(c);
        expect(l, lessThanOrEqualTo(peak + .005), reason: '($x, $y)');
        for (final ink in [tokens.textSecondary, tokens.textPrimary]) {
          expect(colorContrast(Color.alphaBlend(ink, c), c), greaterThanOrEqualTo(4.5));
        }
        // Never beyond r · Cgamut (8-bit and dither tolerance).
        final hue = math.atan2(b, a);
        expect(math.sqrt(a * a + b * b), lessThanOrEqualTo(frostAmbientGlowRatio * frostAmbientTestGamut(l, hue) + .006), reason: '($x, $y)');
      }
    }
  });

  test('is exactly the canvas beyond the reach', () {
    final (:bytes, :bake) = field([const Color(0xFF7A00FF)], [const Offset(20, 20)]);
    expect(pixel(bytes, bake.width, 239, 119).toARGB32(), Color(tokens.canvas.toARGB32()).toARGB32());
  });

  test('warm hues are neutral below a lift ratio of 0.45', () {
    final (:bytes, :bake) = field([const Color(0xFFFF7A00)], [const Offset(0, 60)]);
    final canvas = lab(tokens.canvas);
    // f(t) < .45 beyond t ≈ .54 of the 150 px radius.
    for (var x = 90; x < 145; x += 4) {
      final (_, a, b) = lab(pixel(bytes, bake.width, x, 60));
      expect(math.sqrt(math.pow(a - canvas.$2, 2) + math.pow(b - canvas.$3, 2)), lessThanOrEqualTo(.005), reason: 'x=$x');
    }
    // Near the centre the amber light is clearly coloured.
    final (_, a, b) = lab(pixel(bytes, bake.width, 4, 60));
    expect(math.sqrt(math.pow(a - canvas.$2, 2) + math.pow(b - canvas.$3, 2)), greaterThan(.012));
  });

  test('hue zones move pure violet, blue and yellow out of their cores', () {
    final cores = frostAmbientHueZoneCores;
    for (final colour in [const Color(0xFF8000FF), const Color(0xFF0000FF), const Color(0xFFFFE000), const Color(0xFFFFFF00)]) {
      for (final palette in [FrostPalettes.pink.darkNeutral, FrostPalettes.pink.lightNeutral]) {
        final model = frostAmbientGlows(palette, [FrostAmbientPaletteEntry(colour, 1, const Offset(.5, .5))]);
        final h = (model.glows.single.hue * 180 / math.pi + 360) % 360;
        for (final (start, end) in cores) {
          expect(h >= start && h <= end, false, reason: '$colour → $h° in core $start–$end');
        }
        final toned = frostAmbientTone(palette, colour);
        final th = hue(toned);
        for (final (start, end) in cores) {
          expect(th >= start + 1 && th <= end - 1, false, reason: 'tone $colour → $th°');
        }
      }
    }
  });

  test('detail and window peaks keep the lightness gap', () {
    final peaks = frostAmbientGlowPeaks(tokens, [
      const FrostAmbientPaletteEntry(Color(0xFFFFFFFF), 1, Offset(.5, .5)),
      const FrostAmbientPaletteEntry(Color(0xFF00D040), 1, Offset(.5, .5)),
    ]);
    for (final p in peaks) {
      expect(frostBackdropLightness(tokens.surface) - frostBackdropLightness(Color(p.toARGB32())), greaterThanOrEqualTo(.02 - .002));
    }
  });
}

void _glowField() {
  test('hue turns gradually across the baked field', () {
    const stops = [Color(0xff142463), Color(0xff5b3a9e), Color(0xffc8507a), Color(0xfff27a3c), Color(0xffffc46b), Color(0xff1f7a86), Color(0xff0b3440)];
    final scenes = {
      'photo': image(48, 30, (x, y) => stops[(y * stops.length) ~/ 30]),
      'clash': image(48, 30, (x, _) => x < 24 ? const Color(0xff7a00ff) : const Color(0xffff7a00)),
      'diagonal': image(48, 30, (x, y) => x * 30 > y * 48 ? const Color(0xffff0010) : const Color(0xff0040ff)),
    };
    final tokens = FrostPalettes.pink.darkNeutral;
    final canvas = lab(tokens.canvas);
    for (final entry in scenes.entries) {
      final model = frostAmbientGlows(tokens, entry.value.palette);
      const size = Size(600, 410);
      final centres = frostAmbientWindowGlowCentres(model.glows, Size(entry.value.width.toDouble(), entry.value.height.toDouble()), Offset.zero & size);
      final radius = frostAmbientGlowWindowReach * math.sqrt(size.width * size.width + size.height * size.height);
      final bake = frostAmbientGlowBakeFor(tokens, model, centres, size, radius, 1);
      final field = Float32List(bake.width * bake.height * 3);
      frostAmbientBakeGlowField(bake, field);
      (double, double, double) at((int, int) p) {
        final o = (p.$2 * bake.width + p.$1) * 3;
        return (field[o].toDouble(), field[o + 1].toDouble(), field[o + 2].toDouble());
      }

      final lines = <List<(int, int)>>[
        for (var k = 1; k < 6; k++) [for (var x = 0; x < bake.width; x++) (x, bake.height * k ~/ 6)],
        for (var k = 1; k < 6; k++) [for (var y = 0; y < bake.height; y++) (bake.width * k ~/ 6, y)],
        for (var k = -2; k <= 2; k++)
          [
            for (var y = 0; y < bake.height; y++)
              if ((y * bake.width / bake.height).round() + k * 40 case final x when x >= 0 && x < bake.width) (x, y),
          ],
      ];
      final step = math.max(1, (math.sqrt(bake.width * bake.width + bake.height * bake.height) * .01).round());
      for (final line in lines) {
        for (var i = 1; i < line.length; i++) {
          final p = at(line[i - 1]), q = at(line[i]);
          final e = math.sqrt(math.pow(p.$1 - q.$1, 2) + math.pow(p.$2 - q.$2, 2) + math.pow(p.$3 - q.$3, 2));
          expect(e, lessThanOrEqualTo(.004), reason: '${entry.key} ${line[i]}');
        }
        // Where the tint is visible, its direction turns at most 9° per 1%
        // of the diagonal: no hue edge.
        for (var i = step; i < line.length; i++) {
          final p = at(line[i - step]), q = at(line[i]);
          final cp = math.sqrt(math.pow(p.$2 - canvas.$2, 2) + math.pow(p.$3 - canvas.$3, 2));
          final cq = math.sqrt(math.pow(q.$2 - canvas.$2, 2) + math.pow(q.$3 - canvas.$3, 2));
          if (cp < .006 || cq < .006) continue;
          final hp = math.atan2(p.$3 - canvas.$3, p.$2 - canvas.$2), hq = math.atan2(q.$3 - canvas.$3, q.$2 - canvas.$2);
          expect((((hq - hp) * 180 / math.pi + 540) % 360 - 180).abs(), lessThanOrEqualTo(9), reason: '${entry.key} ${line[i]}');
        }
      }
    }
  });
}
