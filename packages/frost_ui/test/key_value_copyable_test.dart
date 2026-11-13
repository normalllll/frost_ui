import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart' show RenderEditable, RenderParagraph, SemanticsAction;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_copy_feedback.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

const _oid = '1a65d9a0c3b4e5f60718293a4b5c6d7e8f901234';
const _address = 'git@github-zhang:owner/a-repository-with-a-rather-long-name-that-wraps.git';
const _ref = 'refs/heads/main';

Future<void> _frame(WidgetTester tester, Widget child, {double width = 410}) => tester.pumpWidget(
  frostTestApp(
    Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: width, child: child),
    ),
  ),
);

const _preview = FrostKeyValueList(
  entries: [
    FrostKeyValue.copyable(label: 'Source commit', value: _oid, monospace: true),
    FrostKeyValue.copyable(label: 'Address', value: _address, monospace: true),
    FrostKeyValue.copyable(label: 'Target', value: _ref, monospace: true),
  ],
);

RenderEditable _editable(WidgetTester tester, String text) =>
    tester.allRenderObjects.whereType<RenderEditable>().singleWhere((editable) => editable.text?.toPlainText() == text);
Rect _valueRect(WidgetTester tester, String text) {
  final editable = _editable(tester, text);
  return editable.localToGlobal(Offset.zero) & editable.size;
}

void main() {
  testWidgets('labels share one column, values another; long values wrap inside theirs', (tester) async {
    await _frame(tester, _preview);
    final labels = [for (final label in ['Source commit', 'Address', 'Target']) tester.getRect(find.text(label))];
    final values = [for (final value in [_oid, _address, _ref]) _valueRect(tester, value)];
    expect(labels.map((rect) => rect.left).toSet(), hasLength(1));
    expect(values.map((rect) => rect.left).toSet(), hasLength(1));
    expect(values.first.left, greaterThan(labels.map((rect) => rect.right).reduce((a, b) => a > b ? a : b)));
    // Each label stays on one line.
    for (final label in labels) {
      expect(label.height, lessThan(values.last.height + 1));
    }
    final line = _editable(tester, _address).preferredLineHeight;
    expect(values[1].height, greaterThan(line * 1.5), reason: 'the long address wraps');
    expect(values[1].right, lessThanOrEqualTo(410));
    expect(tester.takeException(), isNull);
  });

  testWidgets('each copy button follows its value and centres on its first line', (tester) async {
    await _frame(tester, _preview);
    final buttons = tester.widgetList<FrostCopyFeedbackButton>(find.byType(FrostCopyFeedbackButton)).toList();
    expect(buttons, hasLength(3));
    final rects = [for (final element in find.byType(FrostCopyFeedbackButton).evaluate()) tester.getRect(find.byElementPredicate((e) => e == element))];
    final ref = _valueRect(tester, _ref);
    // A short value: the button is right after it.
    expect(rects[2].left, moreOrLessEquals(ref.right + FrostGap.related));
    for (final (index, value) in [_oid, _address, _ref].indexed) {
      final editable = _editable(tester, value);
      final firstLine = editable.localToGlobal(Offset.zero).dy + editable.preferredLineHeight / 2;
      expect(rects[index].center.dy, moreOrLessEquals(firstLine, epsilon: .5));
      expect(rects[index].left, greaterThanOrEqualTo(_valueRect(tester, value).right + FrostGap.related - .01));
    }
  });

  testWidgets('a label shares its value first baseline, also when the value wraps', (tester) async {
    await _frame(tester, _preview);
    // The first line's baseline of [text] laid out at [width].
    double baseline(InlineSpan text, TextScaler scaler, double width) {
      final painter = TextPainter(text: text, textDirection: TextDirection.ltr, textScaler: scaler)..layout(maxWidth: width);
      final distance = painter.computeLineMetrics().first.baseline;
      painter.dispose();
      return distance;
    }

    for (final (labelText, valueText) in [('Target', _ref), ('Address', _address)]) {
      final label = tester.renderObject<RenderParagraph>(find.descendant(of: find.text(labelText), matching: find.byType(RichText)).first);
      final labelBaseline = label.localToGlobal(Offset.zero).dy + baseline(label.text, label.textScaler, label.size.width);
      final value = _editable(tester, valueText);
      final lines = value.text!.toPlainText();
      expect(lines, valueText);
      final valueBaseline = value.localToGlobal(Offset.zero).dy + baseline(value.text!, value.textScaler, value.size.width);
      expect(labelBaseline, moreOrLessEquals(valueBaseline, epsilon: .5), reason: labelText);
    }
    // The address really wraps, so its first baseline is not its last.
    expect(_editable(tester, _address).size.height, greaterThan(_editable(tester, _address).preferredLineHeight * 1.5));
  });

  testWidgets('a copyable row reads its label with its value; the copy button stays its own node', (tester) async {
    final semantics = tester.ensureSemantics();
    await _frame(tester, const FrostKeyValueList(entries: [FrostKeyValue.copyable(label: 'Commit', value: _oid, monospace: true)]));
    final row = find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == 'Commit' && widget.properties.value == _oid);
    expect(row, findsOneWidget);
    final node = tester.getSemantics(row);
    expect(node.label, 'Commit');
    expect(node.value, _oid);
    expect(node.flagsCollection.isButton, isFalse);
    expect(node.flagsCollection.isTextField, isFalse);
    final button = tester.getSemantics(find.byType(FrostCopyFeedbackButton));
    expect(button, isNot(same(node)));
    expect(button.label, 'L.copy');
    expect(button.flagsCollection.isButton, isTrue);
    expect(button.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    // The button is the row's child node, so it is read after the value.
    var parent = button.parent;
    while (parent != null && parent != node) {
      parent = parent.parent;
    }
    expect(parent, same(node));
    semantics.dispose();
  });

  testWidgets('copying uses the full value; monospace is opt-in', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await _frame(
      tester,
      const FrostKeyValueList(
        entries: [
          FrostKeyValue.copyable(label: 'Commit', value: _oid, monospace: true),
          FrostKeyValue.copyable(label: 'Name', value: 'zhang'),
        ],
      ),
    );
    await tester.tap(find.byType(FrostCopyFeedbackButton).first);
    await tester.pump();
    expect(copied, [_oid]);
    await tester.tapAt(tester.getCenter(find.text('zhang')), kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('L.copy').last);
    await tester.pumpAndSettle();
    expect(copied, [_oid, 'zhang']);
    final mono = FrostTypography.of(tester.element(find.byType(FrostKeyValueList))).style(FrostTextRole.callout, monospace: true).fontFamily;
    expect(_editable(tester, _oid).text!.style!.fontFamily, mono);
    expect(_editable(tester, 'zhang').text!.style!.fontFamily, isNot(mono));
    await tester.pump(const Duration(seconds: 3));
  });
}
