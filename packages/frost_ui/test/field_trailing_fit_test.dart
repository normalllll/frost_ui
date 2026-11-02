import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_field_frame.dart';

import 'support.dart';

// A 320 wide window at 2x text, where a field's trailing controls (clear,
// submit, App actions) no longer all fit beside its editor.
Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    frostTestApp(
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: Align(alignment: Alignment.topCenter, child: child),
        ),
      ),
    ),
  );
}

Future<void> _type(WidgetTester tester, FocusNode focus) async {
  focus.requestFocus();
  await tester.pump();
  await tester.enterText(find.byType(EditableText), 'long');
  await tester.pumpAndSettle();
}

// The node of the first Focus inside [button].
FocusNode _focusNode(Element button) {
  Element? focus, inside;
  void visit(Element element) {
    if (focus != null) return;
    if (element.widget is Focus) {
      focus = element;
      return;
    }
    element.visitChildren(visit);
  }

  button.visitChildren(visit);
  focus!.visitChildren((child) => inside ??= child);
  return Focus.of(inside!);
}

// Trailing buttons that are painted and hittable lie inside the field frame,
// and the editor keeps its room; the others are absent from hit testing,
// semantics and focus.
void _expectFits(WidgetTester tester, {required int shown}) {
  expect(tester.takeException(), isNull);
  final frame = tester.getRect(find.byType(FrostFieldPaint));
  final buttons = find.descendant(of: find.byType(FrostFieldPaint), matching: find.byType(FrostButton));
  var visible = 0;
  for (final element in buttons.evaluate()) {
    final box = element.renderObject! as RenderBox;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final hit = tester.hitTestOnBinding(rect.center).path.any((entry) => entry.target == box);
    if (hit) {
      visible++;
      expect(rect.left >= frame.left && rect.right <= frame.right, isTrue, reason: '$rect outside $frame');
    }
    expect(_focusNode(element).canRequestFocus, hit, reason: "${(element.widget as FrostButton).label} focusable only while shown");
  }
  expect(visible, shown);
  final editor = tester.getRect(find.byType(EditableText));
  expect(editor.left >= frame.left && editor.right <= frame.right, isTrue);
}

void main() {
  late TextEditingController controller;
  late FocusNode focus;
  setUp(() {
    controller = TextEditingController();
    focus = FocusNode();
  });
  tearDown(() {
    controller.dispose();
    focus.dispose();
  });

  Widget search(double width) => SizedBox(
    width: width,
    child: FrostSearchInput(controller: controller, focusNode: focus, placeholder: 'Search', leadingIcon: true, onSubmitted: (_) {}),
  );

  // 84 is the room BooruFlow's search page header leaves its field at 320.
  for (final (width, shown) in [(84.0, 0), (160.0, 1), (320.0, 2)]) {
    testWidgets('search trailing fits a $width wide field at 2x text: $shown shown', (tester) async {
      await _pump(tester, search(width));
      await _type(tester, focus);
      // Focus exclusion follows the layout by one frame.
      await tester.pump();
      _expectFits(tester, shown: shown);
      final semantics = tester.ensureSemantics();
      expect(find.semantics.byLabel('L.search'), shown == 2 ? findsOneWidget : findsNothing);
      semantics.dispose();
    });
  }

  testWidgets('a dropped control returns when the field widens', (tester) async {
    await _pump(tester, search(160));
    await _type(tester, focus);
    await tester.pump();
    _expectFits(tester, shown: 1);
    await _pump(tester, search(320));
    await tester.pumpAndSettle();
    _expectFits(tester, shown: 2);
  });

  testWidgets('App actions and submit drop from the end at 320 and 2x text', (tester) async {
    var acted = 0;
    await _pump(
      tester,
      SizedBox(
        width: 172,
        child: FrostSearchInput(
          controller: controller,
          focusNode: focus,
          placeholder: 'Search',
          leadingIcon: true,
          onSubmitted: (_) {},
          actions: [FrostButton.icon(icon: testIcons.filter, label: 'Filter', size: FrostControlSize.compact, onPressed: () => acted++)],
        ),
      ),
    );
    await _type(tester, focus);
    await tester.pump();
    // Clear and the App action fit; submit, the last, is dropped.
    _expectFits(tester, shown: 2);
    await tester.tap(find.byWidgetPredicate((w) => w is FrostButton && w.label == 'Filter'));
    expect(acted, 1);
  });

  testWidgets('caption search at 320 and 2x text keeps its trailing inside the frame', (tester) async {
    await _pump(
      tester,
      SizedBox(
        width: 160,
        height: 48,
        child: FrostCaptionSearch(controller: controller, focusNode: focus, placeholder: 'Search', onSubmitted: (_) {}),
      ),
    );
    expect(tester.takeException(), isNull);
    await _type(tester, focus);
    await tester.pump();
    _expectFits(tester, shown: 2);
  });

  testWidgets('a password field keeps its visibility toggle before its trailing', (tester) async {
    await _pump(
      tester,
      SizedBox(
        width: 140,
        child: FrostTextField.secure(controller: controller, focusNode: focus, placeholder: 'Password'),
      ),
    );
    await _type(tester, focus);
    await tester.pump();
    _expectFits(tester, shown: 1);
  });

  testWidgets('a page header search at 320 and 2x text does not overflow', (tester) async {
    await _pump(
      tester,
      FrostPageHeader(
        title: const FrostText('Search'),
        middle: FrostSearchInput(controller: controller, focusNode: focus, placeholder: 'Search', leadingIcon: true, onSubmitted: (_) {}),
        actions: [FrostToolbarItem.action(icon: testIcons.edit, label: 'Edit', onPressed: () {})],
      ),
    );
    await _type(tester, focus);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
