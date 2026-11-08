import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/display/_rich_text_parser.dart';
import 'package:frost_ui/src/display/expandable_text.dart' show frostExpandableTextFadeWidth, FrostExpandableTextPainter;
import 'package:frost_ui/src/display/rich_text.dart' show FrostRichTextState;

import 'support.dart';

Widget view(Widget child, {double width = 250, double scale = 1, bool reduced = false, TextDirection direction = TextDirection.ltr}) => frostTestApp(
  MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale), disableAnimations: reduced),
    child: Directionality(
      textDirection: direction,
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(width: width, child: child),
      ),
    ),
  ),
);
const longText =
    'Readable words 中文与 emoji 👩‍👩‍👧‍👦. Readable words 中文与 emoji 👩‍👩‍👧‍👦. '
    'Readable words 中文与 emoji 👩‍👩‍👧‍👦. Readable words 中文与 emoji 👩‍👩‍👧‍👦. '
    'Readable words 中文与 emoji 👩‍👩‍👧‍👦. Readable words 中文与 emoji 👩‍👩‍👧‍👦.';
void main() {
  testWidgets('cold frame overflow and standard height spring in both directions', (tester) async {
    await tester.pumpWidget(view(const FrostExpandableText(text: longText + longText)));
    expect(find.text('L.expandText'), findsOneWidget);
    final collapsed = tester.getSize(find.byType(FrostExpandableText)).height;
    expect(frostExpandableTextFadeWidth, 24);
    final paint = tester
        .widgetList<CustomPaint>(find.descendant(of: find.byType(FrostExpandableText), matching: find.byType(CustomPaint)))
        .map((widget) => widget.painter)
        .whereType<FrostExpandableTextPainter>()
        .single;
    expect(paint.fade!.width, 24);
    expect(paint.text.computeLineMetrics().length, inInclusiveRange(2, 3));
    await tester.tap(find.text('L.expandText'));
    await tester.pump();
    expect(tester.getSize(find.byType(FrostExpandableText)).height, collapsed);
    await tester.pump(const Duration(milliseconds: 60));
    final middle = tester.getSize(find.byType(FrostExpandableText)).height;
    await tester.pumpAndSettle();
    final expanded = tester.getSize(find.byType(FrostExpandableText)).height;
    expect(middle, inExclusiveRange(collapsed, expanded));
    await tester.tap(find.text('L.collapseText'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.getSize(find.byType(FrostExpandableText)).height, inExclusiveRange(collapsed, expanded));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(FrostExpandableText)).height, closeTo(collapsed, .01));
    expect(tester.takeException(), isNull);
  });
  testWidgets('rich expandable text truncates to maxLines with a link that taps, focuses and announces', (tester) async {
    final semantics = tester.ensureSemantics();
    final opened = <Uri>[];
    FrostExpandableTextPainter painter() => tester
        .widgetList<CustomPaint>(find.descendant(of: find.byType(FrostExpandableText), matching: find.byType(CustomPaint)))
        .map((widget) => widget.painter)
        .whereType<FrostExpandableTextPainter>()
        .single;
    await tester.pumpWidget(view(FrostExpandableText.rich(text: 'See [here](https://example.com) $longText', maxLines: 3, onLink: opened.add)));
    expect(find.text('L.expandText'), findsOneWidget);
    expect(painter().text.computeLineMetrics().length, 3);
    final link = find.bySemanticsLabel('here');
    expect(tester.getSemantics(link).getSemanticsData().flagsCollection.isLink, isTrue);
    await tester.tap(link);
    await tester.pump();
    expect(opened, [Uri.parse('https://example.com')]);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(tester.getRect(link).contains(tester.getCenter(find.byElementPredicate((e) => e == FocusManager.instance.primaryFocus!.context))), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(opened, hasLength(2));
    await tester.tap(find.text('L.expandText'));
    await tester.pumpAndSettle();
    expect(painter().text.plainText, startsWith('See here $longText'));
    expect(painter().fade, isNull);
    await tester.tap(link);
    expect(opened, hasLength(3));
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
  testWidgets('linked expandable text shows every character as written and only the marked link acts', (tester) async {
    final semantics = tester.ensureSemantics();
    final opened = <Uri>[];
    const prose = '(*´▽`*) **不是粗体** `不是代码` @someone #tag [x](https://example.test) ';
    final artwork = Uri.parse('https://www.pixiv.net/artworks/1');
    Widget linked({String tail = '', int maxLines = 3}) => view(
      FrostExpandableText.linked(
        runs: [
          const FrostTextRun(prose),
          FrostTextRun('作品', link: artwork),
          FrostTextRun(tail),
        ],
        onLink: opened.add,
        maxLines: maxLines,
      ),
      width: 600,
    );
    FrostExpandableTextPainter painter() => tester
        .widgetList<CustomPaint>(find.descendant(of: find.byType(FrostExpandableText), matching: find.byType(CustomPaint)))
        .map((widget) => widget.painter)
        .whereType<FrostExpandableTextPainter>()
        .single;
    await tester.pumpWidget(linked());
    final tokens = FrostThemeTokens.of(tester.element(find.byType(FrostExpandableText)));
    expect(painter().text.plainText, '$prose作品');
    final spans = <TextSpan>[];
    painter().text.text!.visitChildren((span) {
      if (span is TextSpan && span.text != null) spans.add(span);
      return true;
    });
    for (final span in spans.where((span) => span.text != '作品')) {
      expect(span.style!.color, tokens.textPrimary, reason: span.text);
      expect(span.style!.fontStyle, isNot(FontStyle.italic));
      expect(span.style!.backgroundColor, isNull);
    }
    expect(spans.singleWhere((span) => span.text == '作品').style!.color, tokens.accentInk);
    expect(find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.link == true), findsOneWidget);
    expect(find.descendant(of: find.byType(FrostExpandableText), matching: find.byType(FrostClickSurface)), findsOneWidget);
    final link = find.bySemanticsLabel('作品');
    expect(tester.getSemantics(link).getSemanticsData().flagsCollection.isLink, isTrue);
    await tester.tap(link);
    await tester.pump();
    expect(opened, [artwork]);

    await tester.pumpWidget(linked(tail: ' $longText $longText'));
    await tester.pump();
    expect(find.text('L.expandText'), findsOneWidget);
    expect(painter().text.computeLineMetrics().length, 3);
    expect(painter().text.plainText, startsWith('$prose作品'));
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
  testWidgets('a mention or hashtag without its callback reads as the text around it', (tester) async {
    const text = 'Hi @someone #tag [Link](https://example.test)';
    await tester.pumpWidget(view(FrostRichText(text: text, onLink: (_) {}), width: 600));
    final tokens = FrostThemeTokens.of(tester.element(find.byType(FrostRichText)));
    final paragraph = tester.widget<RichText>(find.descendant(of: find.byType(FrostRichText), matching: find.byType(RichText)).first);
    final spans = (paragraph.text as TextSpan).children!.whereType<TextSpan>().toList();
    expect(spans.firstWhere((span) => span.text == '@someone').style!.color, tokens.textPrimary);
    expect(spans.firstWhere((span) => span.text == '#tag').style!.color, tokens.textPrimary);
    expect(find.text('Link'), findsOneWidget);
    expect(find.descendant(of: find.byType(FrostRichText), matching: find.byType(FrostClickSurface)), findsOneWidget);

    await tester.pumpWidget(view(FrostExpandableText.rich(text: text, onLink: (_) {}), width: 600));
    final painter = tester
        .widgetList<CustomPaint>(find.descendant(of: find.byType(FrostExpandableText), matching: find.byType(CustomPaint)))
        .map((widget) => widget.painter)
        .whereType<FrostExpandableTextPainter>()
        .single;
    final painted = <TextSpan>[];
    painter.text.text!.visitChildren((span) {
      if (span is TextSpan && span.text != null) painted.add(span);
      return true;
    });
    expect(painted.firstWhere((span) => span.text == '@someone').style!.color, tokens.textPrimary);
    expect(painted.firstWhere((span) => span.text == 'Link').style!.color, tokens.accentInk);
    expect(find.descendant(of: find.byType(FrostExpandableText), matching: find.byType(FrostClickSurface)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('a linked text takes a chosen size and line height for truncation, the action and link areas', (tester) async {
    final semantics = tester.ensureSemantics();
    final opened = <Uri>[];
    final uri = Uri.parse('https://example.test/a');
    await tester.pumpWidget(
      view(
        FrostExpandableText.linked(
          runs: [
            FrostTextRun('here', link: uri),
            const FrostTextRun(' $longText $longText'),
          ],
          onLink: opened.add,
          maxLines: 4,
          fontSize: 17,
          lineHeight: 1.7,
        ),
        width: 300,
      ),
    );
    final painter = tester
        .widgetList<CustomPaint>(find.descendant(of: find.byType(FrostExpandableText), matching: find.byType(CustomPaint)))
        .map((widget) => widget.painter)
        .whereType<FrostExpandableTextPainter>()
        .single;
    final lines = painter.text.computeLineMetrics();
    expect(lines, hasLength(4));
    expect(lines.first.height, moreOrLessEquals(17 * 1.7, epsilon: 1));
    final top = tester.getTopLeft(find.byType(FrostExpandableText)).dy;
    final action = tester.getRect(find.text('L.expandText'));
    expect(action.top - top, moreOrLessEquals(lines.last.baseline - lines.last.ascent, epsilon: lines.last.height * .5));
    final link = tester.getRect(find.bySemanticsLabel('here'));
    expect(link.height, greaterThanOrEqualTo(17));
    expect(link.top - top, lessThan(lines.first.height));
    await tester.tap(find.bySemanticsLabel('here'));
    await tester.pump();
    expect(opened, [uri]);
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
  testWidgets('short text has no action; controlled action requires callback', (tester) async {
    await tester.pumpWidget(view(const FrostExpandableText(text: 'Short')));
    expect(find.text('Short'), findsOneWidget);
    expect(find.text('L.expandText'), findsNothing);
    await tester.pumpWidget(view(const FrostExpandableText(text: longText + longText, expanded: false)));
    final semantics = tester.ensureSemantics();
    final action = find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'L.expandText');
    expect(tester.getSemantics(action).getSemanticsData().flagsCollection.isEnabled, Tristate.isFalse);
    await tester.tapAt(tester.getCenter(find.text('L.expandText')));
    await tester.pumpAndSettle();
    expect(find.text('L.collapseText'), findsNothing);
    semantics.dispose();
    var expanded = false;
    await tester.pumpWidget(
      view(
        StatefulBuilder(
          builder: (_, update) =>
              FrostExpandableText(text: longText + longText, expanded: expanded, onExpandedChanged: (value) => update(() => expanded = value)),
        ),
      ),
    );
    await tester.tap(find.text('L.expandText'));
    await tester.pumpAndSettle();
    expect(expanded, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('large text RTL wraps actions and reduced motion applies height immediately', (tester) async {
    await tester.pumpWidget(
      view(const FrostExpandableText(text: longText + longText, maxLines: 2), width: 120, scale: 2, reduced: true, direction: TextDirection.rtl),
    );
    final collapsed = tester.getSize(find.byType(FrostExpandableText)).height;
    await tester.tap(find.text('L.expandText'));
    await tester.pump();
    expect(tester.getSize(find.byType(FrostExpandableText)).height, greaterThan(collapsed));
    expect(find.text('L.collapseText'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('grammar supports nested emphasis, literal code and social targets', () {
    final doc = FrostRichDocument('**bold *both*** *italic* `**raw** @name` [site](https://example.test/a(b)) @用户_2 #话题42');
    expect(doc.nodes.where((n) => n.bold).map((n) => n.text).join(), 'bold both');
    expect(doc.nodes.where((n) => n.bold && n.italic).single.text, 'both');
    expect(doc.nodes.where((n) => n.code).single.text, '**raw** @name');
    expect(doc.nodes.where((n) => n.target == FrostRichTarget.link).single.value, 'https://example.test/a(b)');
    expect(doc.nodes.where((n) => n.target == FrostRichTarget.mention).single.value, '用户_2');
    expect(doc.nodes.where((n) => n.target == FrostRichTarget.hashtag).single.value, '话题42');
    for (final raw in ['unclosed **bold', 'unclosed `code', '[ftp](ftp://example.test)', '~~strike~~', '<div>raw</div>']) {
      expect(FrostRichDocument(raw).nodes.map((n) => n.text).join(), raw);
    }
    expect(FrostRichDocument('a@name a#tag').nodes.every((n) => n.target == null), isTrue);
  });
  test('auto URLs trim multilingual punctuation and preserve balanced brackets', () {
    final doc = FrostRichDocument('https://example.test/a(b)， https://example.test/x). https://example.test/y【z】。');
    expect(doc.nodes.where((n) => n.target == FrostRichTarget.link).map((n) => n.value), [
      'https://example.test/a(b)',
      'https://example.test/x',
      'https://example.test/y【z】',
    ]);
  });
  testWidgets('rich styles callbacks hover and parse cache', (tester) async {
    final calls = <String>[];
    const text = '**Bold** *Italic* `code` [Link](https://example.test) @user #中文';
    await tester.pumpWidget(view(FrostRichText(text: text, onLink: (u) => calls.add(u.toString()), onMention: calls.add, onHashtag: calls.add), width: 600));
    final document = tester.state<FrostRichTextState>(find.byType(FrostRichText)).document;
    final paragraph = tester.widget<RichText>(find.descendant(of: find.byType(FrostRichText), matching: find.byType(RichText)).first);
    final spans = (paragraph.text as TextSpan).children!.whereType<TextSpan>().toList();
    expect(spans.firstWhere((s) => s.text == 'Bold').style!.fontWeight, FontWeight.w600);
    expect(spans.firstWhere((s) => s.text == 'Italic').style!.fontStyle, FontStyle.italic);
    expect(tester.widget<Text>(find.text('code')).style!.fontFamily, 'Consolas');
    expect(
      tester.widget<Padding>(find.ancestor(of: find.text('code'), matching: find.byType(Padding)).first).padding,
      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Link')));
    await tester.pump();
    expect(tester.widget<Text>(find.text('Link')).style!.decoration, TextDecoration.underline);
    await tester.tap(find.text('Link'));
    await tester.tap(find.text('@user'));
    await tester.tap(find.text('#中文'));
    expect(calls, ['https://example.test', 'user', '中文']);
    await tester.pumpWidget(view(FrostRichText(text: text, role: FrostTextRole.callout, onLink: (_) {}), width: 600));
    expect(identical(tester.state<FrostRichTextState>(find.byType(FrostRichText)).document, document), isTrue);
    await tester.pumpWidget(view(const FrostRichText(text: 'Changed')));
    expect(identical(tester.state<FrostRichTextState>(find.byType(FrostRichText)).document, document), isFalse);
    await mouse.removePointer();
    expect(tester.takeException(), isNull);
  });
  testWidgets('selection includes body code and link; opt-out removes selection', (tester) async {
    await tester.pumpWidget(view(FrostRichText(text: 'Body `code` [Link](https://example.test)', onLink: (_) {}), width: 220, scale: 2));
    expect(find.byType(SelectionArea), findsOneWidget);
    final paragraphs = tester.widgetList<RichText>(find.descendant(of: find.byType(FrostRichText), matching: find.byType(RichText)));
    expect(paragraphs.every((p) => p.selectionRegistrar != null), isTrue);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
      return null;
    });
    final selection = tester.state<SelectionAreaState>(find.byType(SelectionArea)).selectableRegion;
    selection.selectAll();
    selection.contextMenuButtonItems.firstWhere((item) => item.type == ContextMenuButtonType.copy).onPressed!();
    await tester.pump();
    expect(copied, contains('Body'));
    expect(copied, contains('code'));
    expect(copied, contains('Link'));
    expect(copied, isNot(contains('\uFFFC')));
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
    await tester.pumpWidget(view(const FrostRichText(text: 'Body `code`', selectable: false)));
    expect(find.byType(SelectionArea), findsNothing);
    expect(tester.widget<RichText>(find.descendant(of: find.byType(FrostRichText), matching: find.byType(RichText)).first).selectionRegistrar, isNull);
    expect(tester.takeException(), isNull);
  });
}
