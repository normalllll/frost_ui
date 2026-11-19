import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/foundation/_glass_material.dart' show frostDarkContentLayer;
import 'package:material_ui/material_ui.dart';

import 'ambient_material_test.dart' show settleGlow;
import 'ambient_transition_test.dart' show complete;
import 'media_frame_test.dart' show ControlledImage;
import 'support.dart';

enum _Material { off, ambient, mica }

final _window = GlobalKey();
const _sidebar = Offset(120, 420), _content = Offset(760, 420);

Future<FrostThemeTokens> _shell(WidgetTester tester, {required Brightness brightness, required FrostTone tone, required _Material material}) async {
  tester.view.physicalSize = const Size(1147, 717);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final art = ControlledImage();
  Widget shell = FrostShell(
    destinations: const [
      FrostNavDestination(icon: FrostIconData.glyph(Icons.home), label: 'Home'),
      FrostNavDestination(icon: FrostIconData.glyph(Icons.search), label: 'Find'),
    ],
    selectedIndex: 0,
    atDestinationRoot: true,
    onDestinationSelected: (_) {},
    canGoBack: false,
    onBack: () {},
    showsMobileNavigation: false,
    child: const SizedBox.expand(),
  );
  if (material == _Material.ambient) shell = FrostAmbientBackdropHost(image: art, child: shell);
  if (material == _Material.mica) shell = FrostWindowCaptionScope(systemBackdropActive: true, child: shell);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _window,
      child: FrostScope(
        config: testConfig,
        child: MaterialApp(
          theme: FrostTheme.build(config: testConfig, brightness: brightness, tone: tone, platform: TargetPlatform.windows, locale: const Locale('en')),
          home: shell,
        ),
      ),
    ),
  );
  if (material == _Material.ambient) {
    await complete(tester, art, const Color(0xFF8E6BB0));
    await settleGlow(tester);
  } else {
    await tester.pumpAndSettle();
  }
  return FrostThemeTokens.of(tester.element(find.byType(FrostShell)));
}

Future<Color> _pixel(WidgetTester tester, Offset point) async {
  final render = _window.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = (await tester.runAsync(() => render.toImage()))!;
  final bytes = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
  final offset = (point.dy.toInt() * image.width + point.dx.toInt()) * 4;
  image.dispose();
  return Color.fromARGB(255, bytes.getUint8(offset), bytes.getUint8(offset + 1), bytes.getUint8(offset + 2));
}

// One 8-bit step of rounding in the captured pixels.
const _rounding = .002;

void main() {
  for (final tone in FrostTone.values) {
    for (final material in [_Material.off, _Material.ambient]) {
      testWidgets('dark content is no lighter than the sidebar or the canvas, $tone, material ${material.name}', (tester) async {
        final tokens = await _shell(tester, brightness: Brightness.dark, tone: tone, material: material);
        final sidebar = (await _pixel(tester, _sidebar)).computeLuminance();
        final content = (await _pixel(tester, _content)).computeLuminance();
        expect(content, lessThanOrEqualTo(sidebar + _rounding));
        expect(content, lessThanOrEqualTo(tokens.canvas.computeLuminance() + _rounding));
      });
    }

    test('over a dark system backdrop the content layer keeps it no lighter than the canvas, $tone', () {
      final canvas = FrostPalettes.pink.palette(Brightness.dark, tone, const Color(0xFFE5484D)).canvas;
      final layer = frostDarkContentLayer(canvas, null);
      expect(layer.a, greaterThan(0));
      expect(Color.alphaBlend(layer, const Color(0xFF2C2C2C)).computeLuminance(), lessThanOrEqualTo(canvas.computeLuminance()));
      expect(frostDarkContentLayer(canvas, canvas).a, 0, reason: 'a window already as dark as the canvas needs no layer');
    });
  }

  testWidgets('under Mica the dark content panel paints the darkening layer and a hairline edge', (tester) async {
    final tokens = await _shell(tester, brightness: Brightness.dark, tone: FrostTone.neutral, material: _Material.mica);
    final panel = find.byWidgetPredicate((widget) => widget is FrostSurface && widget.role == FrostSurfaceRole.panel);
    final fill = tester
        .widgetList<DecoratedBox>(find.descendant(of: panel, matching: find.byType(DecoratedBox)))
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .map((box) => box.color)
        .whereType<Color>()
        .first;
    expect(fill, frostDarkContentLayer(tokens.canvas, null));
    final edge = find.descendant(of: panel, matching: find.byWidgetPredicate((widget) => widget is CustomPaint && widget.foregroundPainter != null)).first;
    expect(edge, paints..path(color: tokens.edgeHairline));
  });

  testWidgets('light content keeps its surface', (tester) async {
    final tokens = await _shell(tester, brightness: Brightness.light, tone: FrostTone.neutral, material: _Material.off);
    expect(await _pixel(tester, _content), tokens.surface.withValues(alpha: 1));
  });
}
