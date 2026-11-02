import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_field_frame.dart';
import 'display_badges_test.dart' show display;
import 'number_input_test.dart' show numberBorder;
import 'selection_input_test.dart' show inputOpacity;

Finder get fieldChrome => find.descendant(of: find.byType(FrostTextField), matching: find.byType(FrostFieldPaint)).first;
Finder get visibilityButton => find.byType(FrostButton);

void main() {
  for (final density in FrostDensity.values) {
    for (final direction in TextDirection.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('multiline and secure share real field geometry $density $direction $scale', (tester) async {
          final controller = TextEditingController(text: 'Four');
          await display(
            tester,
            FrostTextField(controller: controller, minLines: 3, maxLines: 5),
            width: 320,
            density: density,
            direction: direction,
            scale: scale,
          );
          final tokens = FrostThemeTokens.of(tester.element(find.byType(FrostTextField)));
          final paint = tester.renderObject<RenderFrostFieldPaint>(fieldChrome);
          final decoration = ShapeDecoration(color: paint.fill, shape: paint.shape);
          expect(decoration.color, Color.alphaBlend(tokens.textPrimary.withValues(alpha: tokens.isDark ? .05 : .035), tokens.surface));
          expect(decoration.shape, isA<RoundedSuperellipseBorder>());
          final field = tester.widget<TextField>(find.byType(TextField));
          expect(field.minLines, 3);
          expect(field.maxLines, 5);
          expect(field.keyboardType, TextInputType.multiline);
          expect(field.inputFormatters, isNull);
          final frame = tester.getRect(fieldChrome), editor = tester.getRect(find.byType(EditableText));
          expect(editor.top - frame.top, closeTo(frame.bottom - editor.bottom, .001));
          await tester.pumpWidget(const SizedBox());
          controller.dispose();
          await display(
            tester,
            const FrostTextField.secure(label: 'Password'),
            width: 320,
            density: density,
            direction: direction,
            scale: scale,
          );
          final secure = tester.widget<TextField>(find.byType(TextField));
          expect(secure.obscureText, true);
          expect(secure.keyboardType, TextInputType.visiblePassword);
          expect(secure.autocorrect, false);
          expect(secure.enableSuggestions, false);
          expect(secure.minLines, 1);
          expect(secure.maxLines, 1);
          expect(tester.getSize(visibilityButton).height, greaterThanOrEqualTo(FrostDensity.of(tester.element(visibilityButton)).targetHeight));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  for (final reduced in [false, true]) {
    testWidgets('multiline growth bounds, layout middle frame and no truncation reduced=$reduced', (tester) async {
      final controller = TextEditingController();
      await display(tester, FrostTextField(controller: controller, minLines: 2, maxLines: 4), width: 320, reduced: reduced);
      final small = tester.getSize(find.byType(FrostTextField)).height;
      await tester.enterText(find.byType(TextField), 'a\nb\nc\nd\ne\nf');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 80));
      final middle = tester.getSize(find.byType(FrostTextField)).height;
      await tester.pumpAndSettle();
      final large = tester.getSize(find.byType(FrostTextField)).height;
      expect(middle, greaterThan(small));
      expect(middle, reduced ? large : lessThan(large));
      expect(controller.text, 'a\nb\nc\nd\ne\nf');
      final editable = tester.allRenderObjects.whereType<RenderEditable>().single;
      expect(editable.maxLines, 4);
      expect((editable.offset as ScrollPosition).maxScrollExtent, greaterThan(0));
      await tester.enterText(find.byType(TextField), 'a\nb\nc\nd\ne\nf\ng\nh');
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(FrostTextField)).height, large);
      await tester.enterText(find.byType(TextField), '😀');
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(FrostTextField)).height, small);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      expect(tester.takeException(), isNull);
    });
    testWidgets('secure visibility keeps full selection and focus, hover and disabled ink reduced=$reduced', (tester) async {
      final controller = TextEditingController(text: 'secret')..selection = const TextSelection(baseOffset: 1, extentOffset: 4);
      final focus = FocusNode();
      var enabled = true, changes = 0;
      late StateSetter update;
      await display(
        tester,
        StatefulBuilder(
          builder: (_, set) {
            update = set;
            return FrostTextField.secure(controller: controller, focusNode: focus, enabled: enabled, onChanged: (_) => changes++);
          },
        ),
        width: 320,
        reduced: reduced,
      );
      focus.requestFocus();
      await tester.pumpAndSettle();
      final selection = controller.selection;
      expect(numberBorder(tester).a, greaterThan(0));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(visibilityButton));
      await tester.pumpAndSettle();
      final press = await tester.startGesture(tester.getCenter(visibilityButton), pointer: 7);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      await press.up();
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).obscureText, false);
      expect(controller.selection, selection);
      expect(focus.hasFocus, true);
      expect(changes, 0);
      final labels = FrostScope.labelsOf(tester.element(find.byType(FrostTextField)));
      expect(tester.widget<FrostButton>(visibilityButton).label, labels.hidePassword);
      await tester.tap(visibilityButton);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).obscureText, true);
      expect(controller.selection, selection);
      expect(focus.hasFocus, true);
      expect(tester.widget<FrostButton>(visibilityButton).label, labels.showPassword);
      update(() => enabled = false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      final opacity = inputOpacity(tester.allRenderObjects.whereType<RenderEditable>().single);
      expect(opacity, reduced ? .38 : inExclusiveRange(.38, 1));
      await tester.pumpAndSettle();
      expect(inputOpacity(tester.allRenderObjects.whereType<RenderEditable>().single), closeTo(.38, .001));
      expect(inputOpacity(tester.renderObject(find.byType(FrostIcon))), closeTo(.38, .001));
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      focus.dispose();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('an independently disabled accessory still dims in an enabled field', (tester) async {
    await display(
      tester,
      Builder(
        builder: (context) => FrostTextField(
          trailing: FrostButton.icon(icon: FrostIconSet.of(context).eye, label: 'Unavailable', onPressed: null),
        ),
      ),
    );
    expect(inputOpacity(tester.renderObject(find.byType(FrostIcon))), closeTo(.38, .001));
    expect(inputOpacity(tester.allRenderObjects.whereType<RenderEditable>().single), 1);
    expect(tester.takeException(), isNull);
  });
}
