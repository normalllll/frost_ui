import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

void main() {
  testWidgets('stationary content fades gradually over the complete route progress', (tester) async {
    final animation = AnimationController(vsync: tester, duration: FrostMotion.page, reverseDuration: FrostMotion.exit);
    addTearDown(animation.dispose);
    const page = ValueKey('ordinary content');
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) => frostPageTransition(context, animation, kAlwaysDismissedAnimation, const ColoredBox(key: page, color: Colors.red)),
        ),
      ),
    );
    double alpha() => tester.widget<FrostMaterialReveal>(find.ancestor(of: find.byKey(page), matching: find.byType(FrostMaterialReveal)).first).opacity;
    final rect = tester.getRect(find.byKey(page));
    animation.forward();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    expect(alpha(), closeTo(.25, .001));
    expect(tester.getRect(find.byKey(page)), rect);
    await tester.pump(const Duration(milliseconds: 100));
    expect(alpha(), inExclusiveRange(0, 1));
    expect(tester.getRect(find.byKey(page)), rect);
    await tester.pumpAndSettle();
    expect(alpha(), 1);
    animation.reverse();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(alpha(), closeTo(1 - 80 / FrostMotion.exit.inMilliseconds, .001));
    expect(tester.getRect(find.byKey(page)), rect);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('the dim under a page follows route progress and ends clear at both ends', (tester) async {
    final animation = AnimationController(vsync: tester, duration: FrostMotion.page, reverseDuration: FrostMotion.exit);
    addTearDown(animation.dispose);
    await tester.pumpWidget(
      frostTestApp(Builder(builder: (context) => frostPageTransition(context, animation, kAlwaysDismissedAnimation, const ColoredBox(color: Colors.red)))),
    );
    final scrim = FrostThemeTokens.of(tester.element(find.byType(ColoredBox).first)).onMediaScrim.withValues(alpha: 1);
    Future<double> dimAt(double value) async {
      animation.value = value;
      await tester.pump();
      return tester.widgetList<ColoredBox>(find.byType(ColoredBox)).firstWhere((box) => box.color.withValues(alpha: 1) == scrim).color.a;
    }

    final forward = [for (var step = 0; step <= 100; step++) await dimAt(step / 100)];
    final backward = [for (var step = 100; step >= 0; step--) await dimAt(step / 100)];
    for (final sweep in [forward, backward]) {
      expect(sweep.first, 0);
      expect(sweep.last, 0);
      expect(sweep.reduce((a, b) => a > b ? a : b), closeTo(.2, .01));
      for (var index = 1; index < sweep.length; index++) {
        expect((sweep[index] - sweep[index - 1]).abs(), lessThan(.01), reason: 'step $index');
      }
    }
    await tester.pumpWidget(const SizedBox());
  });
}
