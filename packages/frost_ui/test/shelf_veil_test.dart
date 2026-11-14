import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/primitives/_scroll_edge_fade.dart';
import 'package:frost_ui/src/surface/_backdrop_veil.dart';

import 'support.dart';

const _home = FrostIconData.glyph(IconData(0xe101));
const _tile = Color(0xFFFF0000);

Widget _shelf() => FrostShelf(
  title: 'Shelf',
  itemCount: 10,
  itemExtent: 100,
  spacing: 0,
  inset: 0,
  height: 100,
  itemBuilder: (_, _) => const ColoredBox(color: _tile),
);

/// A phone shell whose root page holds [shelf] in a vertical list.
Widget _phone(Widget shelf, {ScrollController? controller, Widget Function(Widget page)? around}) {
  final page = ListView(controller: controller, children: [shelf, const SizedBox(height: 2000)]);
  return frostTestApp(
    FrostShell(
      destinations: [
        FrostNavDestination(icon: _home, label: 'Home'),
        FrostNavDestination(icon: _home, label: 'Library'),
      ],
      selectedIndex: 0,
      atDestinationRoot: true,
      onDestinationSelected: (_) {},
      canGoBack: false,
      onBack: () {},
      showsMobileNavigation: true,
      child: FrostShellDestination(child: around?.call(page) ?? page),
    ),
    platform: TargetPlatform.android,
  );
}

void _window(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Iterable<ShaderMaskLayer> _masks(WidgetTester tester) => tester.layers.whereType<ShaderMaskLayer>();

Future<List<Color>> _pixels(WidgetTester tester, Finder boundary, List<Offset> points) async => (await tester.runAsync(() async {
  final box = tester.renderObject<RenderRepaintBoundary>(boundary);
  final image = await box.toImage(pixelRatio: 1);
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final colors = [
    for (final point in points)
      () {
        final at = (point.dy.round() * image.width + point.dx.round()) * 4;
        return Color.fromARGB(bytes.getUint8(at + 3), bytes.getUint8(at), bytes.getUint8(at + 1), bytes.getUint8(at + 2));
      }(),
  ];
  image.dispose();
  return colors;
}))!;

double _distance(Color a, Color b) => [(a.r - b.r).abs(), (a.g - b.g).abs(), (a.b - b.b).abs()].reduce((x, y) => x > y ? x : y);

void main() {
  testWidgets('on the phone canvas a shelf fades into it with no layer, also while the page scrolls', (tester) async {
    _window(tester);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_phone(_shelf(), controller: controller));
    await tester.pumpAndSettle();
    expect(find.byType(FrostShelf), findsOneWidget);
    expect(_masks(tester), isEmpty);
    controller.jumpTo(10);
    await tester.pump();
    expect(_masks(tester), isEmpty);

    // The trailing edge hides tiles: its last pixels show the canvas, its
    // start the tiles; the leading edge hides nothing.
    final canvas = FrostThemeTokens.of(tester.element(find.byType(FrostShelf))).canvas;
    final strip = tester.getRect(find.descendant(of: find.byType(FrostShelf), matching: find.byType(FrostEdgeFadeMask)));
    final y = strip.center.dy;
    final pixels = await _pixels(tester, find.byType(RepaintBoundary).first, [
      Offset(strip.left + 1, y),
      Offset(strip.right - 25, y),
      Offset(strip.right - 1, y),
    ]);
    expect(_distance(pixels[0], _tile), lessThan(.02));
    expect(_distance(pixels[1], _tile), lessThan(.06));
    expect(_distance(pixels[2], canvas), lessThan(.08));
  });

  testWidgets('under the ambient host a shelf on the window fades with no layer', (tester) async {
    _window(tester);
    await tester.pumpWidget(
      frostTestApp(
        FrostAmbientBackdropHost(image: null, intensity: 1, child: ListView(children: [_shelf()])),
        platform: TargetPlatform.android,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FrostShelf), findsOneWidget);
    expect(_masks(tester), isEmpty);
  });

  testWidgets('on glass a shelf masks its edges', (tester) async {
    _window(tester);
    await tester.pumpWidget(
      _phone(
        _shelf(),
        around: (page) => FrostSurface(role: FrostSurfaceRole.glassPanel, child: page),
      ),
    );
    await tester.pumpAndSettle();
    expect(_masks(tester), isNotEmpty);
  });

  testWidgets('a shaded strip carries linear coverage across it', (tester) async {
    final key = GlobalKey();
    final image = await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 4, 4), Paint()..color = const Color(0xFF0000FF));
      return recorder.endRecording().toImage(4, 4);
    });
    addTearDown(image!.dispose);
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          key: key,
          child: CustomPaint(size: const Size(100, 10), painter: _StripPainter(image)),
        ),
      ),
    );
    final pixels = await _pixels(tester, find.byKey(key), const [Offset(1, 5), Offset(50, 5), Offset(98, 5)]);
    // Blue at the opaque end, white at the clear end, half way between.
    expect(pixels[0].r, lessThan(.05));
    expect(pixels[1].b, greaterThan(.95));
    expect(pixels[1].r, closeTo(.5, .06));
    expect(pixels[2].r, greaterThan(.95));
  });
}

class _StripPainter extends CustomPainter {
  _StripPainter(this.image);
  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    final strip = Offset.zero & size;
    canvas.drawRect(strip, Paint()..color = const Color(0xFFFFFFFF));
    FrostBackdropVeil.drawShaded(
      canvas,
      strip,
      strip.centerLeft,
      strip.centerRight,
      ImageShader(image, TileMode.repeated, TileMode.repeated, Matrix4.identity().storage),
    );
  }

  @override
  bool shouldRepaint(_StripPainter oldDelegate) => false;
}
