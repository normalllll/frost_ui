import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/overlays/_popover_surface.dart';

import 'support.dart';
import 'window_caption_test.dart' show FakeWindow;

void main() {
  for (final size in [const Size(1147, 717), const Size(1280, 800)]) {
    testWidgets('the caption dropdown uses the content area below the field and scrolls inside at $size', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      final controller = TextEditingController(), focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      FrostSearchSuggestionGroup group(String title) => FrostSearchSuggestionGroup(
        title: title,
        actionLabel: 'Act',
        onAction: () {},
        items: [for (var i = 0; i < 12; i++) FrostSearchSuggestion(label: '$title $i', onSelected: () {})],
      );
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
                suggestions: [group('Recent'), group('Mine'), group('Common')],
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pumpAndSettle();
      final panel = tester.getRect(find.byType(FrostPopoverSurface));
      expect(panel.bottom, size.height - 8, reason: 'down to the usual panel margin');
      final visible = find.byType(FrostListRow).hitTestable().evaluate().where((e) {
        final rect = tester.getRect(find.byWidget(e.widget));
        return rect.top >= panel.top && rect.bottom <= panel.bottom;
      }).length;
      // Three titled groups of 36-high rows: at least 16 at 1147×717 and 17 at
      // 1280×800, depending on where group titles fall (half the window, the
      // previous limit, held 8).
      expect(visible, greaterThanOrEqualTo(size.height == 717 ? 16 : 17));
      expect(find.text('Common 11'), findsNothing, reason: 'the rest scrolls inside the panel');
      expect(tester.takeException(), isNull);
    });
  }
}
