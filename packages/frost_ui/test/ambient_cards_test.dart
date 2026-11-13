import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/foundation/_ambient_material.dart';
import 'package:frost_ui/src/foundation/_media_contrast.dart';
import 'package:frost_ui/src/surface/_window_background.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

FrostAmbientSample image(int width, int height, Color Function(int x, int y) pixel) => FrostAmbientSample(width, height, [
  for (var y = 0; y < height; y++)
    for (var x = 0; x < width; x++) pixel(x, y),
]);

const _stops = [Color(0xff142463), Color(0xff5b3a9e), Color(0xffc8507a), Color(0xfff27a3c), Color(0xffffc46b), Color(0xff1f7a86), Color(0xff0b3440)];

final _scenes = {
  'photo': image(48, 30, (x, y) => _stops[(y * _stops.length) ~/ 30]),
  'purple': image(48, 30, (_, _) => const Color(0xff7a00ff)),
  'orange': image(48, 30, (_, _) => const Color(0xffff7a00)),
  'clash': image(48, 30, (x, _) => x < 24 ? const Color(0xff7a00ff) : const Color(0xffff7a00)),
};

// A sidebar-and-header window with a card grid in its content area.
const _size = Size(600, 410);
const _cards = [Rect.fromLTRB(180, 120, 370, 250), Rect.fromLTRB(386, 120, 576, 250), Rect.fromLTRB(180, 266, 576, 396)];

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + .05) / (math.min(la, lb) + .05);
}

void main() {
  final tokens = FrostPalettes.pink.darkNeutral;
  _cases(tokens);
}

void _cases(FrostThemeTokens tokens) {
  ({Uint8List bytes, Float32List lab, FrostAmbientGlowBake bake}) baked(FrostAmbientSample sample, List<Rect> cards, {bool free = true}) {
    final model = frostAmbientGlows(tokens, sample.palette, window: true);
    final centres = frostAmbientWindowGlowCentres(model.glows, Size(sample.width.toDouble(), sample.height.toDouble()), Offset.zero & _size);
    final radius = frostAmbientGlowWindowReach * math.sqrt(_size.width * _size.width + _size.height * _size.height);
    final bake = frostAmbientGlowBakeFor(
      tokens,
      model,
      centres,
      _size,
      radius,
      1,
      freeLift: free ? frostAmbientFreeLift(tokens, sample.palette) : null,
      cards: cards,
      window: true,
    );
    final lab = Float32List(bake.width * bake.height * 3);
    return (bytes: frostAmbientBakeGlowField(bake, lab), lab: lab, bake: bake);
  }

  test('the window glows at r 0.80, the detail surround at 0.65', () {
    expect(frostAmbientWindowGlowRatio, .80);
    expect(frostAmbientGlowRatio, .65);
  });

  test('the card-free peak rises to L(surface) − .005 and keeps both inks readable', () {
    final surface = frostBackdropLightness(tokens.surface);
    for (final entry in _scenes.entries) {
      final model = frostAmbientGlows(tokens, entry.value.palette, window: true);
      final free = frostAmbientFreeLift(tokens, entry.value.palette);
      expect(free, greaterThan(model.lift), reason: entry.key);
      for (final peak in frostAmbientGlowPeaks(tokens, entry.value.palette, free: true)) {
        final quantised = Color(peak.toARGB32());
        expect(frostBackdropLightness(quantised), lessThanOrEqualTo(surface - .005 + .001), reason: entry.key);
        for (final ink in [tokens.textPrimary, tokens.textSecondary]) {
          expect(_contrast(Color.alphaBlend(ink, quantised), quantised), greaterThanOrEqualTo(4.5), reason: '${entry.key} $ink');
        }
      }
      // The window's worst background covers the brighter peak.
      final background = entry.value.resolvePalette(tokens, 1).background;
      for (final peak in frostAmbientGlowPeaks(tokens, entry.value.palette, free: true)) {
        expect(background.computeLuminance(), greaterThanOrEqualTo(peak.computeLuminance()), reason: entry.key);
      }
    }
  });

  test('cards keep the lower field beneath them; it rises only away from them', () {
    final surface = frostBackdropLightness(tokens.surface);
    for (final entry in _scenes.entries) {
      final shaped = baked(entry.value, _cards);
      // The same glows at one lift everywhere: what cards keep beneath them.
      final flat = baked(entry.value, const [], free: false);
      final width = shaped.bake.width;
      var freePeak = 0.0;
      for (var y = 0; y < shaped.bake.height; y++) {
        for (var x = 0; x < width; x++) {
          final o = (y * width + x) * 3;
          final p = Offset(x + .5, y + .5);
          if (_cards.any((card) => card.contains(p))) {
            // Exactly the field without cards, so at most L(surface) − .02.
            expect(shaped.lab[o], closeTo(flat.lab[o], 1e-6), reason: '${entry.key} $p');
            expect(shaped.lab[o], lessThanOrEqualTo(surface - .02), reason: '${entry.key} $p');
          } else if (_cards.every((card) => !card.inflate(frostAmbientCardFeather).contains(p))) {
            freePeak = math.max(freePeak, shaped.lab[o]);
          }
        }
      }
      expect(freePeak, greaterThan(flat.lab.reduce(math.max) + .004), reason: '${entry.key} rises away from cards');
      expect(freePeak, lessThanOrEqualTo(surface - .005), reason: entry.key);
    }
  });

  test('contrast holds everywhere, canvas text over the brighter glow included', () {
    for (final entry in _scenes.entries) {
      final (:bytes, :bake, lab: _) = baked(entry.value, _cards);
      for (var y = 0; y < bake.height; y += 2) {
        for (var x = 0; x < bake.width; x += 2) {
          final at = (y * bake.width + x) * 4;
          final c = Color.fromARGB(255, bytes[at], bytes[at + 1], bytes[at + 2]);
          for (final ink in [tokens.textPrimary, tokens.textSecondary]) {
            expect(_contrast(Color.alphaBlend(ink, c), c), greaterThanOrEqualTo(4.5), reason: '${entry.key} ($x, $y)');
          }
        }
      }
    }
  });

  test('no card outline: the field stays smooth across card edges', () {
    for (final entry in _scenes.entries) {
      final (:lab, :bake, bytes: _) = baked(entry.value, _cards);
      (double, double, double) at(int x, int y) {
        final o = (y * bake.width + x) * 3;
        return (lab[o].toDouble(), lab[o + 1].toDouble(), lab[o + 2].toDouble());
      }

      final lines = <List<(int, int)>>[
        for (final card in _cards) ...[
          [for (var x = 0; x < bake.width; x++) (x, card.center.dy.round())],
          [for (var y = 0; y < bake.height; y++) (card.center.dx.round(), y)],
          [for (var x = 0; x < bake.width; x++) (x, card.top.round() + 2)],
        ],
      ];
      for (final line in lines) {
        for (var i = 1; i < line.length; i++) {
          final p = at(line[i - 1].$1, line[i - 1].$2), q = at(line[i].$1, line[i].$2);
          final e = math.sqrt(math.pow(p.$1 - q.$1, 2) + math.pow(p.$2 - q.$2, 2) + math.pow(p.$3 - q.$3, 2));
          // The glow field's smoothness bound per pixel.
          expect(e, lessThanOrEqualTo(.004), reason: '${entry.key} ${line[i]}');
        }
      }
    }
  });

  testWidgets('modules register their window rects, chrome does not', (tester) async {
    var changes = 0;
    final registry = FrostAmbientCardRegistry(() => changes++);
    addTearDown(registry.dispose);
    final offset = ValueNotifier(40.0);
    Widget app() => frostTestApp(
      FrostAmbientCardScope(
        registry: registry,
        child: ValueListenableBuilder(
          valueListenable: offset,
          builder: (context, top, _) => Stack(
            children: [
              Positioned(
                left: 30,
                top: top,
                width: 200,
                height: 120,
                child: const FrostSurface(role: FrostSurfaceRole.module, child: SizedBox.expand()),
              ),
              const Positioned(
                left: 300,
                top: 40,
                width: 200,
                height: 40,
                child: FrostSurface(role: FrostSurfaceRole.chrome, child: SizedBox.expand()),
              ),
            ],
          ),
        ),
      ),
      brightness: Brightness.dark,
    );
    final window = tester.view.physicalSize / tester.view.devicePixelRatio;
    await tester.pumpWidget(app());
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final origin = tester.getTopLeft(find.byType(FrostSurface).first);
    expect(registry.rects(window), [Rect.fromLTWH(origin.dx, origin.dy, 200, 120)]);
    final before = changes;
    // A move without a repaint of the card is still seen after the frame.
    offset.value = 80;
    await tester.pump();
    await tester.pump();
    expect(changes, greaterThan(before));
    expect(registry.rects(window).single.top, origin.dy + 40);
    expect(tester.takeException(), isNull);
  });
  group('what a card registry reports', () {
    Widget host(void Function(FrostAmbientCardRegistry media) read, Widget child) => frostTestApp(
      FrostAmbientBackdropHost(
        image: null,
        child: Builder(
          builder: (context) {
            read(FrostAmbientCardScope.scopeOf(context)!.media!);
            return child;
          },
        ),
      ),
    );

    testWidgets('a hidden page does not count', (tester) async {
      late FrostAmbientCardRegistry media;
      var index = 1;
      late StateSetter update;
      await tester.pumpWidget(
        host(
          (value) => media = value,
          StatefulBuilder(
            builder: (_, set) {
              update = set;
              return FrostLazyIndexedStack(
                index: index,
                sizing: StackFit.expand,
                children: [
                  const SizedBox.shrink(),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: SizedBox(width: 200, child: FrostMediaFrame(aspectRatio: 1, child: const SizedBox.expand())),
                  ),
                ],
              );
            },
          ),
        ),
      );
      await tester.pump();
      const over = Rect.fromLTWH(650, 450, 100, 100);
      expect(media.overlaps(over), isTrue);
      expect(media.rects(const Size(800, 600)), isNotEmpty);
      update(() => index = 0);
      await tester.pump();
      await tester.pump();
      expect(media.overlaps(over), isFalse);
      expect(media.rects(const Size(800, 600)), isEmpty);
    });

    testWidgets('a row in the scroll cache does not count', (tester) async {
      late FrostAmbientCardRegistry media;
      await tester.pumpWidget(
        host(
          (value) => media = value,
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              height: 300,
              width: 150,
              child: ListView.builder(itemExtent: 150, itemCount: 20, itemBuilder: (_, _) => FrostMediaFrame(aspectRatio: 1, child: const SizedBox.expand())),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(media.overlaps(const Rect.fromLTWH(10, 20, 100, 20)), isTrue);
      expect(media.overlaps(const Rect.fromLTWH(10, 320, 100, 20)), isFalse);
      expect(media.rects(const Size(800, 600)).map((rect) => rect.top), [0, 150]);
    });
  });
}
