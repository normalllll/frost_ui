import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/layout/window_caption_scope.dart' show FrostHitKind;
import 'package:frost_ui/src/navigation/window_caption.dart' show FrostCaptionButtons;
import 'package:material_ui/material_ui.dart';

import 'support.dart';
import 'window_caption_test.dart' show FakeWindow;

const _reader = ValueKey('reader');
const _list = ValueKey('list');

Widget _app(WidgetTester tester, GlobalKey<NavigatorState> navigator, FakeWindow window, {FrostNavigationPlacement placement = FrostNavigationPlacement.automatic}) {
  final controller = TextEditingController(), focus = FocusNode();
  addTearDown(controller.dispose);
  addTearDown(focus.dispose);
  return frostTestApp(
    FrostWindowCaptionScope(
      window: window,
      child: FrostShell(
        navigationPlacement: placement,
        brand: const FrostShellBrand(expanded: FrostText('Brandname')),
        destinations: const [
          FrostNavDestination(icon: FrostIconData.glyph(Icons.home), label: 'Home'),
          FrostNavDestination(icon: FrostIconData.glyph(Icons.search), label: 'Find'),
        ],
        selectedIndex: 0,
        atDestinationRoot: true,
        onDestinationSelected: (_) {},
        canGoBack: true,
        onBack: () {},
        showsMobileNavigation: true,
        titleBarSearch: FrostCaptionSearch(controller: controller, focusNode: focus, placeholder: 'Search', onSubmitted: (_) {}),
        child: FrostShellDestination(
          child: Navigator(
            key: navigator,
            onGenerateRoute: (_) => PageRouteBuilder<void>(pageBuilder: (_, _, _) => const ColoredBox(key: _list, color: Colors.white)),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openReader(WidgetTester tester, GlobalKey<NavigatorState> navigator, {required VoidCallback onRowTap}) async {
  navigator.currentState!.push(
    PageRouteBuilder<void>(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, _, _) => FrostShellWholeWindow(
        titleRow: FrostButton(label: 'Reader menu', onPressed: onRowTap),
        child: const ColoredBox(key: _reader, color: Colors.black),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _window(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Finder get _sidebarItems => find.byType(FrostNavItem);

void main() {
  testWidgets('beside a sidebar a page can take the whole window and give it back', (tester) async {
    _window(tester, const Size(1147, 717));
    final navigator = GlobalKey<NavigatorState>();
    final window = FakeWindow();
    addTearDown(window.dispose);
    await tester.pumpWidget(_app(tester, navigator, window));
    await tester.pumpAndSettle();
    expect(_sidebarItems, findsWidgets);
    final listBefore = tester.getRect(find.byKey(_list));
    final homeBefore = tester.getRect(_sidebarItems.first);

    var taps = 0;
    await _openReader(tester, navigator, onRowTap: () => taps++);
    expect(_sidebarItems, findsNothing);
    expect(find.text('Brandname'), findsNothing);
    expect(find.byType(FrostCaptionSearch), findsNothing);
    expect(find.byType(FrostCaptionButtons), findsWidgets);
    expect(tester.getRect(find.byKey(_reader)), const Rect.fromLTWH(0, 0, 1147, 717));

    final row = tester.getRect(find.text('Reader menu'));
    await tester.tap(find.text('Reader menu'));
    expect(taps, 1);
    final regions = window.calls.last;
    expect(regions.any((region) => region.kind == FrostHitKind.client && region.rect.contains(row.center)), isTrue);
    final buttons = tester.getRect(find.byType(FrostCaptionButtons).first);
    expect(
      regions.any((region) => region.kind == FrostHitKind.caption && region.rect.contains(Offset(buttons.left - 30, row.center.dy))),
      isTrue,
      reason: 'the rest of the row drags the window',
    );

    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(_sidebarItems, findsWidgets);
    expect(tester.getRect(_sidebarItems.first), homeBefore);
    expect(tester.getRect(find.byKey(_list)), listBefore);
    expect(find.byType(FrostCaptionSearch), findsOneWidget);
    expect(find.text('Brandname'), findsOneWidget);
  });

  testWidgets('under bottom navigation the page keeps the content area', (tester) async {
    _window(tester, const Size(1147, 717));
    final navigator = GlobalKey<NavigatorState>();
    final window = FakeWindow();
    addTearDown(window.dispose);
    await tester.pumpWidget(_app(tester, navigator, window, placement: FrostNavigationPlacement.bottom));
    await tester.pumpAndSettle();
    final list = tester.getRect(find.byKey(_list));
    await _openReader(tester, navigator, onRowTap: () {});
    final row = tester.getRect(find.ancestor(of: find.text('Reader menu'), matching: find.byType(FrostButton)));
    expect(row.top, list.top, reason: 'the row sits at the top of the page');
    expect(tester.getRect(find.byKey(_reader)).top, row.bottom);

  });
}
