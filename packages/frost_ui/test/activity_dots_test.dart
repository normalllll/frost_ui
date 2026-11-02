import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'support.dart';

Widget _reduced(Widget child) => frostTestApp(
  Builder(
    builder: (context) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: Center(child: child)),
  ),
);

RenderObject _indicatorPaint(WidgetTester tester) => tester.renderObject(find.descendant(of: find.byType(FrostActivityIndicator), matching: find.byType(CustomPaint)));

void main() {
  const sizes = [
    (FrostControlSize.small, 12.0, 2.5, 2.0),
    (FrostControlSize.compact, 16.0, 3.0, 2.5),
    (FrostControlSize.regular, 20.0, 4.0, 3.0),
    (FrostControlSize.large, 28.0, 5.5, 4.0),
  ];

  for (final (size, box, dot, gap) in sizes) {
    testWidgets('activity indicator $size paints three centred dots and no arc', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(frostTestApp(Center(child: FrostActivityIndicator(size: size, semanticLabel: 'Waiting'))));
      expect(tester.getSize(find.byType(FrostActivityIndicator)), Size.square(box));
      expect(find.bySemanticsLabel('Waiting'), findsOneWidget);
      expect(_indicatorPaint(tester), paintsExactlyCountTimes(#drawCircle, 3));
      expect(_indicatorPaint(tester), paintsExactlyCountTimes(#drawArc, 0));
      expect(_indicatorPaint(tester), isNot(paints..arc()));
      await tester.pumpWidget(const SizedBox());
      semantics.dispose();
    });

    testWidgets('reduced activity indicator $size is three static full dots with no ticker', (tester) async {
      await tester.pumpWidget(_reduced(FrostActivityIndicator(size: size, semanticLabel: null)));
      final left = (box - (3 * dot + 2 * gap)) / 2;
      expect(
        _indicatorPaint(tester),
        paints
          ..circle(x: left + dot / 2, y: box / 2, radius: dot / 2)
          ..circle(x: left + dot / 2 + dot + gap, y: box / 2, radius: dot / 2)
          ..circle(x: left + dot / 2 + 2 * (dot + gap), y: box / 2, radius: dot / 2),
      );
      expect(_indicatorPaint(tester), isNot(paints..arc()));
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('activity dots pulse in sequence on a 900 ms cycle', (tester) async {
    await tester.pumpWidget(frostTestApp(const Center(child: FrostActivityIndicator(semanticLabel: null))));
    // Dot 0 starts its pulse at rest: scale 0.8 of a 4px dot.
    expect(_indicatorPaint(tester), paints..circle(radius: 2 * .8));
    expect(tester.hasRunningAnimations, isTrue);
    // Half a cycle later dot 0 is at its peak (scale 1).
    await tester.pump(const Duration(milliseconds: 450));
    expect(_indicatorPaint(tester), paints..circle(radius: 2.0));
    // A full cycle returns to the start.
    await tester.pump(const Duration(milliseconds: 450));
    expect(_indicatorPaint(tester), paints..circle(radius: 2 * .8));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('refresh dots keep their extent and paint three circles and no arc', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(frostTestApp(const Center(child: FrostRefreshDots())));
    expect(tester.getSize(find.byType(FrostRefreshDots)), const Size(24, 18));
    expect(find.byType(FrostActivityIndicator), findsNothing);
    final render = tester.renderObject(find.byType(FrostRefreshDots));
    expect(render, paintsExactlyCountTimes(#drawCircle, 3));
    expect(render, paintsExactlyCountTimes(#drawArc, 0));
    expect(tester.getSemantics(find.byType(FrostRefreshDots)).label, isNotEmpty);
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(const SizedBox());
    semantics.dispose();
  });

  testWidgets('reduced refresh dots are static', (tester) async {
    await tester.pumpWidget(_reduced(const FrostRefreshDots()));
    final render = tester.renderObject(find.byType(FrostRefreshDots));
    expect(render, paintsExactlyCountTimes(#drawCircle, 3));
    expect(render, isNot(paints..arc()));
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
}
