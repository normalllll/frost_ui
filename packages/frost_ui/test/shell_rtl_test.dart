// The sidebar sits on the reading start: the left edge in left-to-right text
// and the right edge in right-to-left text, with the page inset from it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/navigation/window_caption.dart' show FrostCaptionButtons;
import 'support.dart';
import 'window_caption_test.dart' show FakeWindow;

const _pageKey = ValueKey('page');
const _iconKey = ValueKey('brand-icon');
const _titleKey = ValueKey('title-content');
const _width = 1440.0;
const _rail = 60.0;
const _expanded = 176.0;
final _back = find.byKey(const ValueKey('frost-shell-back'));

Widget _shell({required TextDirection direction, FakeWindow? window, bool expanded = false, EdgeInsets safe = EdgeInsets.zero, bool title = false}) =>
    frostTestApp(
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(padding: safe),
          child: FrostWindowCaptionScope(
            window: window,
            child: Directionality(
              textDirection: direction,
              child: FrostShell(
                destinations: const [FrostNavDestination(icon: FrostIconData.glyph(Icons.home), label: 'Home')],
                selectedIndex: 0,
                atDestinationRoot: true,
                canGoBack: true,
                onBack: () {},
                onDestinationSelected: (_) {},
                showsMobileNavigation: true,
                initiallyExpanded: expanded,
                titleBarContent: title ? const SizedBox(key: _titleKey, width: 120, height: 24) : null,
                brand: const FrostShellBrand(
                  expanded: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(key: _iconKey, width: 20, height: 20),
                      SizedBox(width: 8),
                      Flexible(child: FrostText('Brand', maxLines: 1)),
                    ],
                  ),
                ),
                child: const FrostShellDestination(child: SizedBox.expand(key: _pageKey)),
              ),
            ),
          ),
        ),
      ),
      platform: window == null ? TargetPlatform.android : TargetPlatform.windows,
    );

FakeWindow _window() => FakeWindow();

void main() {
  void size(WidgetTester tester) {
    tester.view.physicalSize = const Size(_width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  for (final expanded in [false, true]) {
    final sidebar = expanded ? _expanded : _rail;
    for (final withWindow in [false, true]) {
      final variant = 'expanded=$expanded window=$withWindow';
      testWidgets('left-to-right keeps the sidebar left and the page right of it $variant', (tester) async {
        size(tester);
        await tester.pumpWidget(_shell(direction: TextDirection.ltr, window: withWindow ? _window() : null, expanded: expanded));
        final page = tester.getRect(find.byKey(_pageKey));
        expect(page.left, sidebar);
        expect(page.right, _width);
        expect(tester.getCenter(_back).dx, _rail / 2);
        expect(tester.getRect(find.byType(FrostNavItem).first).right, lessThanOrEqualTo(sidebar));
      });

      testWidgets('right-to-left puts the sidebar and the page inset on the right $variant', (tester) async {
        size(tester);
        await tester.pumpWidget(_shell(direction: TextDirection.rtl, window: withWindow ? _window() : null, expanded: expanded));
        final page = tester.getRect(find.byKey(_pageKey));
        expect(page.left, 0);
        expect(page.right, _width - sidebar);
        final item = tester.getRect(find.byType(FrostNavItem).first);
        expect(item.left, greaterThanOrEqualTo(_width - sidebar));
        expect(item.right, lessThanOrEqualTo(_width));
        if (!withWindow) expect(tester.getCenter(_back).dx, _width - _rail / 2);
        final icon = tester.getCenter(find.descendant(of: find.byType(FrostNavItem).first, matching: find.byType(FrostIcon)).first);
        expect(icon.dx, closeTo(_width - _rail / 2, .01));
        if (expanded) {
          final brand = tester.getRect(find.byKey(_iconKey));
          expect(brand.center.dx, greaterThan(_width / 2));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('right-to-left caption row follows the sidebar while native buttons stay put', (tester) async {
    size(tester);
    await tester.pumpWidget(_shell(direction: TextDirection.rtl, window: _window(), title: true));
    final buttons = tester.getRect(find.byType(FrostCaptionButtons));
    expect(buttons.right, _width);
    final back = tester.getRect(_back);
    final brand = tester.getRect(find.byKey(_iconKey));
    final title = tester.getRect(find.byKey(_titleKey));
    expect(back.right, lessThanOrEqualTo(buttons.left));
    expect(back.center.dx, greaterThan(_width / 2));
    expect(brand.right, lessThanOrEqualTo(back.left));
    expect(title.center.dx, lessThan(brand.center.dx));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the sidebar keeps the safe inset of the side it is on', (tester) async {
    size(tester);
    const safe = EdgeInsets.only(left: 10, right: 30);
    await tester.pumpWidget(_shell(direction: TextDirection.rtl, safe: safe));
    var page = tester.getRect(find.byKey(_pageKey));
    expect(page.right, _width - 30 - _rail);
    expect(page.left, 0);
    expect(tester.getCenter(_back).dx, _width - 30 - _rail / 2);
    await tester.pumpWidget(_shell(direction: TextDirection.ltr, safe: safe));
    page = tester.getRect(find.byKey(_pageKey));
    expect(page.left, 10 + _rail);
    expect(page.right, _width);
    expect(tester.getCenter(_back).dx, 10 + _rail / 2);
  });
}
