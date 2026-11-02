import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'support.dart';

Finder get handles => find.byWidgetPredicate(
  (widget) => widget is GestureDetector && widget.child is SizedBox && (widget.child! as SizedBox).width == 18 && (widget.child! as SizedBox).height == 22,
);

void main() {
  for (final platform in [TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux]) {
    for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.stylus]) {
      testWidgets('$platform autofocus has no handles; $kind selection has handles until keyboard input', (tester) async {
        final controller = TextEditingController(text: 'Existing text');
        final focus = FocusNode();
        await tester.pumpWidget(
          frostTestApp(
            Builder(
              builder: (context) => Theme(
                data: Theme.of(context).copyWith(platform: platform),
                child: Center(
                  child: SizedBox(
                    width: 300,
                    child: FrostTextField(controller: controller, focusNode: focus, autofocus: true),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(focus.hasFocus, isTrue);
        expect(handles, findsNothing);
        final editor = tester.state<EditableTextState>(find.byType(EditableText));
        final gesture = await tester.startGesture(tester.getCenter(find.byType(EditableText)), kind: kind);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(handles, findsWidgets);
        expect(tester.state<EditableTextState>(find.byType(EditableText)), same(editor));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(handles, findsNothing);
        expect(focus.hasFocus, isTrue);
        await tester.pumpWidget(const SizedBox());
        focus.dispose();
        controller.dispose();
      });
    }
  }
}
