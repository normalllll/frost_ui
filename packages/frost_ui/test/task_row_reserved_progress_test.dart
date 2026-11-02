import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'support.dart';

Widget _rows(FrostTaskStatus status, {double? progress = 0}) => frostTestApp(
  Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 411,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FrostTaskRow(title: 'a.png', detail: 'Detail', status: status, progress: progress, progressPlacement: FrostTaskProgressPlacement.belowDetail),
          const SizedBox(key: ValueKey('next'), height: 20),
        ],
      ),
    ),
  ),
);

void main() {
  testWidgets('a queued task with progress keeps its height and the next row when it starts', (tester) async {
    await tester.pumpWidget(_rows(FrostTaskStatus.queued));
    await tester.pumpAndSettle();
    final height = tester.getSize(find.byType(FrostTaskRow)).height;
    final next = tester.getTopLeft(find.byKey(const ValueKey('next'))).dy;
    expect(tester.widget<AnimatedOpacity>(find.ancestor(of: find.byType(FrostProgressBar), matching: find.byType(AnimatedOpacity)).first).opacity, 0);

    await tester.pumpWidget(_rows(FrostTaskStatus.running));
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.getSize(find.byType(FrostTaskRow)).height, moreOrLessEquals(height));
      expect(tester.getTopLeft(find.byKey(const ValueKey('next'))).dy, moreOrLessEquals(next));
    }
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedOpacity>(find.ancestor(of: find.byType(FrostProgressBar), matching: find.byType(AnimatedOpacity)).first).opacity, 1);

    await tester.pumpWidget(_rows(FrostTaskStatus.paused));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(FrostTaskRow)).height, height);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a queued task without progress takes no room for a bar', (tester) async {
    await tester.pumpWidget(_rows(FrostTaskStatus.queued, progress: null));
    await tester.pumpAndSettle();
    final without = tester.getSize(find.byType(FrostTaskRow)).height;
    await tester.pumpWidget(_rows(FrostTaskStatus.queued));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(FrostTaskRow)).height, greaterThan(without));
    expect(tester.takeException(), isNull);
  });
}
