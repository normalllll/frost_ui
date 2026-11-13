import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart' show RenderEditable, SemanticsAction;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_copy_feedback.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

const _short = r'D:\work\gitbound';
const _long = 'A long value that wraps across several lines when the column is narrow enough to need it';

Future<void> _frame(WidgetTester tester, Widget child, {double width = 640, double scale = 1, bool rtl = false, FrostDensity density = FrostDensity.compact}) => tester.pumpWidget(
  frostTestApp(
    MediaQuery(
      data: MediaQueryData(size: const Size(1000, 800), textScaler: TextScaler.linear(scale)),
      child: Directionality(
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [child]),
          ),
        ),
      ),
    ),
    density: density,
  ),
);

Finder get _button => find.descendant(of: find.byType(FrostCopyable), matching: find.bySemanticsLabel('L.copy')).first;
Rect _buttonRect(WidgetTester tester) => tester.getRect(find.byType(FrostCopyFeedbackButton));
Rect _textRect(WidgetTester tester, String text) => _editable(tester).localToGlobal(Offset.zero) & _editable(tester).size;
RenderEditable _editable(WidgetTester tester) => tester.allRenderObjects.whereType<RenderEditable>().single;
double _firstLineCenter(WidgetTester tester) {
  final editable = _editable(tester);
  final origin = editable.localToGlobal(Offset.zero);
  return origin.dy + editable.preferredLineHeight / 2;
}

void main() {
  for (final rtl in [false, true]) {
    for (final monospace in [false, true]) {
      testWidgets('one line: the button follows the text and centres on it (rtl=$rtl, mono=$monospace)', (tester) async {
        await _frame(tester, FrostCopyable(text: _short, monospace: monospace), rtl: rtl);
        final text = _textRect(tester, _short);
        final button = _buttonRect(tester);
        if (rtl) {
          expect(text.right, 640);
          expect(button.right, moreOrLessEquals(text.left - FrostGap.related));
        } else {
          expect(text.left, 0);
          expect(button.left, moreOrLessEquals(text.right + FrostGap.related));
        }
        expect(button.center.dy, moreOrLessEquals(_firstLineCenter(tester), epsilon: .5));
        expect(_editable(tester).size.height, moreOrLessEquals(_editable(tester).preferredLineHeight, epsilon: 1));
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final scale in [1.0, 1.3]) {
    for (final density in [FrostDensity.compact, FrostDensity.comfortable]) {
      testWidgets('wrapped: the button sits at the row end, centred on the first line, without overlap (scale=$scale, $density)', (tester) async {
        await _frame(tester, const FrostCopyable(text: _long, monospace: true), width: 320, scale: scale, density: density);
        final text = _textRect(tester, _long);
        final button = _buttonRect(tester);
        expect(button.right, moreOrLessEquals(320));
        expect(text.right, lessThanOrEqualTo(button.left - FrostGap.related + .01));
        expect(text.height, greaterThan(_editable(tester).preferredLineHeight * 1.5));
        expect(button.center.dy, moreOrLessEquals(_firstLineCenter(tester), epsilon: .5));
        expect(text.top, greaterThanOrEqualTo(tester.getRect(find.byType(FrostCopyable)).top));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('the row is as wide as its content, so a labeled content keeps its label', (tester) async {
    await _frame(tester, const FrostLabeledContent(label: 'Source commit', content: FrostCopyable(text: '1a65d9a', monospace: true)), width: 410);
    final label = tester.getRect(find.text('Source commit'));
    expect(label.height, lessThan(30), reason: 'the label stays on one line');
    expect(_buttonRect(tester).right, lessThanOrEqualTo(410));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the button and the menu copy the full value; text and button stay separate nodes', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final semantics = tester.ensureSemantics();
    await _frame(tester, const FrostCopyable(text: 'full value', display: 'shown'));

    // The text is a read-only text field reading what it shows; the button
    // is a node of its own named Copy.
    final text = tester.getSemantics(find.byType(EditableText));
    expect(text.value, 'shown');
    expect(text.flagsCollection.isTextField, isTrue);
    expect(text.flagsCollection.isReadOnly, isTrue);
    expect(text.flagsCollection.isButton, isFalse);
    final button = tester.getSemantics(find.byType(FrostCopyFeedbackButton));
    expect(button, isNot(same(text)));
    expect(button.label, 'L.copy');
    expect(button.flagsCollection.isButton, isTrue);
    expect(button.flagsCollection.isTextField, isFalse);
    expect(button.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(_button, findsOneWidget);

    // The button copies the full value and shows its check feedback.
    await tester.tap(find.byType(FrostCopyFeedbackButton));
    await tester.pump();
    expect(copied, ['full value']);
    expect(find.byKey(const ValueKey(true)), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey(true)), findsNothing);

    // A secondary click opens one Copy action that copies the same value.
    await tester.tapAt(tester.getCenter(find.byType(SelectableText)), kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    expect(find.text('L.copy'), findsOneWidget);
    await tester.tap(find.text('L.copy'));
    await tester.pumpAndSettle();
    expect(copied, ['full value', 'full value']);
    expect(find.byKey(const ValueKey(true)), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
