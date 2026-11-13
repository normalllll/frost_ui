import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/foundation/color_math.dart' show colorContrast;
import 'package:material_ui/material_ui.dart';

import 'ambient_material_test.dart' show resolveImage;
import 'media_frame_test.dart' show ControlledImage;
import 'support.dart';

List<int> rgb(Color c) => [(c.r * 255).round(), (c.g * 255).round(), (c.b * 255).round()];
int distance(Color a, Color b) => List.generate(3, (i) => (rgb(a)[i] - rgb(b)[i]).abs()).reduce((a, b) => a + b);

void main() {
  for (final brightness in Brightness.values) {
    for (final artwork in [false, true]) {
      testWidgets('actual ambient pixels decrease toward canvas at 100 40 10 percent $brightness artwork=$artwork', (tester) async {
        tester.view.physicalSize = const Size(320, 240);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final image = artwork ? ControlledImage() : null;
        final key = GlobalKey();
        var intensity = 1.0;
        late StateSetter update;
        await tester.pumpWidget(
          frostTestApp(
            StatefulBuilder(
              builder: (_, set) {
                update = set;
                return RepaintBoundary(
                  key: key,
                  child: FrostAmbientBackdropHost(
                    image: image,
                    fallback: FrostAmbientFallback.accentWash,
                    intensity: intensity,
                    child: const SizedBox.expand(),
                  ),
                );
              },
            ),
            brightness: brightness,
          ),
        );
        if (image != null) {
          await resolveImage(tester, image, const Color(0xff245898));
        } else {
          await tester.pumpAndSettle();
        }
        Future<Color> pixel() async {
          final render = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final picture = (await tester.runAsync(() => render.toImage()))!;
          final data = (await tester.runAsync(() => picture.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
          final at = (160 * picture.width + 32) * 4;
          final color = Color.fromARGB(data.getUint8(at + 3), data.getUint8(at), data.getUint8(at + 1), data.getUint8(at + 2));
          picture.dispose();
          return color;
        }

        final samples = <double, Color>{};
        for (final value in [1.0, .4, .1, 0.0]) {
          update(() => intensity = value);
          await tester.pumpAndSettle();
          samples[value] = await pixel();
        }
        final canvas = samples[0]!;
        debugPrint('$brightness artwork=$artwork: ${samples.map((k, v) => MapEntry(k, rgb(v)))}');
        expect(distance(samples[1]!, canvas), greaterThanOrEqualTo(distance(samples[.4]!, canvas)));
        expect(distance(samples[.4]!, canvas), greaterThanOrEqualTo(distance(samples[.1]!, canvas)));
        // Dark artwork has a bounded tint range below surface. Keep the
        // 60% slider response within three RGB rounding steps, rather than
        // requiring an absolute delta that would exceed that lightness cap.
        final fullRange = distance(samples[1]!, canvas);
        final minimumChange = brightness == Brightness.dark ? (fullRange * .6).floor() - 3 : (artwork ? 15 : 3);
        expect(distance(samples[1]!, samples[.4]!), greaterThanOrEqualTo(minimumChange));
        final tokens = FrostThemeTokens.of(tester.element(find.byType(FrostAmbientBackdropHost)));
        for (final color in samples.values) {
          for (final ink in [tokens.textPrimary, tokens.textSecondary]) {
            expect(colorContrast(ink, color), greaterThanOrEqualTo(4.5));
          }
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
