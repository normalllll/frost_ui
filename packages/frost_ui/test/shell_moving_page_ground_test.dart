import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'ambient_material_test.dart' show settleGlow;
import 'ambient_transition_test.dart' show complete;
import 'media_frame_test.dart' show ControlledImage;
import 'support.dart';

final _paint = find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_AmbientPaint');
final _window = GlobalKey();

/// The shell under an ambient host. With [artShown] the art has arrived and
/// faded in before any page moves; without it, it has not arrived yet.
Future<GlobalKey<NavigatorState>> _app(
  WidgetTester tester, {
  required Size size,
  required TargetPlatform platform,
  Brightness brightness = Brightness.dark,
  bool artShown = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final navigator = GlobalKey<NavigatorState>();
  final art = ControlledImage();
  await tester.pumpWidget(
    RepaintBoundary(
      key: _window,
      child: frostTestApp(
        FrostAmbientBackdropHost(
          image: art,
          child: FrostShell(
            destinations: const [
              FrostNavDestination(icon: FrostIconData.glyph(Icons.home), label: 'Home'),
              FrostNavDestination(icon: FrostIconData.glyph(Icons.search), label: 'Find'),
            ],
            selectedIndex: 0,
            atDestinationRoot: true,
            onDestinationSelected: (_) {},
            canGoBack: false,
            onBack: () {},
            showsMobileNavigation: true,
            child: FrostShellDestination(
              child: Navigator(
                key: navigator,
                onGenerateRoute: (_) => PageRouteBuilder<void>(pageBuilder: (_, _, _) => const SizedBox.expand()),
              ),
            ),
          ),
        ),
        brightness: brightness,
        platform: platform,
      ),
    ),
  );
  await complete(tester, art, Colors.purple);
  if (artShown) {
    await settleGlow(tester);
  } else {
    await tester.pumpAndSettle();
  }
  return navigator;
}

Route<void> _page(GlobalKey<NavigatorState> navigator, {required bool media}) =>
    (media ? const FrostDetailPage<void>.media(child: SizedBox.expand()) : const FrostDetailPage<void>(child: SizedBox.expand())).createRoute(
      navigator.currentContext!,
    );

/// Ambient art painted inside the shell's navigator, under a moving page.
Finder _artIn(GlobalKey<NavigatorState> navigator) => find.descendant(of: find.byKey(navigator), matching: _paint);

/// The fill the shell's pages rest on, painted inside its navigator.
Finder _restingFillIn(WidgetTester tester, GlobalKey<NavigatorState> navigator) {
  final fill = FrostSurfaceScope.maybeOf(tester.element(find.byKey(navigator)))!.background;
  return find.descendant(
    of: find.byKey(navigator),
    matching: find.byWidgetPredicate((widget) => widget is ColoredBox && widget.color.a > 0 && widget.color.withValues(alpha: 1) == fill),
  );
}

Future<List<int>> _pixel(WidgetTester tester, Offset point) async {
  final render = _window.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = (await tester.runAsync(() => render.toImage()))!;
  final bytes = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
  final offset = (point.dy.toInt() * image.width + point.dx.toInt()) * 4;
  image.dispose();
  return [for (var channel = 0; channel < 3; channel++) bytes.getUint8(offset + channel)];
}

Matcher _closeTo(List<int> expected) => predicate<List<int>>(
  (actual) => [for (var channel = 0; channel < 3; channel++) (actual[channel] - expected[channel]).abs()].every((difference) => difference <= 3),
  'within 3 per channel of $expected',
);

void main() {
  for (final (layout, size) in [('the compact shell', const Size(400, 800)), ('the sidebar layout', const Size(1147, 717))]) {
    for (final media in [false, true]) {
      final kind = media ? 'media' : 'ordinary';
      testWidgets('in $layout a moving $kind page carries the fill it rests on', (tester) async {
        final navigator = await _app(tester, size: size, platform: media ? TargetPlatform.android : TargetPlatform.windows);
        expect(find.byType(FrostNavItem), size.width > 600 ? findsWidgets : findsNothing);
        navigator.currentState!.push(_page(navigator, media: media));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        expect(_artIn(navigator), findsNothing, reason: 'pushing in');
        expect(_restingFillIn(tester, navigator), findsWidgets);
        await tester.pumpAndSettle();
        expect(_artIn(navigator), findsNothing, reason: 'at rest');

        navigator.currentState!.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        expect(_artIn(navigator), findsNothing, reason: 'popping');
        expect(_restingFillIn(tester, navigator), findsWidgets);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final brightness in Brightness.values) {
    for (final media in [false, true]) {
      final kind = media ? 'media' : 'ordinary';
      testWidgets('beside a sidebar over shown art a moving $kind page shows the panel as it rests, $brightness', (tester) async {
        final navigator = await _app(
          tester,
          size: const Size(1147, 717),
          platform: media ? TargetPlatform.android : TargetPlatform.windows,
          brightness: brightness,
          artShown: true,
        );
        // A point of the content panel where the art tints it.
        const point = Offset(600, 300);
        final rest = await _pixel(tester, point);
        final route = _page(navigator, media: media) as ModalRoute<void>;
        // A media page dims the page below midway, by design; its ground
        // covers that dim from halfway on.
        bool groundOnly() => !media || route.animation!.value >= .5;
        var compared = 0;
        Future<void> compare(String phase) async {
          if (!groundOnly()) return;
          compared++;
          expect(await _pixel(tester, point), _closeTo(rest), reason: '$phase at ${route.animation!.value}');
        }

        navigator.currentState!.push(route);
        await tester.pump();
        for (var frame = 0; frame < 8; frame++) {
          await tester.pump(const Duration(milliseconds: 30));
          await compare('pushing in');
        }
        await settleGlow(tester);
        expect(await _pixel(tester, point), _closeTo(rest), reason: 'settled');

        navigator.currentState!.pop();
        await tester.pump();
        for (var frame = 0; frame < 4; frame++) {
          await tester.pump(const Duration(milliseconds: 30));
          await compare('popping');
        }
        expect(compared, greaterThanOrEqualTo(4), reason: 'frames of both moves were compared');
        await settleGlow(tester);
        expect(await _pixel(tester, point), _closeTo(rest));
      });
    }
  }
}
