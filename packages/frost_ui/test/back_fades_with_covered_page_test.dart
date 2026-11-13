import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

void main() {
  testWidgets('a page a route moves over keeps an inert Back until it is covered', (tester) async {
    tester.view.physicalSize = const Size(411, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      frostTestApp(
        FrostShell(
          navigationPlacement: FrostNavigationPlacement.bottom,
          destinations: const [
            FrostNavDestination(icon: FrostIconData.glyph(Icons.home), label: 'Home'),
            FrostNavDestination(icon: FrostIconData.glyph(Icons.search), label: 'Find'),
          ],
          selectedIndex: 0,
          atDestinationRoot: false,
          onDestinationSelected: (_) {},
          canGoBack: true,
          onBack: () => navigator.currentState!.maybePop(),
          showsMobileNavigation: true,
          child: Navigator(
            key: navigator,
            onGenerateInitialRoutes: (navigator, _) => [
              MaterialPageRoute<void>(builder: (_) => const FrostPageHeader(title: Text('Root'))),
              const FrostDetailPage<void>(child: FrostPageHeader(title: Text('First'))).createRoute(navigator.context),
            ],
          ),
        ),
        platform: TargetPlatform.android,
      ),
    );
    await tester.pumpAndSettle();
    Finder backOf(String title) => find.descendant(
      of: find.ancestor(of: find.text(title), matching: find.byType(FrostPageHeader)),
      matching: find.byType(FrostCompactBackButton),
    );
    expect(backOf('First'), findsOneWidget);

    navigator.currentState!.push(const FrostDetailPage<void>(child: FrostPageHeader(title: Text('Second'))).createRoute(navigator.currentContext!));
    for (final frame in [0, 16, 100]) {
      await tester.pump(Duration(milliseconds: frame));
      expect(backOf('First'), findsOneWidget, reason: 'Back fades with its page at ${frame}ms');
      final inert = find.ancestor(of: backOf('First'), matching: find.byType(IgnorePointer));
      expect(tester.widgetList<IgnorePointer>(inert).any((widget) => widget.ignoring), isTrue, reason: 'the covered Back takes no taps');
      expect(backOf('Second'), findsOneWidget);
    }
    await tester.pumpAndSettle();
    expect(backOf('Second'), findsOneWidget);

    navigator.currentState!.pop();
    await tester.pump();
    expect(backOf('First'), findsOneWidget);
    final inert = find.ancestor(of: backOf('First'), matching: find.byType(IgnorePointer));
    expect(tester.widgetList<IgnorePointer>(inert).any((widget) => widget.ignoring), isFalse, reason: 'the uncovered page owns Back again');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
