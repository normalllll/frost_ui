import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/primitives/_state_button.dart' show FrostStateButton;
import 'package:material_ui/material_ui.dart';

import 'support.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('select idle rows reveal the clean menu surface: $brightness', (tester) async {
      final boundaryKey = GlobalKey();
      final theme = FrostTheme.build(config: testConfig, brightness: brightness, platform: TargetPlatform.windows, locale: const Locale('en'));
      final tokens = theme.extension<FrostThemeTokens>()!;
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: FrostScope(
            config: testConfig,
            reduceTransparency: true,
            child: MaterialApp(
              theme: theme,
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 320,
                    child: FrostPicker<int>.menu(
                      value: 1,
                      options: const [
                        FrostPickerOption(value: 1, label: 'One'),
                        FrostPickerOption(value: 2, label: 'Two'),
                      ],
                      onChanged: (_) {},
                      label: 'Choice',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(FrostPicker<int>));
      await tester.pumpAndSettle();
      final idleRow = find.ancestor(of: find.text('Two'), matching: find.byType(FrostStateButton));
      final material = tester.widget<FrostStateButton>(idleRow);
      // Assert the resting fill of the actual button.
      expect(material.fill({}).a, 0);
      final sample = tester.getRect(idleRow).centerRight - const Offset(2, 0);
      Future<Color> paintedPixel() async {
        final boundary = boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        final offset = (sample.dy.floor() * image.width + sample.dx.floor()) * 4;
        final colour = Color.fromARGB(bytes.getUint8(offset + 3), bytes.getUint8(offset), bytes.getUint8(offset + 1), bytes.getUint8(offset + 2));
        image.dispose();
        return colour;
      }

      expect((await tester.runAsync(paintedPixel))!.toARGB32(), tokens.surfaceRaised.toARGB32());
      final selectedRow = find.ancestor(of: find.text('One').last, matching: find.byType(FrostStateButton));
      final selectedMaterial = tester.widget<FrostStateButton>(selectedRow);
      expect(selectedMaterial.fill({}).a, 0);
      expect(tester.renderObject<RenderParagraph>(find.text('One').last).text.style!.color, tokens.textPrimary);
      expect(tester.takeException(), isNull);
    });
  }
}
