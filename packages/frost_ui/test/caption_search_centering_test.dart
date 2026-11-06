import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_field_frame.dart';
import 'package:frost_ui/src/layout/_caption_search_scope.dart';
import 'package:frost_ui/src/navigation/window_caption.dart' show FrostCaptionButtons;
import 'package:frost_ui/src/overlays/_popover_surface.dart';

import 'support.dart';
import 'window_caption_test.dart' show FakeWindow;

const _base = FrostCaptionState(maximized: false, active: true, maximizeHovered: false, maximizePressed: false, failed: false);

FrostCaptionState _mac(Rect lights) => FrostCaptionState(
  maximized: false,
  active: true,
  maximizeHovered: false,
  maximizePressed: false,
  failed: false,
  mode: FrostCaptionMode.nativeControls,
  leftButtons: const [],
  rightButtons: const [],
  nativeControls: lights,
);

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

  Future<void> pump(WidgetTester tester, FrostCaptionState state, TargetPlatform platform, {TextDirection direction = TextDirection.ltr}) async {
    tester.view.physicalSize = const Size(1200, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    final window = FakeWindow()..current = state;
    await tester.pumpWidget(
      frostTestApp(
        FrostWindowCaptionScope(
          window: window,
          child: Directionality(
            textDirection: direction,
            child: FrostShell(
              destinations: const [FrostNavDestination(icon: FrostIconData.glyph(Icons.home), label: 'Home')],
              selectedIndex: 0,
              atDestinationRoot: false,
              onDestinationSelected: (_) {},
              canGoBack: true,
              onBack: () {},
              showsMobileNavigation: true,
              brand: const FrostShellBrand(expanded: Text('Application')),
              titleBarSearch: FrostCaptionSearch(
                controller: editing,
                focusNode: focus,
                placeholder: 'Search',
                onSubmitted: (_) {},
                content: searchContent([
                  FrostSearchSection(
                    children: [FrostSearchSuggestionRow(label: 'cat', onSelected: () {})],
                  ),
                ]),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        platform: platform,
      ),
    );
    await tester.pumpAndSettle();
  }

  // The visible field frame, not its taller target.
  Rect frame(WidgetTester tester) => tester.getRect(find.descendant(of: find.byType(FrostTextField), matching: find.byType(FrostFieldPaint)).first);

  Future<void> expectExpandedOnSameLine(WidgetTester tester, double centre) async {
    focus.requestFocus();
    await tester.pumpAndSettle();
    final expanded = frame(tester);
    expect(expanded.width, frostCaptionSearchExpandedWidth);
    expect(expanded.center.dy, closeTo(centre, .01), reason: 'expanding keeps the centre line');
    final panel = tester.getRect(find.byType(FrostPopoverSurface));
    // The dropdown stays directly below the field's target, as before.
    expect(panel.top, greaterThanOrEqualTo(expanded.bottom));
    expect(panel.top - expanded.bottom, lessThanOrEqualTo(4));
    expect(panel.left, expanded.left);
  }

  testWidgets('caption search stays on the window centre in both text directions', (tester) async {
    for (final direction in TextDirection.values) {
      await pump(tester, _base, TargetPlatform.windows, direction: direction);
      expect(frame(tester).center.dx, closeTo(600, 1), reason: direction.name);
      await tester.pumpWidget(const SizedBox());
    }
  });

  for (final (platform, state) in [
    (TargetPlatform.windows, _base),
    (
      TargetPlatform.linux,
      const FrostCaptionState(
        maximized: false,
        active: true,
        maximizeHovered: false,
        maximizePressed: false,
        failed: false,
        style: FrostCaptionStyle.adwaita,
        rightButtons: [FrostCaptionAction.minimize, FrostCaptionAction.maximize, FrostCaptionAction.close],
      ),
    ),
  ]) {
    testWidgets('caption search shares the caption buttons and Back centre line on ${platform.name}', (tester) async {
      await pump(tester, state, platform);
      final field = frame(tester);
      final buttons = tester.getRect(find.byType(FrostCaptionButtons));
      final back = tester.getRect(find.byKey(const ValueKey('frost-shell-back')));
      final brand = tester.getRect(find.text('Application').first);
      expect(field.height, 30);
      expect(field.center.dy, closeTo(buttons.center.dy, .01));
      expect(field.center.dy, closeTo(back.center.dy, .01));
      expect(field.center.dy, closeTo(brand.center.dy, .01));
      expect(field.top, closeTo(40 - field.bottom, .01), reason: 'equal room above and below in the 40 row');
      await expectExpandedOnSameLine(tester, buttons.center.dy);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('macOS centres the caption search on the traffic lights, keeping room above', (tester) async {
    const lights = Rect.fromLTRB(9, 9, 69, 23);
    await pump(tester, _mac(lights), TargetPlatform.macOS);
    final field = frame(tester);
    // Centred on 16 would leave one pixel above a 30 frame; two are kept.
    expect(field.top, 2);
    expect(field.center.dy, 17);
    await expectExpandedOnSameLine(tester, 17);
    expect(tester.takeException(), isNull);
  });

  testWidgets('macOS traffic lights lower in the row put the field on their centre line', (tester) async {
    const lights = Rect.fromLTRB(12, 13, 72, 27);
    await pump(tester, _mac(lights), TargetPlatform.macOS);
    expect(frame(tester).center.dy, lights.center.dy);
    expect(frame(tester).bottom, lessThanOrEqualTo(38));
    expect(tester.takeException(), isNull);
  });
}
