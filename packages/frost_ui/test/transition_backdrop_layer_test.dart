import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';
import 'package:frost_ui/src/surface/ambient_backdrop.dart' show FrostFadingAmbientBackdrop;
import 'package:material_ui/material_ui.dart';

import 'support.dart';

bool _underOpacityLayer(RenderObject render) {
  for (RenderObject? node = render.parent; node != null; node = node.parent) {
    if (node.debugLayer is OpacityLayer) return true;
  }
  return false;
}

final _paint = find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_AmbientPaint');

int _saveLayers(RenderObject render) {
  final canvas = TestRecordingCanvas();
  render.paint(TestRecordingPaintingContext(canvas), Offset.zero);
  return canvas.invocations.where((call) => call.invocation.memberName == #saveLayer).length;
}

Future<GlobalKey<NavigatorState>> _app(WidgetTester tester, TargetPlatform platform, bool reduceTransparency) async {
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    frostTestApp(
      FrostAmbientBackdropHost(
        image: null,
        child: Navigator(key: navigator, onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const SizedBox.expand())),
      ),
      platform: platform,
      reduceTransparency: reduceTransparency,
    ),
  );
  await tester.pumpAndSettle();
  return navigator;
}

void main() {
  for (final reduceTransparency in [false, true]) {
    testWidgets('a pointer page fades its content in an opacity layer and its backdrop by alpha (reduce transparency $reduceTransparency)', (tester) async {
      final navigator = await _app(tester, TargetPlatform.windows, reduceTransparency);
      final content = GlobalKey();
      navigator.currentState!.push(FrostDetailPage<void>(child: SizedBox.expand(key: content)).createRoute(navigator.currentContext!));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final backdrop = tester.renderObject(find.descendant(of: find.byType(FrostFadingAmbientBackdrop), matching: _paint));
      expect(_underOpacityLayer(backdrop), isFalse, reason: 'the window-sized backdrop is not composited through an opacity layer');
      expect(_saveLayers(backdrop), 0, reason: 'it fades by its own alpha');
      expect(_underOpacityLayer(tester.renderObject(find.byKey(content))), isTrue, reason: 'the page content still fades as a whole');
      await tester.pumpAndSettle();
      expect(find.byType(FrostFadingAmbientBackdrop), findsNothing, reason: 'a settled page leaves the backdrop to the window');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a media page that fills the window dips through its backdrop with no opacity layer (reduce transparency $reduceTransparency)', (tester) async {
      final navigator = await _app(tester, TargetPlatform.android, reduceTransparency);
      final content = GlobalKey();
      final page = FrostDetailPage<void>.media(
        child: Column(
          key: content,
          children: const [
            AspectRatio(aspectRatio: 1.6, child: ColoredBox(color: Color(0xFF404040))),
            Expanded(child: ColoredBox(color: Color(0xFF101010))),
          ],
        ),
      );
      var hidden = 0, veiled = 0;
      Future<void> watch() async {
        for (var frame = 0; frame < 60 && find.byType(FrostFadingAmbientBackdrop).evaluate().isNotEmpty; frame++) {
          expect(_underOpacityLayer(tester.renderObject(find.byKey(content))), isFalse, reason: 'content that fills the window takes no opacity pass');
          for (final backdrop in tester.renderObjectList(find.descendant(of: find.byType(FrostFadingAmbientBackdrop), matching: _paint))) {
            expect(_underOpacityLayer(backdrop), isFalse);
            expect(_saveLayers(backdrop), 0);
          }
          final reveal = tester.widget<FrostMaterialReveal>(find.ancestor(of: find.byKey(content), matching: find.byType(FrostMaterialReveal)).first);
          if (reveal.opacity == 0) hidden++;
          if (find.byType(FrostFadingAmbientBackdrop).evaluate().length == 2) veiled++;
          await tester.pump(const Duration(milliseconds: 16));
        }
      }

      navigator.currentState!.push(page.createRoute(navigator.currentContext!));
      await tester.pump();
      await watch();
      expect(hidden, greaterThan(0), reason: 'the backdrop covers the route below before the content shows');
      expect(veiled, greaterThan(0), reason: 'the content then emerges from the backdrop');
      await tester.pumpAndSettle();
      expect(find.byType(FrostFadingAmbientBackdrop), findsNothing, reason: 'a settled page leaves the backdrop to the window');

      hidden = veiled = 0;
      navigator.currentState!.pop();
      await tester.pump();
      await watch();
      expect(hidden, greaterThan(0));
      expect(veiled, greaterThan(0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
