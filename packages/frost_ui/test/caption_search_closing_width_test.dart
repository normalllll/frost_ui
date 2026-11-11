import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/overlays/_popover_surface.dart';

import 'support.dart';
import 'window_caption_test.dart' show FakeWindow;

void main() {
  testWidgets('the caption dropdown keeps its shown width while it fades out', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1147, 717);
    addTearDown(tester.view.reset);
    final controller = TextEditingController(), focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      frostTestApp(
        FrostWindowCaptionScope(
          window: FakeWindow(),
          child: FrostShell(
            destinations: const [FrostNavDestination(icon: FrostIconData.glyph(Icons.home), label: 'Home')],
            selectedIndex: 0,
            atDestinationRoot: true,
            onDestinationSelected: (_) {},
            canGoBack: false,
            onBack: () {},
            showsMobileNavigation: true,
            brand: const FrostShellBrand(expanded: Text('Application')),
            titleBarSearch: FrostCaptionSearch(
              controller: controller,
              focusNode: focus,
              placeholder: 'Search',
              onSubmitted: (_) {},
              content: Row(
                children: [
                  for (var i = 0; i < 4; i++)
                    Expanded(
                      child: FrostMediaCard(
                        media: const ColoredBox(color: Color(0xFF8888CC)),
                        aspectRatio: 3 / 2,
                        overlay: const Column(mainAxisSize: MainAxisSize.min, children: [Text('#tag'), Text('translation')]),
                      ),
                    ),
                ],
              ),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    final rest = tester.getSize(find.byType(FrostCaptionSearch)).width;
    focus.requestFocus();
    await tester.pumpAndSettle();
    final shown = tester.getSize(find.byType(FrostPopoverSurface)).width;
    expect(shown, greaterThan(rest), reason: 'the field widens while open, so the close has a width to keep');
    focus.unfocus();
    var frames = 0;
    for (; frames < 60 && find.byType(FrostPopoverSurface).evaluate().isNotEmpty; frames++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull, reason: 'frame $frames');
      if (find.byType(FrostPopoverSurface).evaluate().isEmpty) break;
      expect(tester.getSize(find.byType(FrostPopoverSurface)).width, shown, reason: 'frame $frames');
    }
    expect(frames, greaterThan(1), reason: 'the dropdown fades over several frames');
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(FrostCaptionSearch)).width, rest);

    // The next open follows the field again.
    focus.requestFocus();
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(FrostPopoverSurface)).width, shown);
  });
}
