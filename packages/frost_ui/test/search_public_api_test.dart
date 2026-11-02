import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'support.dart';

void main() {
  test('search extension compiles from widgets and frost_ui only', () {
    final controller = TextEditingController(), focus = FocusNode();
    final widget = FrostSearchInput.suggesting(
      controller: controller,
      focusNode: focus,
      placeholder: 'Search',
      loading: true,
      message: 'Loading matches',
      placement: FrostSuggestionPlacement.inline,
      onSubmitted: (_) {},
      suggestions: [
        FrostSearchSuggestionGroup(
          title: 'Recent',
          items: [FrostSearchSuggestion(label: 'Term', icon: null, dataColor: 1, detail: 'Detail', value: '42', onSelected: () {}, onRemove: () {})],
        ),
      ],
    );
    expect(widget, isA<Widget>());
    expect(FrostSearchInput(controller: controller, focusNode: focus, placeholder: 'Search', onSubmitted: (_) {}), isA<Widget>());
    controller.dispose();
    focus.dispose();
  });

  for (final suggesting in [false, true]) {
    testWidgets('blank text has nothing to submit by button, Enter or IME; suggesting=$suggesting', (tester) async {
      for (final (text, expected) in [
        ('   ', <String>[]),
        ('abc', ['abc', 'abc']),
      ]) {
        final submitted = <String>[];
        final controller = TextEditingController(text: text), focus = FocusNode();
        addTearDown(controller.dispose);
        addTearDown(focus.dispose);
        await tester.pumpWidget(
          frostTestApp(
            Center(
              child: SizedBox(
                width: 400,
                child: suggesting
                    ? FrostSearchInput.suggesting(controller: controller, focusNode: focus, placeholder: 'q', onSubmitted: submitted.add, suggestions: const [])
                    : FrostSearchInput(controller: controller, focusNode: focus, placeholder: 'q', onSubmitted: submitted.add),
              ),
            ),
          ),
        );
        focus.requestFocus();
        await tester.pump();
        final button = tester.widget<FrostButton>(find.byWidgetPredicate((widget) => widget is FrostButton && widget.label == 'L.search'));
        expect(button.onPressed == null, text.trim().isEmpty);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pump();
        expect(submitted, expected, reason: 'text "$text"');
        await tester.pumpWidget(const SizedBox());
      }
    });
  }
}
