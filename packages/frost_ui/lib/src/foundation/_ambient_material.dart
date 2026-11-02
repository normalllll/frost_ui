import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '_media_contrast.dart';
import 'tokens.dart';

/// Intensity is resolved in these steps, so a slider reuses cached materials.
const frostAmbientIntensityStep = .05;
const _ambientMaterialCacheCapacity = 128;

/// Immutable pixels owned alongside the cached pre-blurred image.
class FrostAmbientSample {
  FrostAmbientSample(this.width, this.height, this.pixels);
  final int width, height;
  final List<Color> pixels;
  final _materials = <Object, FrostAmbientMaterials>{};
  final _toned = <Object, ({List<FrostAmbientPaletteEntry> palette, Color solid})>{};
  int resolutions = 0;

  /// The dominant colours, computed once per sample: up to three scored,
  /// hue-separated chromatic colours (analogous stops for monochrome art).
  late final List<FrostAmbientPaletteEntry> palette = frostAmbientScoredPalette(frostAmbientCandidates(width, height, pixels));

  /// [palette] mapped into the theme's backdrop range, with the reduced
  /// transparency fill (their weighted mean). Cached per theme.
  ({List<FrostAmbientPaletteEntry> palette, Color solid}) toned(FrostThemeTokens tokens) {
    final key = (tokens.brightness, tokens.tone, tokens.canvas, tokens.surface, tokens.textPrimary, tokens.textSecondary, tokens.accent);
    if (_toned[key] case final cached?) return cached;
    if (_toned.length >= _ambientMaterialCacheCapacity) _toned.clear();
    final entries = [for (final entry in palette) FrostAmbientPaletteEntry(frostAmbientTone(tokens, entry.color), entry.weight, entry.centroid)];
    var r = 0.0, g = 0.0, b = 0.0, total = 0.0;
    for (final entry in entries) {
      r += entry.color.r * entry.weight;
      g += entry.color.g * entry.weight;
      b += entry.color.b * entry.weight;
      total += entry.weight;
    }
    final mean = total == 0 ? tokens.canvas : Color.from(alpha: 1, red: r / total, green: g / total, blue: b / total);
    // The channel mean is a convex mix, but its OKLab L is re-checked.
    return _toned[key] = (palette: entries, solid: total == 0 ? mean : _enforce(tokens, _OkLab.of(mean)));
  }

  /// The palette material; plain canvas when the sample has no usable colour
  /// (transparent artwork).
  FrostAmbientMaterials resolve(FrostThemeTokens tokens, double intensity) =>
      palette.isNotEmpty ? resolvePalette(tokens, intensity) : FrostAmbientMaterials(background: tokens.canvas);

  /// Palette material. Light: gradients only mix canvas with tone-mapped
  /// colours at the bucket's upper intensity or less, overlaps included, and
  /// the channel minimum of the endpoints bounds the slight gamma-space dip.
  /// Dark: the window glows' card-free peaks are its brightest pixels.
  /// Positions do not matter.
  FrostAmbientMaterials resolvePalette(FrostThemeTokens tokens, double intensity) {
    final bucket = (intensity / frostAmbientIntensityStep).ceil().clamp(0, 20);
    final key = (tokens.brightness, tokens.tone, tokens.canvas, tokens.surface, tokens.textPrimary, tokens.textSecondary, tokens.accent, bucket);
    if (_materials[key] case final cached?) return cached;
    if (_materials.length >= _ambientMaterialCacheCapacity) _materials.clear();
    resolutions++;
    final toned = this.toned(tokens);
    final strength = bucket * frostAmbientIntensityStep;
    final peaks = tokens.isDark ? frostAmbientGlowPeaks(tokens, palette, free: true) : [for (final entry in toned.palette) entry.color];
    final endpoints = [tokens.canvas, for (final peak in peaks) Color.lerp(tokens.canvas, peak, strength)!];
    final background = tokens.isDark ? endpoints.reduce((a, b) => b.computeLuminance() > a.computeLuminance() ? b : a) : _channelBound(endpoints, false);
    return _materials[key] = FrostAmbientMaterials(
      background: background,
      palette: toned.palette,
      solid: toned.solid,
      raw: palette,
      sourceSize: Size(width.toDouble(), height.toDouble()),
    );
  }
}

Color _channelBound(Iterable<Color> colors, bool brightest) {
  var r = brightest ? 0.0 : 1.0, g = r, b = r;
  for (final color in colors) {
    r = brightest ? math.max(r, color.r) : math.min(r, color.r);
    g = brightest ? math.max(g, color.g) : math.min(g, color.g);
    b = brightest ? math.max(b, color.b) : math.min(b, color.b);
  }
  return Color.from(alpha: 1, red: r, green: g, blue: b);
}

class FrostAmbientMaterials {
  const FrostAmbientMaterials({required this.background, this.palette = const [], this.raw = const [], this.solid, this.sourceSize = Size.zero});

  /// The untoned picks, from which the dark glows are built.
  final List<FrostAmbientPaletteEntry> raw;

  /// Worst painted background, for readable fills above the backdrop.
  final Color background;

  /// Tone-mapped image colours, heaviest first; empty without usable colour.
  final List<FrostAmbientPaletteEntry> palette;

  /// Reduced-transparency fill at full intensity.
  final Color? solid;

  /// Sample size whose cover fit maps palette centroids into the window.
  final Size sourceSize;
}

/// One dominant colour with its share of all pixels and its pixel centroid
/// (normalised image x and y).
class FrostAmbientPaletteEntry {
  const FrostAmbientPaletteEntry(this.color, this.weight, this.centroid);
  final Color color;
  final double weight;
  final Offset centroid;
}

/// Up to eight clusters, so small vivid regions can still be scored.
const _candidateSize = 8;

/// Clusters under 2% of the pixels are noise, not a colour of the art.
const _candidateMinimumWeight = .02;
const _clusterIterations = 12;

/// Clusters closer than ΔE 0.06 read as one colour and are merged.
const _clusterMergeDistance = .06;

/// Below this OKLab chroma a colour is neutral and keeps the canvas tint.
const _neutralChroma = .02;

/// Up to three colours; more turns the backdrop into a patchwork.
const _pickCount = 3;

/// Chromatic picks share 60% of the frame; the rest stays neutral canvas.
const _chromaticShare = .6;

/// Picks below this chroma read as grey and are scored down.
const _nearNeutralChroma = .04;

/// Compressive chroma ceilings, C' = Cmax · tanh(C / Cmax): enough colour
/// to read as the art's, low enough to stay a backdrop.
const _darkChromaCeiling = .040, _lightChromaCeiling = .045;

/// One 8-bit step of gradient dither in dark (the glows carry no grain); in
/// light the dither plus the grain, which only darkens, by up to two steps.
const _darkNoiseSteps = 1, _lightNoiseSteps = 3;

double _tanh(double x) {
  final e = math.exp(2 * x);
  return (e - 1) / (e + 1);
}

class _OkLab {
  const _OkLab(this.l, this.a, this.b);
  factory _OkLab.of(Color color) {
    double linear(double c) => c <= .04045 ? c / 12.92 : math.pow((c + .055) / 1.055, 2.4).toDouble();
    final r = linear(color.r), g = linear(color.g), b = linear(color.b);
    final l = math.pow(.4122214708 * r + .5363325363 * g + .0514459929 * b, 1 / 3).toDouble();
    final m = math.pow(.2119034982 * r + .6806995451 * g + .1073969566 * b, 1 / 3).toDouble();
    final s = math.pow(.0883024619 * r + .2817188376 * g + .6299787005 * b, 1 / 3).toDouble();
    return _OkLab(
      .2104542553 * l + .793617785 * m - .0040720468 * s,
      1.9779984951 * l - 2.428592205 * m + .4505937099 * s,
      .0259040371 * l + .7827717662 * m - .808675766 * s,
    );
  }
  factory _OkLab.polar(double l, double chroma, double hue) => _OkLab(l, chroma * math.cos(hue), chroma * math.sin(hue));

  final double l, a, b;
  double get chroma => math.sqrt(a * a + b * b);
  double get hue => math.atan2(b, a);
  double distance(_OkLab other) => math.sqrt(math.pow(l - other.l, 2) + math.pow(a - other.a, 2) + math.pow(b - other.b, 2));

  // Linear sRGB channels; outside [0, 1] when the colour is out of gamut.
  List<double> get _linear {
    final l = math.pow(this.l + .3963377774 * a + .2158037573 * b, 3).toDouble();
    final m = math.pow(this.l - .1055613458 * a - .0638541728 * b, 3).toDouble();
    final s = math.pow(this.l - .0894841775 * a - 1.291485548 * b, 3).toDouble();
    return [
      4.0767416621 * l - 3.3077115913 * m + .2309699292 * s,
      -1.2684380046 * l + 2.6097574011 * m - .3413193965 * s,
      -.0041960863 * l - .7034186147 * m + 1.707614701 * s,
    ];
  }

  bool get inGamut => _linear.every((c) => c >= -1e-6 && c <= 1 + 1e-6);

  Color get color {
    double encode(double c) {
      final v = c.clamp(0.0, 1.0);
      return v <= .0031308 ? v * 12.92 : 1.055 * math.pow(v, 1 / 2.4) - .055;
    }

    final rgb = _linear;
    return Color.from(alpha: 1, red: encode(rgb[0]), green: encode(rgb[1]), blue: encode(rgb[2]));
  }
}

/// Deterministic k-means in OKLab over the blurred sample: farthest-point
/// initialisation starting from the mean, a fixed iteration cap, merge of
/// clusters closer than ΔE 0.06, then removal of clusters under 2% of the
/// pixels; up to eight candidates for [frostAmbientScoredPalette].
/// Transparent pixels count towards the total but carry no colour.
List<FrostAmbientPaletteEntry> frostAmbientCandidates(int width, int height, List<Color> pixels) {
  final points = <_OkLab>[], weights = <double>[], positions = <Offset>[];
  for (var i = 0; i < pixels.length; i++) {
    final pixel = pixels[i];
    if (pixel.a <= 0) continue;
    points.add(_OkLab.of(pixel.withValues(alpha: 1)));
    weights.add(pixel.a);
    positions.add(Offset(((i % width) + .5) / width, ((i ~/ width) + .5) / height));
  }
  final total = pixels.length.toDouble();
  if (points.isEmpty || total == 0) return const [];
  _OkLab mean(Iterable<int> members) {
    var l = 0.0, a = 0.0, b = 0.0, w = 0.0;
    for (final i in members) {
      l += points[i].l * weights[i];
      a += points[i].a * weights[i];
      b += points[i].b * weights[i];
      w += weights[i];
    }
    return _OkLab(l / w, a / w, b / w);
  }

  final indices = List.generate(points.length, (i) => i);
  final centres = <_OkLab>[mean(indices)];
  final nearest = List.filled(points.length, double.infinity);
  while (centres.length < _candidateSize) {
    var best = -1;
    var bestDistance = 1e-4;
    for (var i = 0; i < points.length; i++) {
      nearest[i] = math.min(nearest[i], points[i].distance(centres.last));
      if (nearest[i] > bestDistance) {
        bestDistance = nearest[i];
        best = i;
      }
    }
    if (best < 0) break;
    centres.add(points[best]);
  }
  final assignment = List.filled(points.length, -1);
  for (var iteration = 0; iteration < _clusterIterations; iteration++) {
    var changed = false;
    for (var i = 0; i < points.length; i++) {
      var best = 0;
      var bestDistance = double.infinity;
      for (var c = 0; c < centres.length; c++) {
        final distance = points[i].distance(centres[c]);
        if (distance < bestDistance) {
          bestDistance = distance;
          best = c;
        }
      }
      if (assignment[i] != best) {
        assignment[i] = best;
        changed = true;
      }
    }
    for (var c = 0; c < centres.length; c++) {
      final members = [
        for (var i = 0; i < points.length; i++)
          if (assignment[i] == c) i,
      ];
      if (members.isNotEmpty) centres[c] = mean(members);
    }
    if (!changed) break;
  }
  final clusters = <({_OkLab colour, double weight, Offset centroid})>[];
  for (var c = 0; c < centres.length; c++) {
    var weight = 0.0, x = 0.0, y = 0.0;
    for (var i = 0; i < points.length; i++) {
      if (assignment[i] != c) continue;
      weight += weights[i];
      x += positions[i].dx * weights[i];
      y += positions[i].dy * weights[i];
    }
    if (weight > 0) clusters.add((colour: centres[c], weight: weight, centroid: Offset(x / weight, y / weight)));
  }
  // Merge the closest pair under the threshold until none remains.
  while (true) {
    var pair = (-1, -1);
    var closest = _clusterMergeDistance;
    for (var i = 0; i < clusters.length; i++) {
      for (var j = i + 1; j < clusters.length; j++) {
        final distance = clusters[i].colour.distance(clusters[j].colour);
        if (distance < closest) {
          closest = distance;
          pair = (i, j);
        }
      }
    }
    if (pair.$1 < 0) break;
    final first = clusters[pair.$1], second = clusters[pair.$2];
    final weight = first.weight + second.weight;
    double mix(double a, double b) => (a * first.weight + b * second.weight) / weight;
    clusters[pair.$1] = (
      colour: _OkLab(mix(first.colour.l, second.colour.l), mix(first.colour.a, second.colour.a), mix(first.colour.b, second.colour.b)),
      weight: weight,
      centroid: Offset(mix(first.centroid.dx, second.centroid.dx), mix(first.centroid.dy, second.centroid.dy)),
    );
    clusters.removeAt(pair.$2);
  }
  final kept = clusters.where((c) => c.weight / total >= _candidateMinimumWeight).toList()
    // Stable for equal weights: centre order is itself deterministic.
    ..sort((a, b) => b.weight.compareTo(a.weight));
  return [for (final c in kept) FrostAmbientPaletteEntry(c.colour.color, c.weight / total, c.centroid)];
}

/// Selection in the style of Material Color Utilities `Score`. Each
/// chromatic candidate scores 0.7 × share plus a chroma term that rewards
/// chroma above the candidates' median and penalises near-neutral colours.
/// Picks are greedy with a minimum hue separation of 60°, stepping down to
/// 30° until three are chosen. A single chromatic pick gains two analogous
/// stops at ±30° and 0.6 × chroma. Chromatic weights share 60% of the frame;
/// the remaining 40% stays the neutral canvas. Art without any chromatic
/// candidate keeps up to three neutral ones.
List<FrostAmbientPaletteEntry> frostAmbientScoredPalette(List<FrostAmbientPaletteEntry> candidates) {
  final labs = {for (final c in candidates) c: _OkLab.of(c.color)};
  final chromatic = candidates.where((c) => labs[c]!.chroma >= _neutralChroma).toList();
  if (chromatic.isEmpty) return candidates.take(_pickCount).toList();
  final chromas = chromatic.map((c) => labs[c]!.chroma).toList()..sort();
  final median = chromas[chromas.length ~/ 2];
  double score(FrostAmbientPaletteEntry c) {
    final chroma = labs[c]!.chroma;
    final term = chroma >= median ? 3 * (chroma - median) : chroma - median;
    return .7 * c.weight + term - (chroma < _nearNeutralChroma ? .1 : 0);
  }

  final ranked = [...chromatic]..sort((a, b) => score(b).compareTo(score(a)));
  double separation(FrostAmbientPaletteEntry a, FrostAmbientPaletteEntry b) {
    final d = ((labs[a]!.hue - labs[b]!.hue) * 180 / math.pi).abs() % 360;
    return math.min(d, 360 - d);
  }

  var picked = <FrostAmbientPaletteEntry>[];
  for (final minimum in const [60.0, 50.0, 40.0, 30.0]) {
    picked = [];
    for (final candidate in ranked) {
      if (picked.length == _pickCount) break;
      if (picked.every((p) => separation(p, candidate) >= minimum)) picked.add(candidate);
    }
    if (picked.length == _pickCount) break;
  }
  if (picked.length == 1) {
    final main = picked.single, lab = labs[main]!;
    for (final (turn, shift) in const [(1, .2), (-1, -.2)]) {
      final hue = lab.hue + turn * math.pi / 6;
      final chroma = _gamutChroma(lab.l, hue, lab.chroma * .6);
      picked.add(
        FrostAmbientPaletteEntry(
          _OkLab.polar(lab.l, chroma, hue).color,
          main.weight * .5,
          Offset((main.centroid.dx + shift).clamp(0.0, 1.0), main.centroid.dy),
        ),
      );
    }
  }
  final total = picked.fold(0.0, (sum, p) => sum + p.weight);
  return [for (final p in picked) FrostAmbientPaletteEntry(p.color, p.weight / total * _chromaticShare, p.centroid)];
}

/// Maps one image colour into the theme's backdrop range in OKLCH. Dark: L
/// between canvas + .015 and the backdrop lightness limit. Light: L between canvas
/// − .07 and canvas, below surface − .02. Chroma is compressed, Cmax ·
/// tanh(C / Cmax); the hue goes through the hue zones and is harmonised with
/// the accent. Near-neutral colours take the canvas chroma and hue, so cool
/// and warm themes keep their tint. Both inks then reach 4.5:1, including
/// after 8-bit quantisation.
Color frostAmbientTone(FrostThemeTokens tokens, Color color) {
  final source = _OkLab.of(color.withValues(alpha: 1));
  final canvas = _OkLab.of(tokens.canvas);
  final double lightness;
  if (tokens.isDark) {
    final limit = frostBackdropLightnessLimit(tokens);
    // The band never inverts, even for a palette with a narrow canvas gap.
    final low = math.min(canvas.l + .015, limit);
    lightness = low + (limit - low) * source.l.clamp(0.0, 1.0);
  } else {
    lightness = canvas.l - .07 + .07 * source.l.clamp(0.0, 1.0);
  }
  if (source.chroma < _neutralChroma) return _enforce(tokens, _OkLab.polar(lightness, canvas.chroma, canvas.hue));
  final ceiling = tokens.isDark ? _darkChromaCeiling : _lightChromaCeiling;
  final hue = frostAmbientHarmonize(frostAmbientHueZone((source.hue * 180 / math.pi + 360) % 360), _degrees(_OkLab.of(tokens.accent).hue));
  return _enforce(tokens, _OkLab.polar(lightness, ceiling * _tanh(source.chroma / ceiling), hue * math.pi / 180));
}

double _degrees(double radians) => (radians * 180 / math.pi + 360) % 360;

double _gamutChroma(double lightness, double hue, double chroma) {
  if (_OkLab.polar(lightness, chroma, hue).inGamut) return chroma;
  var low = 0.0, high = chroma;
  for (var step = 0; step < 20; step++) {
    final mid = (low + high) / 2;
    if (_OkLab.polar(lightness, mid, hue).inGamut) {
      low = mid;
    } else {
      high = mid;
    }
  }
  return low;
}

// Moves L away from the inks (down in dark, up in light) until both inks pass
// and the lightness bounds hold, re-fitting chroma to the gamut at each step.
Color _enforce(FrostThemeTokens tokens, _OkLab target) {
  final hue = target.hue, wanted = target.chroma;
  final dark = tokens.isDark;
  final ceiling = dark ? frostBackdropLightnessLimit(tokens) : frostBackdropLightness(tokens.surface) - .02;
  // A gradient mixes the colour with canvas in gamma space. Linearisation is
  // convex, so in dark no mix is brighter than its brighter endpoint. In light
  // a mix can dip slightly below the darker one; the channel minimum bounds it.
  // Dither and grain then move a pixel by a few 8-bit steps, towards the ink
  // at worst, so that move is checked too.
  Color dithered(Color color) {
    final step = (dark ? _darkNoiseSteps : -_lightNoiseSteps) / 255;
    double move(double c) => (c + step).clamp(0.0, 1.0);
    return Color.from(alpha: 1, red: move(color.r), green: move(color.g), blue: move(color.b));
  }

  List<Color> worst(Color color) {
    final bound = dark ? color : _channelBound([color, tokens.canvas], false);
    return [color, bound, dithered(bound)];
  }

  bool readable(Color color) => worst(color).every(
    (background) => [
      tokens.textSecondary,
      tokens.textPrimary,
    ].every((ink) => frostContrastScrimOpacity(surface: tokens.canvas, ink: ink, worst: background, minimum: 0) == 0),
  );
  bool bounded(Color color) =>
      worst(color).every((background) => frostBackdropLightness(background) <= ceiling && frostBackdropLightness(Color(background.toARGB32())) <= ceiling);
  var lightness = target.l.clamp(0.0, 1.0);
  var color = _OkLab.polar(lightness, _gamutChroma(lightness, hue, wanted), hue).color;
  for (var step = 0; step < 500; step++) {
    final passes = readable(color);
    if (passes && bounded(color)) break;
    // Dark: both failures lower L. Light: readability raises it, the surface
    // ceiling lowers it; the canvas range keeps these from meeting.
    lightness = (dark || passes ? lightness - .002 : lightness + .002).clamp(0.0, 1.0);
    color = _OkLab.polar(lightness, _gamutChroma(lightness, hue, wanted), hue).color;
  }
  return color;
}

// Preserve the WinUI wash as a floor, adding a local surface backing only
// where the actual window background would otherwise make its ink unreadable.
Color frostReadableWindowFill(FrostThemeTokens tokens, Color floor, Color behind, Color ink) {
  final painted = Color.alphaBlend(floor, behind);
  final backing = frostContrastScrimOpacity(surface: Color.alphaBlend(floor, tokens.surface), ink: ink, worst: painted, minimum: 0);
  return Color.alphaBlend(floor, tokens.surface.withValues(alpha: backing));
}

/// Paints one radial gradient per palette colour into [clip], heaviest first,
/// centred where the colour sits in the sample under a cover fit of [target].
/// The radius grows with the colour's weight; alpha is [intensity] at the
/// centre, 55% of it halfway and none at the edge. The whole tint is then
/// masked by a static radial falloff from [falloffFrom] (default: the
/// top-leading corner of [target]), reaching zero at
/// [frostAmbientFalloffReach] of the target's diagonal.
void frostPaintAmbientPalette(
  Canvas canvas,
  Rect clip,
  Rect target,
  List<FrostAmbientPaletteEntry> palette,
  Size sourceSize,
  double intensity, {
  Offset? falloffFrom,
}) {
  canvas.saveLayer(clip, Paint());
  final source = Offset.zero & sourceSize;
  final crop = source.isEmpty || target.isEmpty ? Rect.zero : Alignment.center.inscribe(applyBoxFit(BoxFit.cover, source.size, target.size).source, source);
  final extent = target.longestSide;
  for (final entry in palette) {
    final center = crop.isEmpty
        ? target.center
        : Offset(
            target.left + (entry.centroid.dx * source.width - crop.left) / crop.width * target.width,
            target.top + (entry.centroid.dy * source.height - crop.top) / crop.height * target.height,
          );
    final color = entry.color;
    canvas.drawRect(
      clip,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: intensity),
            color.withValues(alpha: .55 * intensity),
            color.withValues(alpha: 0),
          ],
          stops: const [0, .5, 1],
        ).createShader(Rect.fromCircle(center: center, radius: extent * (.45 + .4 * entry.weight))),
    );
  }
  final origin = falloffFrom ?? target.topLeft;
  const samples = 9;
  canvas.drawRect(
    clip,
    Paint()
      ..blendMode = BlendMode.dstIn
      ..shader =
          RadialGradient(
            colors: [for (var i = 0; i < samples; i++) Color.fromRGBO(0, 0, 0, frostAmbientFalloff(i / (samples - 1)))],
            stops: [for (var i = 0; i < samples; i++) i / (samples - 1)],
          ).createShader(
            Rect.fromCircle(center: origin, radius: frostAmbientFalloffReach * math.sqrt(target.width * target.width + target.height * target.height)),
          ),
  );
  canvas.restore();
}

/// Fraction of the target diagonal at which the light tint reaches zero, so
/// colour gathers at the top-leading corner and the reading area stays calm.
const frostAmbientFalloffReach = .65;

/// Tint alpha at [fraction] of the falloff reach: 1 at the origin, a smooth
/// (smoothstep) decline, and 0 from the reach onwards.
double frostAmbientFalloff(double fraction) => 1 - _smoothstep(0, 1, fraction);

/// The small pre-blurred copy of decoded artwork and its pixels, shared by
/// the window host and the media surround. No further decode is involved.
Future<({ui.Image image, FrostAmbientSample sample})> frostAmbientSampleOf(ui.Image source, int sampleWidth) async {
  final height = (sampleWidth * source.height / source.width).round().clamp(8, 96);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final bounds = Rect.fromLTWH(0, 0, sampleWidth.toDouble(), height.toDouble());
  // Clamp the edges so the blur does not fade to transparent at the border.
  canvas.saveLayer(bounds, Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3, tileMode: TileMode.clamp));
  canvas.drawImageRect(source, Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()), bounds, Paint()..filterQuality = FilterQuality.medium);
  canvas.restore();
  final picture = recorder.endRecording();
  final image = await picture.toImage(sampleWidth, height).whenComplete(picture.dispose);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    if (bytes == null) throw StateError('Ambient sample pixels are unavailable.');
    final pixels = <Color>[];
    for (var offset = 0; offset < bytes.lengthInBytes; offset += 4) {
      // Transparent source pixels reveal the canvas, not opaque black.
      pixels.add(Color.fromARGB(bytes.getUint8(offset + 3), bytes.getUint8(offset), bytes.getUint8(offset + 1), bytes.getUint8(offset + 2)));
    }
    return (image: image, sample: FrostAmbientSample(image.width, image.height, pixels));
  } catch (_) {
    image.dispose();
    rethrow;
  }
}

/// Static light grain: a deterministic 64 × 64 TPDF tile at about ±1.5/255,
/// rounded to whole steps and shifted down to 0, 1 or 2 steps, drawn with a
/// difference blend. It only darkens, so the light surface hierarchy keeps
/// its budget in both directions. Generated once, asynchronously; listeners
/// repaint.
final frostAmbientGrain = ValueNotifier<ui.Image?>(null);
bool _grainStarted = false;
const _grainSide = 64;

void frostEnsureAmbientGrain() {
  if (_grainStarted) return;
  _grainStarted = true;
  var seed = 0x9E3779B9;
  double next() {
    seed = (seed * 1664525 + 1013904223) & 0xFFFFFFFF;
    return seed / 0x100000000;
  }

  final tile = Uint8List(_grainSide * _grainSide * 4);
  for (var i = 0; i < _grainSide * _grainSide; i++) {
    final noise = ((next() + next() - 1) * 1.5).round().clamp(-1, 1);
    tile[i * 4] = tile[i * 4 + 1] = tile[i * 4 + 2] = 1 - noise;
    tile[i * 4 + 3] = 255;
  }
  ui.decodeImageFromPixels(tile, _grainSide, _grainSide, ui.PixelFormat.rgba8888, (image) => frostAmbientGrain.value = image);
}

/// Draws the grain over an already opaque light backdrop in [rect], one texel
/// per physical pixel. Dark backdrops paint light, not stain, so they carry
/// none; nothing either before the tile is ready.
void frostPaintAmbientGrain(Canvas canvas, Rect rect, double pixelRatio, {bool dark = false}) {
  if (dark) return;
  final grain = frostAmbientGrain.value;
  if (grain == null) {
    frostEnsureAmbientGrain();
    return;
  }
  final s = 1 / pixelRatio;
  canvas.drawRect(
    rect,
    Paint()
      ..blendMode = BlendMode.difference
      ..shader = ImageShader(grain, TileMode.repeated, TileMode.repeated, Float64List.fromList([s, 0, 0, 0, 0, s, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1])),
  );
}

/// No-image background: three static stops tinted by the accent hue, lighter
/// at the top-leading corner and darker in the far corner. Dark: L from
/// L(canvas) + .012 down to L(canvas), C ≤ .012. Light: L from L(canvas) down
/// to L(canvas) − .02, C ≤ .015. Each stop passes the same solver as the
/// palette colours (both inks, the lightness limits, noise).
List<Color> frostAmbientMeshStops(FrostThemeTokens tokens) {
  final key = (tokens.brightness, tokens.tone, tokens.canvas, tokens.surface, tokens.textPrimary, tokens.textSecondary, tokens.accent);
  if (_meshStops[key] case final cached?) return cached;
  if (_meshStops.length >= _ambientMaterialCacheCapacity) _meshStops.clear();
  final canvas = _OkLab.of(tokens.canvas), accent = _OkLab.of(tokens.accent);
  final dark = tokens.isDark;
  final chroma = math.min(accent.chroma, dark ? .012 : .015);
  final lightness = dark ? [canvas.l + .012, canvas.l + .006, canvas.l] : [canvas.l, canvas.l - .01, canvas.l - .02];
  return _meshStops[key] = [for (final l in lightness) _enforce(tokens, _OkLab.polar(l, chroma, accent.hue))];
}

final _meshStops = <Object, List<Color>>{};

/// Material for the mesh: dark takes its most luminous stop, light the
/// channel minimum of stops and canvas, as for the palette.
FrostAmbientMaterials frostAmbientMeshMaterial(FrostThemeTokens tokens) {
  final stops = [tokens.canvas, ...frostAmbientMeshStops(tokens)];
  final background = tokens.isDark ? stops.reduce((a, b) => b.computeLuminance() > a.computeLuminance() ? b : a) : _channelBound(stops, false);
  return FrostAmbientMaterials(background: background);
}

void frostPaintAmbientMesh(Canvas canvas, Rect clip, Rect target, FrostThemeTokens tokens, double intensity) {
  final stops = frostAmbientMeshStops(tokens);
  canvas.drawRect(
    clip,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [for (final stop in stops) Color.lerp(tokens.canvas, stop, intensity)!],
        stops: const [0, .45, 1],
      ).createShader(target),
  );
}

// ---------------------------------------------------------------- dark glows

/// Window glow radius, as a fraction of the window diagonal.
const frostAmbientGlowWindowReach = .55;

/// Detail glow radius, as a fraction of the surround diagonal.
const frostAmbientGlowDetailReach = .75;

/// Window glow chroma as a share r of the gamut chroma at each L and hue:
/// the content area carries the art's colour most strongly.
const frostAmbientWindowGlowRatio = .80;

/// Detail surround glow ratio: lower, so the surround never competes with
/// the media it extends.
const frostAmbientGlowRatio = .65;

/// Feathering outside a registered card, in logical pixels: wide enough that
/// the lower glow under a card shows no outline.
const frostAmbientCardFeather = 24.0;

double _smoothstep(double edge0, double edge1, double x) {
  final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

// (start, end, hue shift in degrees). Each zone acts fully in its middle
// third and tapers smoothly to nothing at its edges. Orange turns towards
// red, yellow to gold and yellow-green to green (no olive), pure blue and
// violet away from their harshest hues, magenta towards rose.
const _hueZones = <(double, double, double)>[(45, 75, -10), (95, 110, -20), (110, 125, 20), (190, 200, 0), (255, 270, -10), (280, 305, 10), (330, 350, 12)];

/// The middle third of a zone, where its shift acts in full.
List<(double, double)> get frostAmbientHueZoneCores => [for (final (start, end, _) in _hueZones) (start + (end - start) / 3, end - (end - start) / 3)];

/// [hue] (degrees) after the hue zones.
double frostAmbientHueZone(double hue) {
  var shifted = hue;
  for (final (start, end, shift) in _hueZones) {
    final third = (end - start) / 3;
    shifted += _smoothstep(start, start + third, hue) * (1 - _smoothstep(end - third, end, hue)) * shift;
  }
  return (shifted + 360) % 360;
}

/// Material Color Utilities `Blend.harmonize`: turn towards the accent by
/// half the difference, at most 15°.
double frostAmbientHarmonize(double hue, double accent) {
  final difference = (accent - hue + 540) % 360 - 180;
  final turn = math.min(difference.abs() / 2, 15.0) * difference.sign;
  return (hue + turn + 360) % 360;
}

/// One dark glow: its mapped hue (radians), chroma share of the gamut,
/// whether it is a warm hue that turns brown when dim (source 30–125°), and
/// its source pick.
typedef FrostAmbientGlow = ({double hue, double share, bool warm, Offset centroid, double weight});

/// The dark glows for [raw], and the shared lift ΔLmax. The peak is
/// L(surface) − .02, lowered until both inks keep 4.5:1 over every glow's
/// peak colour and its dither step. [window] takes
/// [frostAmbientWindowGlowRatio], otherwise [frostAmbientGlowRatio].
({List<FrostAmbientGlow> glows, double lift}) frostAmbientGlows(FrostThemeTokens tokens, List<FrostAmbientPaletteEntry> raw, {bool window = false}) {
  final ratio = window ? frostAmbientWindowGlowRatio : frostAmbientGlowRatio;
  final key = (
    ratio,
    tokens.brightness,
    tokens.tone,
    tokens.canvas,
    tokens.surface,
    tokens.textPrimary,
    tokens.textSecondary,
    tokens.accent,
    Object.hashAll(raw),
    raw.length,
  );
  if (_glows[key] case final cached?) return cached;
  if (_glows.length >= _ambientMaterialCacheCapacity) _glows.clear();
  final accent = _degrees(_OkLab.of(tokens.accent).hue);
  final glows = <FrostAmbientGlow>[];
  for (final entry in raw) {
    final lab = _OkLab.of(entry.color);
    if (lab.chroma < _neutralChroma) continue;
    final source = _degrees(lab.hue);
    final hue = frostAmbientHarmonize(frostAmbientHueZone(source), accent);
    // No brown, gated by the source hue: zones and harmonisation move orange
    // and brown (about 50°) just under 30°.
    glows.add((hue: hue * math.pi / 180, share: ratio, warm: source >= 30 && source <= 125, centroid: entry.centroid, weight: entry.weight));
  }
  return _glows[key] = (glows: glows, lift: _glowLift(tokens, glows, frostBackdropLightness(tokens.surface) - .02));
}

final _glows = <Object, ({List<FrostAmbientGlow> glows, double lift})>{};

/// The largest lift below [ceiling] at which both inks keep 4.5:1 over every
/// glow's peak colour and its dither step, and that step stays under it.
double _glowLift(FrostThemeTokens tokens, List<FrostAmbientGlow> glows, double ceiling) {
  final canvas = _OkLab.of(tokens.canvas);
  Color step(Color color) =>
      Color.from(alpha: 1, red: (color.r + 1 / 255).clamp(0.0, 1.0), green: (color.g + 1 / 255).clamp(0.0, 1.0), blue: (color.b + 1 / 255).clamp(0.0, 1.0));
  bool readable(Color color) => [color, step(color)].every(
    (background) => [
      tokens.textSecondary,
      tokens.textPrimary,
    ].every((ink) => frostContrastScrimOpacity(surface: tokens.canvas, ink: ink, worst: background, minimum: 0) == 0),
  );
  // The bake dithers by up to one step; keep that step under the ceiling.
  bool bounded(Color color) => frostBackdropLightness(step(color)) <= ceiling;
  var peak = ceiling;
  while (peak > canvas.l &&
      !glows.every((g) {
        final color = _glowColour(canvas, peak, g);
        return readable(color) && bounded(color) && bounded(_OkLab(peak, canvas.a, canvas.b).color);
      })) {
    peak -= .002;
  }
  return math.max(0.0, peak - canvas.l);
}

Color _glowColour(_OkLab canvas, double l, FrostAmbientGlow g) {
  final chroma = g.share * _gamutChroma(l, g.hue, .4);
  return _OkLab(l, canvas.a + chroma * math.cos(g.hue), canvas.b + chroma * math.sin(g.hue)).color;
}

/// The window lift away from registered cards, up to L(surface) − .005 under
/// the same contrast and dither rules. Under cards the lower lift of
/// [frostAmbientGlows] (L(surface) − .02) holds, keeping cards apart.
double frostAmbientFreeLift(FrostThemeTokens tokens, List<FrostAmbientPaletteEntry> raw) {
  final model = frostAmbientGlows(tokens, raw, window: true);
  final key = (
    tokens.brightness,
    tokens.tone,
    tokens.canvas,
    tokens.surface,
    tokens.textPrimary,
    tokens.textSecondary,
    tokens.accent,
    Object.hashAll(raw),
    raw.length,
  );
  if (_freeLifts.length >= _ambientMaterialCacheCapacity) _freeLifts.clear();
  return _freeLifts[key] ??= math.max(model.lift, _glowLift(tokens, model.glows, frostBackdropLightness(tokens.surface) - .005));
}

final _freeLifts = <Object, double>{};

/// Peak colours of the dark glows, for the worst-background bound; [free]
/// takes the window glows at the card-free lift, the window's brightest
/// pixels.
List<Color> frostAmbientGlowPeaks(FrostThemeTokens tokens, List<FrostAmbientPaletteEntry> raw, {bool free = false}) {
  final canvas = _OkLab.of(tokens.canvas);
  final model = frostAmbientGlows(tokens, raw, window: free);
  final l = canvas.l + (free ? frostAmbientFreeLift(tokens, raw) : model.lift);
  return [for (final g in model.glows) _glowColour(canvas, l, g)];
}

/// Everything the bake needs, as plain data so it can run off the UI isolate.
typedef FrostAmbientGlowBake = ({
  int width,
  int height,
  double scale,
  List<double> canvas,
  List<int> canvasRgb,
  double cap,
  // False only for analysis and tests: plain rounding, no noise.
  bool dither,
  double lift,
  // The lift away from [cards] (logical l, t, r, b, ...), which keep [lift];
  // it eases in over [frostAmbientCardFeather] outside them.
  double freeLift,
  List<double> cards,
  double radius,
  List<({double x, double y, double hue, double share, bool warm})> glows,
});

/// Bakes the dark glow field, RGBA8 with TPDF dither:
///
/// - each glow lifts ΔL_i = ΔLmax · f(d / R), f the smooth falloff, and
///   L = L(canvas) + min(ΔLmax, (Σ ΔL_i⁴)^¼), a soft maximum, scaled up to
///   the free lift away from cards;
/// - a/b are built apart from L, so the hue can only turn gradually: each
///   glow adds its chroma vector premultiplied by a Gaussian-like profile on
///   a coarse grid, and numerator and weight are blurred (sigma 8% of the
///   diagonal) and divided, a normalised convolution. Weighting by the
///   lifts instead switched dominance across a narrow band, where differing
///   hues cancelled: two flat regions and a seam;
/// - each glow's chroma is share · Cgamut(L, h) · profile, warm hues
///   × smoothstep(.45, .7, profile), all × smoothstep(.006, .018, C), faded
///   with the lift so the field still ends neutral at the reach;
/// - the result, canvas tint included, never exceeds [cap] · Cgamut(L, h).
///
/// [lab], when given (width × height × 3), receives the unquantised OKLab
/// field, for analysis and tests.
Uint8List frostAmbientBakeGlowField(FrostAmbientGlowBake bake, [Float32List? lab]) {
  final lc = bake.canvas[0], ca = bake.canvas[1], cb = bake.canvas[2];
  // Gamut chroma table over the narrow L range and every degree of hue.
  const lSteps = 16, hSteps = 360;
  final span = math.max(bake.lift, bake.freeLift);
  final table = Float64List((lSteps + 1) * hSteps);
  for (var i = 0; i <= lSteps; i++) {
    final l = lc + span * i / lSteps;
    for (var h = 0; h < hSteps; h++) {
      table[i * hSteps + h] = _gamutChroma(l, h * math.pi / 180, .4);
    }
  }
  double gamut(double l, double hue) {
    final li = (span <= 0 ? 0.0 : ((l - lc) / span * lSteps)).clamp(0.0, lSteps.toDouble());
    final hi = ((hue * 180 / math.pi) % 360 + 360) % 360;
    final l0 = li.floor().clamp(0, lSteps - 1), h0 = hi.floor() % hSteps, h1 = (h0 + 1) % hSteps;
    final lt = li - l0, ht = hi - hi.floor();
    double at(int l, int h) => table[l * hSteps + h];
    final low = at(l0, h0) * (1 - ht) + at(l0, h1) * ht, high = at(l0 + 1, h0) * (1 - ht) + at(l0 + 1, h1) * ht;
    return low * (1 - lt) + high * lt;
  }

  final out = Uint8List(bake.width * bake.height * 4);
  var seed = 0x2545F491;
  double noise() {
    seed = (seed * 1664525 + 1013904223) & 0xFFFFFFFF;
    final a = seed / 0x100000000;
    seed = (seed * 1664525 + 1013904223) & 0xFFFFFFFF;
    return a + seed / 0x100000000 - 1;
  }

  double encode(double c) {
    final v = c.clamp(0.0, 1.0);
    return v <= .0031308 ? v * 12.92 : 1.055 * math.pow(v, 1 / 2.4) - .055;
  }

  final diagonal = math.sqrt(bake.width * bake.width + bake.height * bake.height);
  final cell = math.max(4.0, diagonal * .01);
  final gw = (bake.width / cell).ceil() + 2, gh = (bake.height / cell).ceil() + 2;
  final fieldA = Float64List(gw * gh), fieldB = Float64List(gw * gh), fieldW = Float64List(gw * gh);
  for (var j = 0; j < gh; j++) {
    for (var i = 0; i < gw; i++) {
      final px = i * cell / bake.scale, py = j * cell / bake.scale;
      for (final g in bake.glows) {
        final dx = px - g.x, dy = py - g.y;
        final t = math.sqrt(dx * dx + dy * dy) / bake.radius;
        if (t >= 1) continue;
        final profile = math.exp(-t * t / (2 * .35 * .35)) * (1 - _smoothstep(.75, 1, t));
        var chroma = g.share * gamut(lc + bake.lift * profile, g.hue) * profile;
        if (g.warm) chroma *= _smoothstep(.45, .7, profile);
        chroma *= _smoothstep(.006, .018, chroma);
        fieldA[j * gw + i] += profile * chroma * math.cos(g.hue);
        fieldB[j * gw + i] += profile * chroma * math.sin(g.hue);
        fieldW[j * gw + i] += profile;
      }
    }
  }
  final sigma = .08 * diagonal / cell;
  final reach = (3 * sigma).ceil();
  final kernel = [for (var k = -reach; k <= reach; k++) math.exp(-k * k / (2 * sigma * sigma))];
  void blur(Float64List field) {
    final pass = Float64List(field.length);
    for (var j = 0; j < gh; j++) {
      for (var i = 0; i < gw; i++) {
        var sum = 0.0;
        for (var k = -reach; k <= reach; k++) {
          sum += field[j * gw + (i + k).clamp(0, gw - 1)] * kernel[k + reach];
        }
        pass[j * gw + i] = sum;
      }
    }
    for (var j = 0; j < gh; j++) {
      for (var i = 0; i < gw; i++) {
        var sum = 0.0;
        for (var k = -reach; k <= reach; k++) {
          sum += pass[(j + k).clamp(0, gh - 1) * gw + i] * kernel[k + reach];
        }
        field[j * gw + i] = sum;
      }
    }
  }

  blur(fieldA);
  blur(fieldB);
  blur(fieldW);
  // Bilinear sample of the normalised, blurred a/b field at pixel (x, y).
  (double, double) smoothAb(int x, int y) {
    final gx = ((x + .5) / cell).clamp(0.0, gw - 1.001), gy = ((y + .5) / cell).clamp(0.0, gh - 1.001);
    final i = gx.floor(), j = gy.floor(), tx = gx - i, ty = gy - j;
    double sample(Float64List f) =>
        (f[j * gw + i] * (1 - tx) + f[j * gw + i + 1] * tx) * (1 - ty) + (f[(j + 1) * gw + i] * (1 - tx) + f[(j + 1) * gw + i + 1] * tx) * ty;
    final w = sample(fieldW);
    return w <= 1e-9 ? (0.0, 0.0) : (sample(fieldA) / w, sample(fieldB) / w);
  }

  for (var y = 0; y < bake.height; y++) {
    final py = (y + .5) / bake.scale;
    for (var x = 0; x < bake.width; x++) {
      final px = (x + .5) / bake.scale;
      var sum4 = 0.0, reached = false;
      for (final g in bake.glows) {
        final dx = px - g.x, dy = py - g.y;
        final t = math.sqrt(dx * dx + dy * dy) / bake.radius;
        if (t >= 1) continue;
        final lift = bake.lift * (1 - _smoothstep(0, 1, t));
        sum4 += lift * lift * lift * lift;
        reached = reached || lift > 0;
      }
      final at = (y * bake.width + x) * 4;
      if (!reached) {
        // Beyond every glow: exactly the canvas, without dither.
        if (lab != null) {
          final i = (y * bake.width + x) * 3;
          lab
            ..[i] = lc
            ..[i + 1] = ca
            ..[i + 2] = cb;
        }
        out
          ..[at] = bake.canvasRgb[0]
          ..[at + 1] = bake.canvasRgb[1]
          ..[at + 2] = bake.canvasRgb[2]
          ..[at + 3] = 255;
        continue;
      }
      final liftTotal = math.min(bake.lift, math.sqrt(math.sqrt(sum4)));
      var l = lc + liftTotal;
      if (bake.freeLift > bake.lift && bake.lift > 0) {
        // The same normalised field, scaled up to the free lift away from
        // cards; inside a card the scale is exactly one.
        var distance = double.infinity;
        for (var k = 0; k < bake.cards.length; k += 4) {
          final dx = math.max(0.0, math.max(bake.cards[k] - px, px - bake.cards[k + 2]));
          final dy = math.max(0.0, math.max(bake.cards[k + 1] - py, py - bake.cards[k + 3]));
          distance = math.min(distance, math.sqrt(dx * dx + dy * dy));
        }
        final away = distance == double.infinity ? 1.0 : _smoothstep(0, frostAmbientCardFeather, distance);
        l = lc + liftTotal / bake.lift * (bake.lift + (bake.freeLift - bake.lift) * away);
      }
      // The blurred field, faded with the lift so it still ends neutral at
      // the reach; the fade scales magnitude, never hue.
      final (fa, fb) = smoothAb(x, y);
      final presence = bake.lift <= 0 ? 0.0 : _smoothstep(0, .25, liftTotal / bake.lift);
      var a = ca + fa * presence, b = cb + fb * presence;
      final c = math.sqrt(a * a + b * b);
      if (c > 0) {
        final cap = bake.cap * gamut(l, math.atan2(b, a));
        if (c > cap) {
          a *= cap / c;
          b *= cap / c;
        }
      }
      if (lab != null) {
        final i = (y * bake.width + x) * 3;
        lab
          ..[i] = l
          ..[i + 1] = a
          ..[i + 2] = b;
      }
      final rgb = _OkLab(l, a, b)._linear;
      for (var k = 0; k < 3; k++) {
        // TPDF dither, at most one 8-bit step from the nearest value.
        final value = encode(rgb[k]) * 255;
        final nearest = value.round();
        out[at + k] = bake.dither ? (value + noise()).round().clamp(nearest - 1, nearest + 1).clamp(0, 255) : nearest.clamp(0, 255);
      }
      out[at + 3] = 255;
    }
  }
  return out;
}

/// Bakes on a background isolate where available, then uploads the image.
Future<ui.Image> frostAmbientBakeGlowImage(FrostAmbientGlowBake bake) async {
  final pixels = await compute(frostAmbientBakeGlowField, bake);
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(pixels, bake.width, bake.height, ui.PixelFormat.rgba8888, done.complete);
  return done.future;
}

/// One endpoint of a cross-fade: its weight when the current fade began.
/// One endpoint of a cross-fade: its weight when the current fade began.
abstract interface class FrostAmbientFading {
  abstract double startWeight;
  void dispose();
}

/// Fading endpoints kept beside a new one. Each paints window-sized layers on
/// every frame, and retargeting faster than the fade would stack them up.
const _ambientFadingCapacity = 2;

/// Disposes the faintest of [frames] beyond the capacity and scales the rest
/// back to the same total, so the mixture stays opaque.
void frostAmbientBoundFading<T extends FrostAmbientFading>(List<T> frames) {
  if (frames.length <= _ambientFadingCapacity) return;
  final total = frames.fold(0.0, (sum, frame) => sum + frame.startWeight);
  while (frames.length > _ambientFadingCapacity) {
    var faintest = 0;
    for (var index = 1; index < frames.length; index++) {
      if (frames[index].startWeight < frames[faintest].startWeight) faintest = index;
    }
    frames.removeAt(faintest).dispose();
  }
  final kept = frames.fold(0.0, (sum, frame) => sum + frame.startWeight);
  if (kept <= 0) return;
  for (final frame in frames) {
    frame.startWeight *= total / kept;
  }
}

/// Waits for what a bake depends on to hold still, so moving layout does not
/// bake a field nobody keeps. Layout that never rests still gets its bake once
/// the patience runs out.
class FrostAmbientSettle {
  static const _quiet = Duration(milliseconds: 120), _patience = Duration(milliseconds: 800);
  Timer? _quietTimer, _patienceTimer;
  Completer<bool>? _waiter;

  /// True once settled; false when a newer [wait] or [cancel] took over. A
  /// newer wait keeps the patience already running.
  Future<bool> wait() {
    _waiter?.complete(false);
    final waiter = _waiter = Completer<bool>();
    _quietTimer?.cancel();
    _quietTimer = Timer(_quiet, _settled);
    _patienceTimer ??= Timer(_patience, _settled);
    return waiter.future;
  }

  /// Something moved: start the quiet period again.
  void moved() {
    if (_waiter == null) return;
    _quietTimer?.cancel();
    _quietTimer = Timer(_quiet, _settled);
  }

  void _settled() {
    final waiter = _waiter;
    _clear();
    waiter?.complete(true);
  }

  void cancel() {
    final waiter = _waiter;
    _clear();
    waiter?.complete(false);
  }

  void _clear() {
    _quietTimer?.cancel();
    _patienceTimer?.cancel();
    _quietTimer = _patienceTimer = null;
    _waiter = null;
  }
}

class _BakeTicket {
  _BakeTicket(this.owner, this.key, this.bake);
  final Object owner;
  final _BakeKey key;
  final FrostAmbientGlowBake bake;
  final done = Completer<ui.Image?>();
}

/// Everything that changes a bake's pixels: material, theme, window size,
/// pixel ratio and card rects all reach the output through these numbers.
class _BakeKey {
  _BakeKey(FrostAmbientGlowBake bake)
    : _values = [
        bake.width,
        bake.height,
        bake.scale,
        ...bake.canvas,
        ...bake.canvasRgb,
        bake.cap,
        if (bake.dither) 1 else 0,
        bake.lift,
        bake.freeLift,
        bake.radius,
        bake.cards.length,
        ...bake.cards,
        for (final glow in bake.glows) ...[glow.x, glow.y, glow.hue, glow.share, if (glow.warm) 1 else 0],
      ];
  final List<num> _values;
  @override
  late final int hashCode = Object.hashAll(_values);
  @override
  bool operator ==(Object other) => other is _BakeKey && listEquals(_values, other._values);
}

/// Runs glow bakes one at a time for the whole process and keeps their results.
///
/// Concurrent bakes stall the UI isolate while one alone does not, so at most
/// one runs. Each owner has one place in the queue: its newer request replaces
/// its waiting one, whose future resolves to null, and an owner that moved on
/// no longer receives what is running. A running bake is not aborted, and its
/// result is dropped if nobody waits for it any more. Other owners keep their
/// places, since each of them still needs its own field.
///
/// Every image handed out is the caller's own handle to dispose.
class FrostAmbientGlowBakes {
  FrostAmbientGlowBakes._();
  static final instance = FrostAmbientGlowBakes._();

  // A bake is capped near a megapixel, so this bounds the memory too. It covers
  // going back and forth between a few pictures in both surfaces.
  static const _capacity = 8;
  final _results = <_BakeKey, ui.Image>{};
  final _waiting = <Object, _BakeTicket>{};
  _BakeKey? _runningKey;
  final _receivers = <_BakeTicket>[];

  /// Replaces the bake itself in tests.
  @visibleForTesting
  Future<ui.Image> Function(FrostAmbientGlowBake bake)? debugRunner;

  /// Bakes begun since the last [debugReset].
  @visibleForTesting
  int debugStarted = 0;

  /// The most bakes that ever ran at once since the last [debugReset].
  @visibleForTesting
  int debugPeakRunning = 0;
  int _runningCount = 0;

  /// The cache's own handles, oldest use first.
  @visibleForTesting
  Iterable<ui.Image> get debugCachedImages => _results.values;

  @visibleForTesting
  void debugReset() {
    for (final image in _results.values) {
      image.dispose();
    }
    _results.clear();
    debugStarted = 0;
    debugPeakRunning = _runningCount;
    debugRunner = null;
  }

  ui.Image? _reuse(_BakeKey key) {
    final image = _results.remove(key);
    if (image == null) return null;
    _results[key] = image;
    return image.clone();
  }

  /// The finished field for [bake], if it is at hand.
  ui.Image? cached(FrostAmbientGlowBake bake) => _reuse(_BakeKey(bake));

  /// The field for [bake], or null if [owner] asked for something else or
  /// cancelled before it arrived.
  Future<ui.Image?> request(Object owner, FrostAmbientGlowBake bake) {
    cancel(owner);
    final key = _BakeKey(bake);
    if (_reuse(key) case final image?) return Future.value(image);
    final ticket = _BakeTicket(owner, key, bake);
    if (key == _runningKey) {
      _receivers.add(ticket);
    } else {
      _waiting[owner] = ticket;
      _startNext();
    }
    return ticket.done.future;
  }

  /// Withdraws what [owner] waits for. A bake already running goes on.
  void cancel(Object owner) {
    _waiting.remove(owner)?.done.complete(null);
    _receivers.removeWhere((ticket) {
      if (ticket.owner != owner) return false;
      ticket.done.complete(null);
      return true;
    });
  }

  void _startNext() {
    if (_runningKey != null) return;
    while (_waiting.isNotEmpty) {
      final ticket = _waiting.remove(_waiting.keys.first)!;
      if (_reuse(ticket.key) case final image?) {
        ticket.done.complete(image);
        continue;
      }
      _runningKey = ticket.key;
      _receivers.add(ticket);
      _waiting.removeWhere((_, other) {
        if (other.key != ticket.key) return false;
        _receivers.add(other);
        return true;
      });
      debugStarted++;
      debugPeakRunning = math.max(debugPeakRunning, ++_runningCount);
      // The slot belongs to the process, not to the zone of whoever asked: it
      // has to come free even if that zone is gone by then.
      unawaited(Zone.root.run(() => _run(ticket)));
      return;
    }
  }

  Future<void> _run(_BakeTicket ticket) async {
    try {
      final image = await (debugRunner ?? frostAmbientBakeGlowImage)(ticket.bake);
      if (_receivers.isEmpty) {
        image.dispose();
      } else {
        _results[ticket.key] = image;
        while (_results.length > _capacity) {
          _results.remove(_results.keys.first)?.dispose();
        }
        for (final receiver in _receivers) {
          receiver.done.complete(image.clone());
        }
      }
    } catch (error, stack) {
      for (final receiver in _receivers) {
        receiver.done.completeError(error, stack);
      }
    } finally {
      _receivers.clear();
      _runningKey = null;
      _runningCount--;
      _startNext();
    }
  }
}

/// The bake for [model] in a [size] logical area at [pixelRatio], capped near
/// one megapixel; [centres] are logical positions. [freeLift] and [cards]
/// shape the window field (see the bake); [window] takes the window ratio as
/// the chroma cap.
FrostAmbientGlowBake frostAmbientGlowBakeFor(
  FrostThemeTokens tokens,
  ({List<FrostAmbientGlow> glows, double lift}) model,
  List<Offset> centres,
  Size size,
  double radius,
  double pixelRatio, {
  double? freeLift,
  List<Rect> cards = const [],
  bool window = false,
}) {
  final canvas = _OkLab.of(tokens.canvas);
  final scale = math.min(pixelRatio, math.sqrt(1.1e6 / math.max(1.0, size.width * size.height)));
  return (
    width: math.max(1, (size.width * scale).ceil()),
    height: math.max(1, (size.height * scale).ceil()),
    scale: scale,
    canvas: [canvas.l, canvas.a, canvas.b],
    canvasRgb: [(tokens.canvas.r * 255).round(), (tokens.canvas.g * 255).round(), (tokens.canvas.b * 255).round()],
    cap: window ? frostAmbientWindowGlowRatio : frostAmbientGlowRatio,
    dither: true,
    lift: model.lift,
    freeLift: freeLift ?? model.lift,
    cards: [
      for (final card in cards) ...[card.left, card.top, card.right, card.bottom],
    ],
    radius: radius,
    glows: [
      for (var i = 0; i < model.glows.length; i++)
        (x: centres[i].dx, y: centres[i].dy, hue: model.glows[i].hue, share: model.glows[i].share, warm: model.glows[i].warm),
    ],
  );
}

/// Window glow centres: each pick's cover-fitted centroid, pulled 65% of the
/// way towards the top edge, where the window's chrome sits.
List<Offset> frostAmbientWindowGlowCentres(List<FrostAmbientGlow> glows, Size sourceSize, Rect target) {
  final source = Offset.zero & sourceSize;
  final crop = source.isEmpty ? Rect.zero : Alignment.center.inscribe(applyBoxFit(BoxFit.cover, source.size, target.size).source, source);
  return [
    for (final glow in glows)
      () {
        final point = crop.isEmpty
            ? target.center
            : Offset(
                target.left + (glow.centroid.dx * source.width - crop.left) / crop.width * target.width,
                target.top + (glow.centroid.dy * source.height - crop.top) / crop.height * target.height,
              );
        return Offset(point.dx, target.top + (point.dy - target.top) * .35);
      }(),
  ];
}

/// Detail glow centres around the media [stage]: a centroid at the image
/// centre sits behind the stage; off-centre colours move out to its edges.
List<Offset> frostAmbientDetailGlowCentres(List<FrostAmbientGlow> glows, Rect stage) {
  final margin = stage.shortestSide * .15;
  return [
    for (final glow in glows)
      stage.center + Offset((glow.centroid.dx - .5) * (stage.width + 2 * margin), (glow.centroid.dy - .5) * (stage.height + 2 * margin)),
  ];
}

/// Gamut-boundary chroma at [lightness] and [hue] (radians), for tests.
@visibleForTesting
double frostAmbientTestGamut(double lightness, double hue) => _gamutChroma(lightness, hue, .4);
