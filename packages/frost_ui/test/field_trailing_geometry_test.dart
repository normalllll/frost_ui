import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

void main() {
  Future<void> pump(WidgetTester tester, TargetPlatform platform, Widget child, {TextDirection direction = TextDirection.ltr}) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      frostTestApp(
        Directionality(
          textDirection: direction,
          child: Center(child: SizedBox(width: 300, child: child)),
        ),
        platform: platform,
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder button(String label) => find.byWidgetPredicate((w) => w is FrostButton && w.label == label);
  Finder glyph(String label) => find.descendant(of: button(label), matching: find.byType(FrostIcon));

  const clear = 'L.clearText', submit = 'L.search';
  // Icon-to-icon gap and icon-to-field-end distance in a compact field.
  const rules = {TargetPlatform.windows: (gap: 16.0, end: 10.0, height: 32.0), TargetPlatform.android: (gap: 24.0, end: 12.0, height: 36.0)};

  for (final MapEntry(key: platform, value: rule) in rules.entries) {
    for (final direction in TextDirection.values) {
      testWidgets('clear and submit sit close and concentric on $platform $direction', (tester) async {
        final controller = TextEditingController(text: 'muryo');
        final focus = FocusNode();
        addTearDown(controller.dispose);
        addTearDown(focus.dispose);
        await pump(
          tester,
          platform,
          FrostSearchInput(controller: controller, focusNode: focus, placeholder: 'Search', leadingIcon: true, size: FrostControlSize.compact, onSubmitted: (_) {}),
          direction: direction,
        );
        focus.requestFocus();
        await tester.pumpAndSettle();
        final field = tester.getRect(find.byType(FrostTextField));
        final first = tester.getRect(glyph(clear)), last = tester.getRect(glyph(submit));
        final ltr = direction == TextDirection.ltr;
        expect(ltr ? last.left - first.right : first.left - last.right, rule.gap);
        expect(ltr ? field.right - last.right : last.left - field.left, rule.end);
        final firstTarget = tester.getRect(button(clear)), lastTarget = tester.getRect(button(submit));
        expect(lastTarget.height, rule.height);
        expect(firstTarget.overlaps(lastTarget), isFalse);
        expect(lastTarget.right, lessThanOrEqualTo(field.right));
        expect(lastTarget.left, greaterThanOrEqualTo(field.left));
      });
    }

    testWidgets('a clear button alone keeps that distance and an empty end keeps the inset on $platform', (tester) async {
      final controller = TextEditingController(text: 'muryo');
      addTearDown(controller.dispose);
      await pump(tester, platform, FrostTextField(controller: controller, clearable: true, size: FrostControlSize.compact));
      final field = tester.getRect(find.byType(FrostTextField));
      expect(field.right - tester.getRect(glyph(clear)).right, rule.end);

      controller.clear();
      await tester.pumpAndSettle();
      expect(field.right - tester.getRect(find.byType(EditableText)).right, 10, reason: 'an empty end keeps the field inset');
    });

    testWidgets('a token search places its buttons the same way on $platform', (tester) async {
      final controller = FrostTokenEditingController(rules: const []);
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      controller.text = 'muryo';
      await pump(tester, platform, FrostSearchInput(controller: controller, focusNode: focus, placeholder: 'Search', size: FrostControlSize.compact, onSubmitted: (_) {}));
      focus.requestFocus();
      await tester.pumpAndSettle();
      final field = tester.getRect(find.byType(FrostTokenField));
      final first = tester.getRect(glyph(clear)), last = tester.getRect(glyph(submit));
      expect(last.left - first.right, rule.gap);
      expect(field.right - last.right, rule.end);
    });

    testWidgets('a trailing that is not an icon button stays on the inset on $platform', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pump(tester, platform, FrostTextField(controller: controller, trailing: const Text('kg'), size: FrostControlSize.compact));
      expect(tester.getRect(find.byType(FrostTextField)).right - tester.getRect(find.text('kg')).right, 10);
    });
  }

  testWidgets('the editor width changes continuously as the clear button expands', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await pump(tester, TargetPlatform.windows, FrostTextField(controller: controller, clearable: true, size: FrostControlSize.compact));
    var width = tester.getSize(find.byType(EditableText)).width;
    final start = width;
    controller.text = 'a';
    for (var frame = 0; frame < 40; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      final next = tester.getSize(find.byType(EditableText)).width;
      expect((next - width).abs(), lessThan(12), reason: 'frame $frame');
      width = next;
    }
    expect(width, start - 24, reason: 'a 32 target less the 8 it takes from the inset');
  });
}
