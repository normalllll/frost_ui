import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/display/_data_track.dart';
import 'package:material_ui/material_ui.dart';

import 'display_badges_test.dart' show display;

Finder get trackPaint => find.byWidgetPredicate((w) => w is CustomPaint && w.painter is FrostDataTrackPainter);
FrostDataTrackPainter painter(WidgetTester tester) => tester.widget<CustomPaint>(trackPaint).painter! as FrostDataTrackPainter;

void main() {
  for (final direction in TextDirection.values) {
    for (final brightness in Brightness.values) {
      testWidgets('meter paint, marks, modulo and clamp $direction $brightness', (tester) async {
        final handle = tester.ensureSemantics();
        await display(
          tester,
          const FrostMeter(value: 20, min: 0, max: 10, dataColor: -1, marks: [-1, 5, 15], semanticLabel: 'Level'),
          width: 200,
          direction: direction,
          brightness: brightness,
          scale: 2,
        );
        final tokens = FrostThemeTokens.of(tester.element(find.byType(FrostMeter)));
        final x = direction == TextDirection.ltr ? 195.0 : 5.0;
        expect(tester.getSize(find.byType(FrostMeter)), const Size(200, 17));
        expect(
          tester.renderObject<RenderCustomPaint>(trackPaint),
          paints
            ..rrect(rrect: RRect.fromRectAndRadius(const Rect.fromLTWH(5, 3, 190, 4), const Radius.circular(2)), color: tokens.fillStrong)
            ..circle(x: x, y: 5, radius: 5, color: tokens.surface)
            ..circle(x: x, y: 5, radius: 4, color: tokens.categorical.last, strokeWidth: 2, style: PaintingStyle.stroke)
            ..rect(rect: Rect.fromLTWH((direction == TextDirection.ltr ? 5 : 195) - .5, 11, 1, 6), color: tokens.textTertiary),
        );
        final data = tester.getSemantics(find.byType(FrostMeter)).getSemanticsData();
        expect(data.label, 'Level');
        expect(data.value, '10.0');
        expect(tester.takeException(), isNull);
        handle.dispose();
      });
    }
  }
  for (final reduced in [false, true]) {
    testWidgets('data track spring intermediate frames reduced=$reduced', (tester) async {
      var value = .2;
      late StateSetter update;
      await display(
        tester,
        StatefulBuilder(
          builder: (context, set) {
            update = set;
            return FrostMeter(value: value, semanticLabel: 'Level');
          },
        ),
        width: 200,
        reduced: reduced,
      );
      update(() => value = .8);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      expect(painter(tester).marker, reduced ? .8 : inExclusiveRange(.2, .8));
      await tester.pumpAndSettle();
      expect(painter(tester).marker, .8);
      expect(tester.takeException(), isNull);
    });
  }
}
