import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/layout/window_caption_scope.dart' show FrostHitKind;
import 'package:frost_ui/src/navigation/window_caption.dart' show FrostCaptionButtons;
import 'package:material_ui/material_ui.dart';

import 'support.dart';
import 'window_caption_test.dart' show FakeWindow;

const _size = Size(1147, 717);

void main() {
  late TextEditingController editing;
  late FocusNode focus;
  setUp(() {
    editing = TextEditingController();
    focus = FocusNode();
  });
  tearDown(() {
    editing.dispose();
    focus.dispose();
  });

  Future<FakeWindow> pump(WidgetTester tester, {FrostCaptionSearchPlacement? placement, TextDirection direction = TextDirection.ltr}) async {
    tester.view.physicalSize = _size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final window = FakeWindow();
    final search = FrostCaptionSearch(controller: editing, focusNode: focus, placeholder: 'Search', onSubmitted: (_) {}, content: const SizedBox());
    await tester.pumpWidget(
      frostTestApp(
        Directionality(
          textDirection: direction,
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
              titleBarSearch: search,
              titleBarSearchPlacement: placement ?? FrostCaptionSearchPlacement.center,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return window;
  }

  Rect search(WidgetTester tester) => tester.getRect(find.byType(FrostSearchInput));
  Rect buttons(WidgetTester tester) => tester.getRect(find.byType(FrostCaptionButtons));

  for (final direction in TextDirection.values) {
    final ltr = direction == TextDirection.ltr;
    testWidgets('an end placed search sits beside the window buttons and expands away from them ($direction)', (tester) async {
      await pump(tester, placement: FrostCaptionSearchPlacement.end, direction: direction);
      final rest = search(tester), controls = buttons(tester);
      if (ltr) {
        expect(controls.left - rest.right, moreOrLessEquals(FrostGap.related, epsilon: .5));
      } else {
        // The window buttons stay on the right; the row's end is on the left.
        expect(rest.left, lessThan(80));
      }
      expect(rest.width, lessThan(360));

      focus.requestFocus();
      await tester.pumpAndSettle();
      final open = search(tester);
      expect(open.width, greaterThan(rest.width));
      expect(ltr ? open.right : open.left, moreOrLessEquals(ltr ? rest.right : rest.left, epsilon: .5));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('without a placement the search stays on the window centre', (tester) async {
    await pump(tester);
    final rest = search(tester);
    expect(rest.center.dx, moreOrLessEquals(_size.width / 2, epsilon: 1));
    expect(rest.width, greaterThan(300));
    expect(tester.takeException(), isNull);
  });

  for (final placement in FrostCaptionSearchPlacement.values) {
    testWidgets('the blanks on both sides of the search drag the window ($placement)', (tester) async {
      final window = await pump(tester, placement: placement);
      final rest = search(tester), controls = buttons(tester);
      final y = rest.center.dy;
      final after = Offset((rest.right + controls.left) / 2, y), before = Offset(rest.left - 20, y);
      final regions = window.calls.last;
      bool has(FrostHitKind kind, Offset point) => regions.any((region) => region.kind == kind && region.rect.contains(point));
      expect(has(FrostHitKind.caption, after), isTrue, reason: 'right of the search');
      expect(has(FrostHitKind.caption, before), isTrue, reason: 'left of the search');
      expect(has(FrostHitKind.client, after), isFalse);
      expect(has(FrostHitKind.client, before), isFalse);
      expect(has(FrostHitKind.client, rest.center), isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
