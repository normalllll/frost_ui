import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

const _summary = FrostText.rich(
  TextSpan(
    children: [
      TextSpan(text: '待下载 '),
      FrostToneSpan('3', tone: FrostTextTone.primary),
      TextSpan(text: ' 条 · '),
      FrostToneSpan('2', tone: FrostTextTone.accent),
      TextSpan(text: ' 名学生'),
    ],
  ),
  role: FrostTextRole.callout,
  tone: FrostTextTone.secondary,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
);

/// The colour each run of the painted text resolves to, with inherited styles
/// applied.
List<(String, Color?)> _runs(WidgetTester tester) {
  final text = tester.widget<RichText>(find.descendant(of: find.byType(FrostText), matching: find.byType(RichText))).text;
  final runs = <(String, Color?)>[];
  void visit(InlineSpan span, TextStyle? inherited) {
    final style = inherited?.merge(span.style) ?? span.style;
    if (span is TextSpan) {
      if (span.text case final text?) runs.add((text, style?.color));
      for (final child in span.children ?? const <InlineSpan>[]) {
        visit(child, style);
      }
    }
  }

  visit(text, null);
  return runs;
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('toned runs take their tone and the rest the text tone, $brightness', (tester) async {
      await tester.pumpWidget(frostTestApp(const Center(child: _summary), brightness: brightness));
      final tokens = FrostThemeTokens.of(tester.element(find.byType(FrostText)));
      final runs = Map.fromEntries(_runs(tester).map((run) => MapEntry(run.$1, run.$2)));
      expect(runs['3'], tokens.textPrimary);
      expect(runs['2'], tokens.accentInk);
      expect(runs['待下载 '], tokens.textSecondary);
      expect(runs[' 名学生'], tokens.textSecondary);
    });
  }

  testWidgets('a toned line on glass takes the glass ink, like the text tone', (tester) async {
    await tester.pumpWidget(
      frostTestApp(
        const Center(
          child: FrostSurface(
            role: FrostSurfaceRole.overlay,
            child: FrostText.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'a '),
                  FrostToneSpan('b', tone: FrostTextTone.tertiary),
                ],
              ),
              tone: FrostTextTone.primary,
            ),
          ),
        ),
        brightness: Brightness.dark,
      ),
    );
    final tokens = FrostThemeTokens.of(tester.element(find.byType(FrostText)));
    final runs = Map.fromEntries(_runs(tester).map((run) => MapEntry(run.$1, run.$2)));
    expect(runs['b'], tokens.textTertiaryGlass);
  });

  testWidgets('the toned line stays one text: found by its plain text, one label, one ellipsis', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(frostTestApp(const Center(child: SizedBox(width: 60, child: _summary))));
    expect(find.text('待下载 3 条 · 2 名学生'), findsOneWidget);
    expect(find.bySemanticsLabel('待下载 3 条 · 2 名学生'), findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(find.descendant(of: find.byType(FrostText), matching: find.byType(RichText)));
    expect(paragraph.didExceedMaxLines, isTrue, reason: 'the whole line is cut by one ellipsis');
    expect(find.byType(RichText), findsOneWidget);
    semantics.dispose();
  });
}
