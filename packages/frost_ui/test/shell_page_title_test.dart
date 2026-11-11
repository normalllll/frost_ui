import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/navigation/window_caption.dart' show FrostCaptionButtons;

import 'support.dart';
import 'window_caption_test.dart' show FakeWindow;

const _brandKey = ValueKey('brand');
final _navigator = GlobalKey<NavigatorState>();

Widget _page(String title) => Scaffold(
  body: Column(
    children: [
      FrostPageHeader(title: FrostText(title)),
      const Expanded(child: SizedBox.expand()),
    ],
  ),
);

Widget _shell({TextDirection direction = TextDirection.ltr, bool canGoBack = false}) => frostTestApp(
  FrostWindowCaptionScope(
    window: FakeWindow(),
    child: Directionality(
      textDirection: direction,
      child: FrostShell(
        destinations: const [FrostNavDestination(icon: FrostIconData.glyph(Icons.home), label: 'Home')],
        selectedIndex: 0,
        atDestinationRoot: !canGoBack,
        canGoBack: canGoBack,
        onBack: () => _navigator.currentState?.pop(),
        onDestinationSelected: (_) {},
        showsMobileNavigation: true,
        brand: const FrostShellBrand(expanded: FrostText('BooruFlow', key: _brandKey)),
        child: FrostShellDestination(
          child: Navigator(
            key: _navigator,
            onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => _page('Browse')),
          ),
        ),
      ),
    ),
  ),
);

/// The title texts that paint: the row's, and a header's when it draws one.
Iterable<Rect> _painted(WidgetTester tester, String title) => find
    .text(title)
    .evaluate()
    .where((element) => element.findAncestorWidgetOfExactType<Opacity>()?.opacity != 0)
    .map((element) => tester.getRect(find.byWidget(element.widget)));

void main() {
  for (final direction in TextDirection.values) {
    testWidgets('the Windows title row shows the page title after the brand, once, in ${direction.name}', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_shell(direction: direction));
      await tester.pumpAndSettle();
      final titles = _painted(tester, 'Browse').toList();
      expect(titles, hasLength(1), reason: 'the header leaves its title to the row');
      final title = titles.single, brand = tester.getRect(find.byKey(_brandKey));
      final buttons = tester.getRect(find.byType(FrostCaptionButtons));
      expect(title.center.dy, closeTo(brand.center.dy, 1), reason: 'in the title row');
      expect(title.bottom, lessThanOrEqualTo(buttons.bottom));
      if (direction == TextDirection.ltr) {
        expect(title.left, greaterThan(brand.right));
      } else {
        expect(title.right, lessThan(brand.left));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a pushed page names the title row, and the page below names it again after Back', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_shell());
    await tester.pumpAndSettle();
    _navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => _page('Post 42')));
    await tester.pumpAndSettle();
    expect(_painted(tester, 'Post 42'), hasLength(1));
    expect(_painted(tester, 'Browse'), isEmpty);
    _navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(_painted(tester, 'Browse'), hasLength(1));
    expect(_painted(tester, 'Post 42'), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the header keeps the title for screen readers', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_shell());
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Browse'), findsOneWidget);
    semantics.dispose();
  });
}
