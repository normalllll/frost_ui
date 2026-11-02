import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'support.dart';
import 'window_caption_test.dart' show FakeWindow;

void main() {
  testWidgets('caption search keeps one control row in the caption and hides it for large text header', (tester) async {
    tester.view.physicalSize = const Size(1200, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final window = FakeWindow();
    final editing = TextEditingController();
    final focus = FocusNode();
    var scale = 1.0;
    Widget tree() => frostTestApp(
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: FrostWindowCaptionScope(
            window: window,
            child: FrostShell(
              destinations: const [FrostNavDestination(icon: FrostIconData.glyph(Icons.home), label: 'Home')],
              selectedIndex: 0,
              atDestinationRoot: true,
              onDestinationSelected: (_) {},
              canGoBack: false,
              onBack: () {},
              showsMobileNavigation: true,
              brand: const FrostShellBrand(expanded: Text('Application')),
              titleBarSearch: FrostCaptionSearch(controller: editing, focusNode: focus, placeholder: 'Search', onSubmitted: (_) {}),
              child: const SizedBox.expand(key: ValueKey('content')),
            ),
          ),
        ),
      ),
    );
    final search = find.byType(FrostCaptionSearch);
    final field = find.byType(FrostSearchInput);

    await tester.pumpWidget(tree());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getRect(search).top, lessThan(40));
    final element = tester.element(field);

    for (final value in [1.3, 2.0]) {
      scale = value;
      await tester.pumpWidget(tree());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'text scale $value');
      // Out of the row: hidden, taking no room, the editor alive.
      expect(search, findsNothing, reason: 'text scale $value');
      expect(tester.element(find.byType(FrostSearchInput, skipOffstage: false)), same(element), reason: 'the editor survives');
    }

    scale = 1;
    await tester.pumpWidget(tree());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getRect(search).top, lessThan(40));
    expect(tester.element(field), same(element));
    await tester.enterText(find.byType(TextField), 'query');
    expect(editing.text, 'query');

    await tester.pumpWidget(const SizedBox());
    editing.dispose();
    focus.dispose();
    window.dispose();
  });

  testWidgets('caption search under unbounded height and width takes one row at the resting width', (tester) async {
    final editing = TextEditingController();
    final focus = FocusNode();
    await tester.pumpWidget(
      frostTestApp(
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [FrostCaptionSearch(controller: editing, focusNode: focus, placeholder: 'Search', onSubmitted: (_) {})],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final rect = tester.getRect(find.byType(FrostCaptionSearch));
    expect(rect.width, 360);
    expect(rect.height, moreOrLessEquals(tester.getRect(find.byType(FrostSearchInput)).height));
    await tester.pumpWidget(const SizedBox());
    editing.dispose();
    focus.dispose();
  });
}
