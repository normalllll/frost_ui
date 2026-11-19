import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/foundation/color_math.dart' show colorContrast;
import 'package:material_ui/material_ui.dart';

import 'support.dart';

Widget _columns({required bool pane}) => Row(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    const SizedBox(width: 260),
    if (pane) const FrostDivider.pane() else const FrostDivider(axis: Axis.vertical),
    const Expanded(child: SizedBox.expand()),
  ],
);

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('a pane edge draws the full height in the line tone, a content divider in the separator, $brightness', (tester) async {
      await tester.pumpWidget(frostTestApp(_columns(pane: true), brightness: brightness));
      final tokens = FrostThemeTokens.of(tester.element(find.byType(FrostDivider)));
      final edge = tester.getRect(find.byType(FrostDivider));
      expect(edge.height, tester.view.physicalSize.height / tester.view.devicePixelRatio);
      expect(find.byType(FrostDivider), paints..line(color: tokens.line));
      expect(
        colorContrast(Color.alphaBlend(tokens.line, tokens.canvas), tokens.canvas),
        greaterThan(colorContrast(Color.alphaBlend(tokens.separator, tokens.canvas), tokens.canvas)),
        reason: 'the pane edge stands out more than a content divider',
      );

      await tester.pumpWidget(frostTestApp(_columns(pane: false), brightness: brightness));
      expect(find.byType(FrostDivider), paints..line(color: tokens.separator));
    });
  }

  testWidgets('a split view parts its panes with the pane edge', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(frostTestApp(FrostSplitView(primary: const SizedBox.expand(), secondary: const SizedBox.expand(), onCloseSecondary: () {})));
    await tester.pumpAndSettle();
    final tokens = FrostThemeTokens.of(tester.element(find.byType(FrostSplitView)));
    expect(find.byType(FrostDivider), paints..line(color: tokens.line));
  });
}
