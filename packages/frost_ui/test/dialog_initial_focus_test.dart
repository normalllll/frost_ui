import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'dialog_sheet_test.dart' show launch;

void main() {
  for (final delayed in [false, true]) {
    testWidgets('a field takes focus only through its own autofocus; delayed=$delayed', (tester) async {
      for (final autofocus in [false, true]) {
        var ready = !delayed;
        late StateSetter update;
        final field = FocusNode();
        await launch(
          tester,
          (context) => showFrostDialog(
            context: context,
            builder: (_) => FrostDialog(
              title: 'Push',
              content: StatefulBuilder(
                builder: (_, set) {
                  update = set;
                  return FrostFormSection(
                    children: [
                      const FrostCopyable(text: r'V:\Code\project'),
                      if (ready) FrostTextField(label: 'Target', focusNode: field, autofocus: autofocus) else const SizedBox(height: 32),
                    ],
                  );
                },
              ),
              actions: const [],
            ),
          ),
        );
        if (delayed) {
          update(() => ready = true);
          await tester.pumpAndSettle();
        }
        expect(field.hasPrimaryFocus, autofocus);
        await tester.pumpWidget(const SizedBox());
        field.dispose();
      }
    });
  }
  for (final delayed in [false, true]) {
    testWidgets('an autofocus field takes focus over the default action, and the copy button stays reachable; delayed=$delayed', (tester) async {
      var ready = !delayed;
      late StateSetter update;
      final field = FocusNode();
      await launch(
        tester,
        (context) => showFrostDialog(
          context: context,
          builder: (_) => FrostDialog(
            title: 'Push',
            content: StatefulBuilder(
              builder: (_, set) {
                update = set;
                return FrostFormSection(
                  children: [
                    const FrostCopyable(text: r'D:\work\gitbound', monospace: true),
                    if (ready) FrostTextField(label: 'Target branch', focusNode: field, autofocus: true) else const SizedBox(height: 32),
                  ],
                );
              },
            ),
            actions: [
              FrostDialogAction(label: 'Close', value: false, role: FrostButtonRole.cancel),
              FrostDialogAction(label: 'Preview', value: true, isDefault: true),
            ],
          ),
        ),
      );
      if (delayed) {
        update(() => ready = true);
        await tester.pumpAndSettle();
      }
      expect(field.hasPrimaryFocus, isTrue);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus!.context!.findAncestorWidgetOfExactType<FrostCopyable>(), isNotNull);
      await tester.pumpWidget(const SizedBox());
      field.dispose();
    });
  }
  testWidgets('a late field does not take focus after the user navigates', (tester) async {
    var ready = false;
    late StateSetter update;
    final field = FocusNode();
    await launch(
      tester,
      (context) => showFrostDialog(
        context: context,
        builder: (_) => FrostDialog(
          title: 'Push',
          content: StatefulBuilder(
            builder: (_, set) {
              update = set;
              return FrostFormSection(
                children: [
                  const FrostCopyable(text: 'Repository'),
                  if (ready) FrostTextField(focusNode: field),
                ],
              );
            },
          ),
          actions: [FrostDialogAction(label: 'Cancel', value: false, role: FrostButtonRole.cancel)],
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    final chosen = FocusManager.instance.primaryFocus;
    update(() => ready = true);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, same(chosen));
    expect(field.hasFocus, isFalse);
    await tester.pumpWidget(const SizedBox());
    field.dispose();
  });
  testWidgets('Tab from the opened dialog reaches its first control', (tester) async {
    final text = FocusNode();
    await launch(
      tester,
      (context) => showFrostDialog(
        context: context,
        builder: (_) => FrostDialog(
          title: 'Push',
          content: FrostFormSection(
            children: [
              FrostPicker<int>.menu(
                label: 'Branch',
                value: 1,
                options: const [FrostPickerOption(value: 1, label: 'main')],
                onChanged: (_) {},
              ),
              FrostTextField(focusNode: text),
            ],
          ),
          actions: const [],
        ),
      ),
    );
    expect(text.hasFocus, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(text.hasFocus, isFalse);
    expect(FocusManager.instance.primaryFocus!.context!.findAncestorWidgetOfExactType<FrostPicker<int>>(), isNotNull);
    await tester.pumpWidget(const SizedBox());
    text.dispose();
  });
}
