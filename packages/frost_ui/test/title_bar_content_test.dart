import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/layout/window_caption_scope.dart' show FrostHitKind;
import 'package:frost_ui/src/navigation/window_caption.dart' show FrostCaptionButtons;
import 'package:material_ui/material_ui.dart';

import 'app_router_test.dart' show TestRouter;
import 'support.dart';
import 'window_caption_test.dart' show FakeWindow;

void main() {
  testWidgets('interactive title content hides intact for narrow/large text, hides for actual fullscreen and restores hits', (tester) async {
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
              titleBarContent: FrostSearchInput(controller: editing, focusNode: focus, placeholder: 'Search', onSubmitted: (_) {}),
              child: const SizedBox.expand(key: ValueKey('content')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(tree());
    await tester.pumpAndSettle();
    final finder = find.byType(FrostSearchInput);
    final element = tester.element(finder);
    final captionRect = tester.getRect(finder);
    expect(captionRect.top, lessThan(40));
    expect(captionRect.right, lessThan(tester.getRect(find.byType(FrostCaptionButtons)).left));
    expect(window.calls.last.any((region) => region.kind == FrostHitKind.client && region.rect.contains(captionRect.center)), true);
    await tester.enterText(find.byType(TextField), 'retained query');

    expect(focus.hasPrimaryFocus, true);
    final hidden = find.byType(FrostSearchInput, skipOffstage: false);
    tester.view.physicalSize = const Size(520, 700);
    await tester.pumpAndSettle();
    expect(finder, findsNothing);
    expect(tester.element(hidden), same(element));
    expect(editing.text, 'retained query');
    expect(focus.hasPrimaryFocus, true);

    tester.view.physicalSize = const Size(1200, 700);
    scale = 2;
    await tester.pumpWidget(tree());
    await tester.pumpAndSettle();
    expect(finder, findsNothing);
    expect(tester.element(hidden), same(element));

    window.current = const FrostCaptionState(maximized: false, fullscreen: true, active: true, maximizeHovered: false, maximizePressed: false, failed: false);
    window.notifyListeners();
    await tester.pumpAndSettle();
    expect(finder, findsNothing);
    expect(tester.element(find.byType(FrostSearchInput, skipOffstage: false)), same(element));
    expect(window.calls.last, isEmpty);
    expect(find.byType(FrostCaptionButtons), findsNothing);

    scale = 1;
    window.change();
    await tester.pumpWidget(tree());
    await tester.pumpAndSettle();
    expect(tester.element(finder), same(element));
    expect(tester.getRect(finder).top, lessThan(40));
    expect(window.calls.last.any((region) => region.kind == FrostHitKind.caption), true);
    expect(editing.text, 'retained query');
    expect(focus.hasPrimaryFocus, true);

    await tester.pumpWidget(const SizedBox());
    editing.dispose();
    focus.dispose();
    window.dispose();
  });
  testWidgets('FrostApp nested route keeps title focus through repeated resize', (tester) async {
    tester.view.physicalSize = const Size(1600, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final window = FakeWindow();
    final editing = TextEditingController();
    final focus = FocusNode();
    final navigator = GlobalKey<NavigatorState>();
    final delegate = TestRouter(
      FrostShell(
        destinations: const [FrostNavDestination(icon: FrostIconData.glyph(Icons.home), label: 'Home')],
        selectedIndex: 0,
        atDestinationRoot: true,
        onDestinationSelected: (_) {},
        canGoBack: false,
        onBack: () {},
        showsMobileNavigation: true,
        titleBarContent: FrostSearchInput(controller: editing, focusNode: focus, placeholder: 'Search', onSubmitted: (_) {}),
        child: Navigator(
          key: navigator,
          onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const SizedBox.expand()),
        ),
      ),
    );
    await tester.pumpWidget(
      FrostApp.router(
        config: testConfig,
        title: 'Test',
        routerConfig: RouterConfig<Object>(routerDelegate: delegate),
        builder: (context, child) => FrostWindowCaptionScope(window: window, child: child!),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'retained query');
    final element = tester.element(find.byType(EditableText));
    for (final size in [const Size(390, 780), const Size(1600, 720), const Size(390, 780), const Size(1600, 720)]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(EditableText, skipOffstage: false)), same(element));
      expect(focus.hasPrimaryFocus, true);
    }
    await tester.pumpWidget(const SizedBox());
    delegate.dispose();
    editing.dispose();
    focus.dispose();
    window.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
