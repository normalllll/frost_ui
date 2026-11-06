import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/lists/_row_scope.dart';
import 'package:frost_ui/src/overlays/_popover_surface.dart';

import 'support.dart';

Finder _row(String text) => find.byWidgetPredicate((w) => w is FrostListRow && w.title == text);

void main() {
  late TextEditingController controller;
  late FocusNode focus;
  late List<String> selected;
  late List<String> submitted;
  setUp(() {
    controller = TextEditingController();
    focus = FocusNode();
    selected = [];
    submitted = [];
  });
  tearDown(() {
    controller.dispose();
    focus.dispose();
  });

  Widget groups({bool keepsOpen = false}) => FrostSearchSection(
    title: 'Tags',
    children: [
      for (final tag in ['sky', 'cloud', 'sea'])
        FrostSearchSuggestionRow(
          label: tag,
          keepsOpen: keepsOpen,
          onSelected: () {
            selected.add(tag);
            controller.text = '${controller.text}$tag ';
          },
        ),
    ],
  );

  for (final caption in [false, true]) {
    final name = caption ? 'FrostCaptionSearch' : 'FrostSearchInput';

    Future<void> pump(WidgetTester tester, Widget content) => tester.pumpWidget(
      frostTestApp(
        Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 360,
            height: caption ? 32 : null,
            child: caption
                ? FrostCaptionSearch(controller: controller, focusNode: focus, placeholder: 'Search', onSubmitted: submitted.add, content: content)
                : FrostSearchInput.suggesting(controller: controller, focusNode: focus, placeholder: 'Search', onSubmitted: submitted.add, content: content),
          ),
        ),
      ),
    );

    Finder panel(Finder child) => find.descendant(of: find.byType(FrostPopoverSurface), matching: child);

    Future<void> open(WidgetTester tester) async {
      focus.requestFocus();
      controller.text = "a";
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('$name: a keep-open suggestion stays open after a tap and after Enter', (tester) async {
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await pump(tester, groups(keepsOpen: true));
      await open(tester);
      expect(panel(_row('cloud')), findsOneWidget);
      final editor = tester.state<EditableTextState>(find.byType(EditableText));

      await tester.tap(_row('cloud'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(selected, ['cloud']);
      expect(controller.text, 'acloud ');
      expect(panel(_row('cloud')), findsOneWidget);
      expect(focus.hasFocus, isTrue);
      expect(tester.state<EditableTextState>(find.byType(EditableText)), same(editor));

      // Nothing is highlighted, so an arrow key starts at the first item.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 300));
      expect(selected, ['cloud', 'sky']);
      expect(submitted, isEmpty);
      expect(panel(_row('sea')), findsOneWidget);
      expect(focus.hasFocus, isTrue);

      // Esc still closes it.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(panel(_row('sea')), findsNothing);
      expect(tester.state<EditableTextState>(find.byType(EditableText)), same(editor));
    });

    bool highlighted(WidgetTester tester) => panel(find.byType(FrostListRow)).evaluate().any((row) => FrostListItemScope.of(row)?.highlighted ?? false);

    testWidgets('$name: Enter submits and closes after a tap on a keep-open suggestion', (tester) async {
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await pump(tester, groups(keepsOpen: true));
      await open(tester);
      await tester.tap(_row('cloud'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(panel(_row('cloud')), findsOneWidget);
      expect(highlighted(tester), isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selected, ['cloud']);
      expect(submitted, ['acloud ']);
      expect(panel(_row('cloud')), findsNothing);
    });

    testWidgets('$name: the input action submits and closes after a keep-open selection', (tester) async {
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await pump(tester, groups(keepsOpen: true));
      await open(tester);
      await tester.tap(_row('sky'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(selected, ['sky']);
      expect(submitted, ['asky ']);
      expect(panel(_row('sky')), findsNothing);
    });

    testWidgets('$name: a mouse left over the clicked row takes no highlight until it moves', (tester) async {
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await pump(tester, groups(keepsOpen: true));
      await open(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: tester.getCenter(_row('cloud')));
      await tester.pump();
      await mouse.down(tester.getCenter(_row('cloud')));
      await tester.pump();
      await mouse.up();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(selected, ['cloud']);
      expect(highlighted(tester), isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selected, ['cloud']);
      expect(submitted, ['acloud ']);
    });

    testWidgets('$name: a real pointer move after a keep-open click highlights again', (tester) async {
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await pump(tester, groups(keepsOpen: true));
      await open(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: tester.getCenter(_row('cloud')));
      await tester.pump();
      await mouse.down(tester.getCenter(_row('cloud')));
      await tester.pump();
      await mouse.up();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await mouse.moveBy(const Offset(4, 0));
      await tester.pump();
      expect(highlighted(tester), isTrue);
    });

    testWidgets('$name: a keyboard selection that rebuilds the suggestions leaves no highlight', (tester) async {
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      // The app builds new suggestion objects as the query changes.
      await tester.pumpWidget(
        frostTestApp(
          Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 360,
              height: caption ? 32 : null,
              child: ListenableBuilder(
                listenable: controller,
                builder: (_, _) => caption
                    ? FrostCaptionSearch(
                        controller: controller,
                        focusNode: focus,
                        placeholder: 'Search',
                        onSubmitted: submitted.add,
                        content: groups(keepsOpen: true),
                      )
                    : FrostSearchInput.suggesting(
                        controller: controller,
                        focusNode: focus,
                        placeholder: 'Search',
                        onSubmitted: submitted.add,
                        content: groups(keepsOpen: true),
                      ),
              ),
            ),
          ),
        ),
      );
      await open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(highlighted(tester), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(selected, ['sky']);
      expect(highlighted(tester), isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selected, ['sky']);
      expect(submitted, ['asky ']);
      expect(panel(_row('sky')), findsNothing);
    });

    testWidgets('$name: a normal suggestion still closes the list', (tester) async {
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await pump(tester, groups());
      await open(tester);
      expect(panel(_row('cloud')), findsOneWidget);
      await tester.tap(_row('cloud'));
      await tester.pumpAndSettle();
      expect(selected, ['cloud']);
      expect(panel(_row('cloud')), findsNothing);
    });
  }
}
