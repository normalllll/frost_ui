import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/overlays/_popover_surface.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';
import 'window_caption_test.dart' show FakeWindow;

void main() {
  testWidgets('hiding the title content closes its open suggestions and keeps the text', (tester) async {
    tester.view.physicalSize = const Size(1100, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final window = FakeWindow();
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(window.dispose);
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    var taps = 0;
    await tester.pumpWidget(
      frostTestApp(
        FrostWindowCaptionScope(
          window: window,
          child: FrostShell(
            destinations: const [
              FrostNavDestination(icon: FrostIconData.glyph(Icons.home), label: 'Home'),
              FrostNavDestination(icon: FrostIconData.glyph(Icons.search), label: 'Find'),
            ],
            selectedIndex: 0,
            atDestinationRoot: true,
            onDestinationSelected: (_) {},
            canGoBack: false,
            onBack: () {},
            showsMobileNavigation: true,
            titleBarContent: FrostCaptionSearch(
              controller: controller,
              focusNode: focus,
              placeholder: 'Search',
              content: searchContent([
                FrostSearchSection(
                  children: [
                    for (final label in ['sky', 'sky blue', 'skyline']) FrostSearchSuggestionRow(label: label, onSelected: () {}),
                  ],
                ),
              ]),
              onSubmitted: (_) {},
            ),
            child: FrostShellDestination(
              child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => taps++, child: const SizedBox.expand()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(EditableText));
    await tester.enterText(find.byType(EditableText), 'sky');
    await tester.pumpAndSettle();
    expect(find.text('skyline'), findsOneWidget);
    final panel = tester.getRect(find.byType(FrostPopoverSurface));

    tester.view.physicalSize = const Size(405, 853);
    await tester.pump();
    await tester.pump();
    expect(find.text('skyline', skipOffstage: false), findsNothing);
    expect(find.byType(FrostPopoverSurface, skipOffstage: false), findsNothing);
    await tester.tapAt(Offset(panel.center.dx.clamp(20, 380), panel.center.dy));
    await tester.pump();
    expect(taps, 1, reason: 'the content under the closed panel takes the tap');

    tester.view.physicalSize = const Size(1100, 780);
    await tester.pumpAndSettle();
    expect(controller.text, 'sky');
    expect(tester.takeException(), isNull);
  });
}
