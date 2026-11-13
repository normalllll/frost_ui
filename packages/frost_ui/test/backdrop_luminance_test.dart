import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/foundation/_ambient_material.dart';
import 'package:frost_ui/src/foundation/_media_contrast.dart';
import 'package:frost_ui/src/foundation/color_math.dart' show colorContrast;
import 'package:material_ui/material_ui.dart';

import 'ambient_material_test.dart' show resolveImage;
import 'media_frame_test.dart' show ControlledImage;
import 'support.dart';

void main() {
  test('dark backdrop bounds cover bright islands, tones, intensities and both inks', () {
    for (final tone in FrostTone.values) {
      final tokens = FrostPalettes.pink.palette(Brightness.dark, tone, FrostPalettes.pink.darkDefaultAccent);
      final limit = frostBackdropLightnessLimit(tokens);
      for (final art in [const Color(0xff102028), const Color(0xff808080), Colors.white, Colors.red, Colors.yellow]) {
        for (final island in [false, true]) {
          final pixels = List.filled(64, art);
          if (island) pixels[0] = Colors.white;
          final sample = FrostAmbientSample(8, 8, pixels);
          for (final intensity in [0.0, .1, .4, 1.0]) {
            final material = sample.resolve(tokens, intensity);
            // The worst background is the card-free glow peak, up to
            // L(surface) − .005; under cards the glow keeps the lightness gap, and the
            // reduced-transparency fill stays within the backdrop lightness limit.
            final card = frostBackdropLightness(tokens.surface) - .005 + .001;
            expect(frostBackdropLightness(material.background), lessThanOrEqualTo(card));
            expect(frostBackdropLightness(Color(material.background.toARGB32())), lessThanOrEqualTo(card));
            for (final peak in frostAmbientGlowPeaks(tokens, sample.palette)) {
              expect(frostBackdropLightness(tokens.surface) - frostBackdropLightness(Color(peak.toARGB32())), greaterThanOrEqualTo(.02 - .002));
            }
            expect(frostBackdropLightness(Color(sample.toned(tokens).solid.toARGB32())), lessThanOrEqualTo(limit));
            for (final ink in [tokens.textPrimary, tokens.textSecondary]) {
              expect(colorContrast(Color.alphaBlend(ink, material.background), material.background), greaterThanOrEqualTo(4.5));
            }
          }
        }
        final media = Color.alphaBlend(frostMediaBackdropBase(tokens).withValues(alpha: frostMediaScrimOpacity(tokens)), art);
        expect(frostBackdropLightness(media), lessThanOrEqualTo(limit));
        expect(frostBackdropLightness(Color(media.toARGB32())), lessThanOrEqualTo(limit));
        expect(frostBackdropLightness(tokens.surface) - frostBackdropLightness(media), greaterThanOrEqualTo(.02));
      }
    }
  });

  for (final tone in FrostTone.values) {
    for (final solid in [false, true]) {
      testWidgets('white artwork raster stays recessed in window and inline media $tone solid=$solid', (tester) async {
        final provider = ControlledImage();
        final key = GlobalKey();
        final theme = FrostTheme.build(
          config: testConfig,
          brightness: Brightness.dark,
          tone: tone,
          platform: TargetPlatform.windows,
          locale: const Locale('en'),
        );
        await tester.pumpWidget(
          frostTestApp(
            Theme(
              data: theme,
              child: Center(
                child: SizedBox(
                  width: 540,
                  height: 120,
                  child: RepaintBoundary(
                    key: key,
                    child: FrostAmbientBackdropHost(
                      image: provider,
                      child: Row(
                        children: [
                          const Expanded(
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: SizedBox(
                                width: 140,
                                height: 40,
                                child: FrostSurface(role: FrostSurfaceRole.reading, elevated: false, child: SizedBox.expand()),
                              ),
                            ),
                          ),
                          Expanded(
                            child: FrostAmbientBackdrop.fromImage(image: provider, child: const SizedBox.expand()),
                          ),
                          const Expanded(
                            child: FrostSurface(role: FrostSurfaceRole.panel, elevated: false, child: SizedBox.expand()),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            brightness: Brightness.dark,
            reduceTransparency: solid,
          ),
        );
        await resolveImage(tester, provider, Colors.white);
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = (await tester.runAsync(() => boundary.toImage()))!;
        final bytes = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
        final tokens = theme.extension<FrostThemeTokens>()!;
        final values = <double>[];
        for (final x in [40, 220, 400]) {
          final at = (80 * image.width + x) * 4;
          final pixel = Color.fromARGB(bytes.getUint8(at + 3), bytes.getUint8(at), bytes.getUint8(at + 1), bytes.getUint8(at + 2));
          final lightness = frostBackdropLightness(pixel);
          values.add(lightness);
          if (x != 400) {
            // A GPU blend may round a final channel one step differently from
            // the float solver; the actual surface gap remains mandatory.
            expect(lightness, lessThanOrEqualTo(frostBackdropLightnessLimit(tokens) + 1 / 255));
            expect(frostBackdropLightness(tokens.surface) - lightness, greaterThanOrEqualTo(.02));
          }
          expect(colorContrast(Color.alphaBlend(tokens.textSecondary, pixel), pixel), greaterThanOrEqualTo(6.43));
        }
        expect(values[2], greaterThan(values[0]), reason: 'Glass panel must remain above canvas');
        image.dispose();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
