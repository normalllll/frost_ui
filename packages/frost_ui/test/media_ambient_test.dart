import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/foundation/_ambient_material.dart';
import 'package:frost_ui/src/foundation/_media_contrast.dart';
import 'package:frost_ui/src/foundation/color_math.dart' show colorContrast;
import 'package:material_ui/material_ui.dart';

import 'support.dart';

class _CountedImage extends ImageProvider<_CountedImage> {
  _CountedImage(this.bytes);
  final Uint8List bytes;
  var loads = 0;
  Size? decodedSize;
  @override
  Future<_CountedImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(_CountedImage key, ImageDecoderCallback decode) {
    loads++;
    return OneFrameImageStreamCompleter(_load(decode));
  }

  Future<ImageInfo> _load(ImageDecoderCallback decode) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final codec = await decode(buffer);
    try {
      final frame = await codec.getNextFrame();
      decodedSize = Size(frame.image.width.toDouble(), frame.image.height.toDouble());
      return ImageInfo(image: frame.image);
    } finally {
      codec.dispose();
    }
  }
}

Future<_CountedImage> _solid(WidgetTester tester, Color color) async => (await tester.runAsync(() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 32, 32), Paint()..color = color);
  final picture = recorder.endRecording();
  final image = await picture.toImage(32, 32);
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  image.dispose();
  picture.dispose();
  return _CountedImage(bytes);
}))!;
Future<void> settleImage(WidgetTester tester) async {
  for (var index = 0; index < 5; index++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
  await tester.pump(FrostMotion.reveal);
}

Finder get ambient => find.byType(FrostAmbientBackdrop);
Color opaqueBackground(WidgetTester tester) => tester.widgetList<ColoredBox>(find.descendant(of: ambient, matching: find.byType(ColoredBox))).single.color;

void main() {
  test('all six palettes, brightnesses and tones meet worst-case media contrast', () {
    final palettes = FrostPalettes.pink;
    for (final accent in palettes.accentPresets) {
      for (final brightness in Brightness.values) {
        for (final tone in FrostTone.values) {
          final tokens = palettes.palette(brightness, tone, accent);
          final opacity = frostMediaScrimOpacity(tokens);
          expect(opacity, greaterThanOrEqualTo(tokens.isDark ? .88 : .6));
          final worst = tokens.isDark ? Colors.white : Colors.black;
          final background = Color.alphaBlend(frostMediaBackdropBase(tokens).withValues(alpha: opacity), worst);
          expect(colorContrast(tokens.textPrimary, background), greaterThanOrEqualTo(4.5));
          expect(colorContrast(tokens.textPrimary, Color(background.toARGB32())), greaterThanOrEqualTo(4.5));
          expect(frostMediaScrimOpacity(tokens), opacity);
        }
      }
    }
  });
  testWidgets('media ambient paints the palette over canvas and cross-fades sources', (tester) async {
    final first = await _solid(tester, Colors.red), second = await _solid(tester, Colors.blue);
    late StateSetter update;
    ImageProvider provider = first;
    final key = GlobalKey();
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: 300,
              height: 200,
              child: StatefulBuilder(
                builder: (_, set) {
                  update = set;
                  return FrostAmbientBackdrop.fromImage(image: provider, child: const Text('Foreground'));
                },
              ),
            ),
          ),
        ),
      ),
    );
    await settleImage(tester);
    await tester.pumpAndSettle();
    // No blurred texture, no filter and no surface scrim: palette gradients only.
    expect(find.byType(RawImage), findsNothing);
    expect(find.byType(ImageFiltered), findsNothing);
    expect(find.descendant(of: ambient, matching: find.byType(ColoredBox)), findsNothing);
    final red = await _pixel(tester, key, const Offset(150, 100));
    expect(red.r, greaterThan(red.b));
    update(() => provider = second);
    await tester.pump();
    expect(await _pixel(tester, key, const Offset(150, 100)), red);
    await settleImage(tester);
    final tokens = FrostThemeTokens.of(tester.element(ambient));
    await tester.pumpAndSettle();
    final blue = await _pixel(tester, key, const Offset(150, 100));
    expect(blue.b, greaterThan(blue.r));
    expect(colorContrast(tokens.textSecondary, blue), greaterThanOrEqualTo(4.5));
    expect(find.text('Foreground'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    for (final color in [Colors.white, Colors.black, Colors.red]) {
      testWidgets('opaque palette mean passes text contrast $brightness $color', (tester) async {
        final provider = await _solid(tester, color);
        await tester.pumpWidget(
          frostTestApp(
            SizedBox(
              width: 300,
              height: 200,
              child: FrostAmbientBackdrop.fromImage(image: provider, child: const SizedBox()),
            ),
            brightness: brightness,
            reduceTransparency: true,
          ),
        );
        final tokens = FrostThemeTokens.of(tester.element(ambient));
        expect(opaqueBackground(tester).toARGB32(), tokens.canvas.toARGB32());
        await settleImage(tester);
        await tester.pumpAndSettle();
        final background = opaqueBackground(tester);
        final expected = FrostAmbientSample(1, 1, [color]).toned(tokens).solid;
        for (final (actual, wanted) in [(background.r, expected.r), (background.g, expected.g), (background.b, expected.b)]) {
          expect(actual, closeTo(wanted, 2.5 / 255));
        }
        expect(background.a, 1);
        for (final ink in [tokens.textPrimary, tokens.textSecondary]) {
          expect(colorContrast(Color.alphaBlend(ink, background), background), greaterThanOrEqualTo(4.5));
        }
        expect(find.byType(ImageFiltered), findsNothing);
        expect(find.byType(BackdropFilter), findsNothing);
        expect(find.byType(RawImage), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('palette cache survives theme changes and remounts without decoding again', (tester) async {
    final provider = await _solid(tester, Colors.white);
    for (final brightness in [Brightness.light, Brightness.dark, Brightness.light]) {
      await tester.pumpWidget(
        frostTestApp(
          FrostAmbientBackdrop.fromImage(image: provider, child: const SizedBox()),
          brightness: brightness,
          reduceTransparency: true,
        ),
      );
      await settleImage(tester);
      await tester.pumpAndSettle();
      expect(provider.loads, 1);
      final tokens = FrostThemeTokens.of(tester.element(ambient));
      expect(colorContrast(tokens.textPrimary, opaqueBackground(tester)), greaterThanOrEqualTo(4.5));
      await tester.pumpWidget(const SizedBox());
    }
  });
  testWidgets('opaque fill transitions from canvas to the palette while foreground stays opaque', (tester) async {
    final provider = await _solid(tester, Colors.red);
    await tester.pumpWidget(frostTestApp(FrostAmbientBackdrop.fromImage(image: provider, child: const Text('Opaque foreground')), reduceTransparency: true));
    final before = opaqueBackground(tester);
    for (var index = 0; index < 5; index++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    await tester.pump(FrostMotion.reveal ~/ 2);
    final middle = opaqueBackground(tester);
    await tester.pumpAndSettle();
    final after = opaqueBackground(tester);
    expect(middle, isNot(before));
    expect(middle, isNot(after));
    expect(
      find.descendant(
        of: ambient,
        matching: find.ancestor(of: find.text('Opaque foreground'), matching: find.byType(Opacity)),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('palette is reused while the page moves and resizes without decoding its source again', (tester) async {
    final provider = await _solid(tester, Colors.red);
    late StateSetter update;
    var width = 200.0, shift = 0.0;
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (_, set) {
            update = set;
            return Center(
              child: Transform.translate(
                offset: Offset(shift, 0),
                child: SizedBox(
                  width: width,
                  height: 200,
                  child: FrostAmbientBackdrop.fromImage(image: provider, child: const Text('Foreground')),
                ),
              ),
            );
          },
        ),
      ),
    );
    await settleImage(tester);
    for (var index = 1; index <= 10; index++) {
      update(() => shift = index.toDouble());
      await tester.pump(const Duration(milliseconds: 8));
    }
    update(() => width = 100);
    await tester.pump();
    await settleImage(tester);
    expect(provider.loads, 1);
    expect(find.byType(ImageFiltered), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('two-colour media extends each colour on its own side', (tester) async {
    final provider = (await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 32, 64), Paint()..color = Colors.red);
      canvas.drawRect(const Rect.fromLTWH(32, 0, 32, 64), Paint()..color = Colors.blue);
      final picture = recorder.endRecording();
      final image = await picture.toImage(64, 64);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      image.dispose();
      picture.dispose();
      return _CountedImage(bytes);
    }))!;
    final key = GlobalKey();
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        frostTestApp(
          Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 400,
                height: 200,
                child: FrostAmbientBackdrop.fromImage(image: provider, child: const SizedBox()),
              ),
            ),
          ),
          brightness: brightness,
        ),
      );
      await settleImage(tester);
      // Dark bakes its glow field on another isolate and fades it in on the
      // wall clock.
      for (var i = 0; i < 30; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
      final left = await _pixel(tester, key, const Offset(30, 100)), right = await _pixel(tester, key, const Offset(370, 100));
      expect(left.r, greaterThan(left.b), reason: '$brightness');
      expect(right.b, greaterThan(right.r), reason: '$brightness');
    }
  });

  testWidgets('zero-sized and removed backdrops do not publish late prepared images', (tester) async {
    final provider = await _solid(tester, Colors.red);
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: SizedBox.shrink(
            child: FrostAmbientBackdrop.fromImage(image: provider, child: const SizedBox()),
          ),
        ),
      ),
    );
    await settleImage(tester);
    expect(provider.loads, 0);
    await tester.pumpWidget(frostTestApp(FrostAmbientBackdrop.fromImage(image: provider, child: const SizedBox())));
    await tester.pumpWidget(const SizedBox());
    await settleImage(tester);
    expect(tester.takeException(), isNull);
  });
}

Future<Color> _pixel(WidgetTester tester, GlobalKey key, Offset point) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = (await tester.runAsync(() => boundary.toImage()))!;
  final bytes = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
  final at = (point.dy.round() * image.width + point.dx.round()) * 4;
  image.dispose();
  return Color.fromARGB(255, bytes.getUint8(at), bytes.getUint8(at + 1), bytes.getUint8(at + 2));
}
