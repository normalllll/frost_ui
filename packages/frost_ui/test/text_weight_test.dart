import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

void main() {
  for (final content in [false, true]) {
    testWidgets('a weight keeps the role size and line height (content $content)', (tester) async {
      await tester.pumpWidget(
        frostTestApp(
          Column(
            children: [
              FrostText('plain', content: content),
              FrostText('medium', weight: FrostTextWeight.medium, content: content),
              FrostText('semibold', weight: FrostTextWeight.semibold, content: content),
            ],
          ),
        ),
      );
      TextStyle style(String text) =>
          tester.widget<RichText>(find.descendant(of: find.widgetWithText(FrostText, text), matching: find.byType(RichText))).text.style!;
      final body = FrostTypography.of(tester.element(find.text('plain'))).style(FrostTextRole.body);
      for (final (text, weight) in [('medium', FontWeight.w500), ('semibold', FontWeight.w600)]) {
        expect(style(text).fontSize, body.fontSize);
        expect(style(text).height, body.height);
        expect(style(text).fontWeight, weight);
      }
      expect(style('plain').fontWeight, body.fontWeight);
    });
  }
}
