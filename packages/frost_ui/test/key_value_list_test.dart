import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'support.dart';

void main() {
  Future<void> pump(WidgetTester tester, List<FrostKeyValue> entries, {double width = 300, bool dividers = false}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      frostTestApp(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: FrostKeyValueList(entries: entries, dividers: dividers),
          ),
        ),
      ),
    );
  }

  // Label and value share one font and size, so the bottoms of their first
  // glyphs line up exactly when their baselines do.
  double baseline(WidgetTester tester, Finder text) {
    final paragraph = tester.renderObject<RenderParagraph>(text);
    final glyph = paragraph.getBoxesForSelection(const TextSelection(baseOffset: 0, extentOffset: 1)).first;
    return paragraph.localToGlobal(Offset(0, glyph.bottom)).dy;
  }

  // The test font draws every glyph one em (14) wide.
  const em = 14.0;

  testWidgets('the label column is as wide as the longest label and labels stay on one line', (tester) async {
    await pump(tester, const [FrostKeyValue(label: 'Dimensions', value: '3840 × 2160'), FrostKeyValue(label: 'Rating', value: 'Safe')]);
    expect(tester.getSize(find.text('Dimensions')), const Size(10 * em, 20));
    expect(tester.getSize(find.text('Rating')).width, 10 * em);
    expect(tester.getTopLeft(find.text('3840 × 2160')).dx, 10 * em + 12);
    expect(tester.getTopLeft(find.text('Safe')).dx, 10 * em + 12);
  });

  testWidgets('a label longer than half the list wraps at the cap', (tester) async {
    await pump(tester, const [FrostKeyValue(label: 'An unusually long label', value: 'v')], width: 312);
    final label = tester.getSize(find.text('An unusually long label'));
    expect(label.width, 150);
    expect(label.height, greaterThan(20));
    expect(tester.getTopLeft(find.text('v')).dx, 162);
  });

  testWidgets('values wrap in their own column and share the label baseline', (tester) async {
    await pump(tester, const [FrostKeyValue(label: 'Tags', value: 'one two three four five six seven eight'), FrostKeyValue(label: 'Size', value: '1.2 MB')]);
    final value = tester.getRect(find.text('one two three four five six seven eight'));
    expect(value.left, 4 * em + 12);
    expect(value.right, lessThanOrEqualTo(300));
    expect(value.height, greaterThan(20));
    expect(baseline(tester, find.text('Tags')), baseline(tester, find.text('one two three four five six seven eight')));
    expect(baseline(tester, find.text('Size')), baseline(tester, find.text('1.2 MB')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a link value is tappable, focusable, ends with the external-link glyph and reads as a link', (tester) async {
    final handle = tester.ensureSemantics();
    var opened = 0;
    await pump(tester, [
      const FrostKeyValue(label: 'Size', value: '1.2 MB'),
      FrostKeyValue.link(label: 'Source', value: 'example.com/post/1', semanticLabel: 'Open source', onPressed: () => opened++),
    ]);
    final link = find.textContaining('example.com/post/1');
    expect(find.descendant(of: find.byType(FrostKeyValueList), matching: find.byType(FrostIcon)), findsOneWidget);
    expect(baseline(tester, find.text('Source')), baseline(tester, link));
    expect(tester.getTopLeft(link).dx, 6 * em + 12);

    await tester.tap(link);
    expect(opened, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(frostFocusRings(), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(opened, 2);

    expect(
      tester.getSemantics(find.text('Source')),
      matchesSemantics(label: 'Source\nOpen source', isLink: true, hasTapAction: true, isFocusable: true, hasFocusAction: true, isFocused: true),
    );
    handle.dispose();
  });

  testWidgets('a link without an action is plain text', (tester) async {
    await pump(tester, const [FrostKeyValue.link(label: 'Source', value: 'example.com', onPressed: null)]);
    expect(find.text('example.com'), findsOneWidget);
    expect(find.byType(FrostClickSurface), findsNothing);
    expect(find.byType(FrostIcon), findsNothing);
  });
}
