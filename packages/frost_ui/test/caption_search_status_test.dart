import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/overlays/_popover_surface.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

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

  Future<void> pump(WidgetTester tester, {required double width, bool loading = false, String? message, List<Widget> suggestions = const []}) =>
      tester.pumpWidget(
        frostTestApp(
          Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width,
              height: 32,
              child: FrostCaptionSearch(
                controller: controller,
                focusNode: focus,
                placeholder: 'Search',
                onSubmitted: (_) {},
                content: searchContent(suggestions, loading: loading, message: message),
              ),
            ),
          ),
        ),
      );

  Finder panelStatus(Finder child) => find.descendant(of: find.byType(FrostPopoverSurface), matching: child);

  testWidgets('caption dropdown shows loading while typing, retaining suggestions', (tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    final suggestions = [
      FrostSearchSection(
        children: [FrostSearchSuggestionRow(label: 'cat', onSelected: () {})],
      ),
    ];
    await pump(tester, width: 360, loading: true, suggestions: suggestions);
    focus.requestFocus();
    controller.text = 'ca';
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(panelStatus(find.byType(FrostActivityIndicator)), findsOneWidget);
    expect(panelStatus(find.text('cat')), findsOneWidget);
    expect(focus.hasFocus, isTrue);

    await pump(tester, width: 360, suggestions: suggestions);
    await tester.pumpAndSettle();
    expect(panelStatus(find.byType(FrostActivityIndicator)), findsNothing);
    expect(panelStatus(find.text('cat')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('caption dropdown shows an empty or failure message without suggestions', (tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await pump(tester, width: 360, message: 'No suggestions');
    focus.requestFocus();
    await tester.pumpAndSettle();
    expect(panelStatus(find.text('No suggestions')), findsOneWidget);

    await pump(tester, width: 360, message: 'Could not load suggestions');
    await tester.pumpAndSettle();
    expect(panelStatus(find.text('Could not load suggestions')), findsOneWidget);
    expect(find.text('No suggestions'), findsNothing);

    // The message is status, not a selectable item: Enter still submits.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a resting caption icon shows no dropdown status', (tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await pump(tester, width: 100, loading: true, message: 'No suggestions');
    await tester.pumpAndSettle();
    expect(find.byType(FrostPopoverSurface), findsNothing);
    expect(find.text('No suggestions'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
