import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

class _PlainPage extends Page<void> {
  const _PlainPage({required this.child});
  final Widget child;
  @override
  Route<void> createRoute(BuildContext context) =>
      PageRouteBuilder<void>(settings: this, transitionDuration: Duration.zero, reverseTransitionDuration: Duration.zero, pageBuilder: (_, _, _) => child);
}

void main() {
  testWidgets('the bottom bar of a destination root blurs only while no page above it is there or moving', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var detail = false;
    late StateSetter update;
    final navigator = GlobalKey<NavigatorState>();
    const page = ValueKey('detail page');
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (context, set) {
            update = set;
            return FrostShell(
              destinations: [
                FrostNavDestination(icon: testIcons.image, label: 'Home'),
                FrostNavDestination(icon: testIcons.search, label: 'Search'),
              ],
              selectedIndex: 0,
              atDestinationRoot: !detail,
              onDestinationSelected: (_) {},
              canGoBack: detail,
              onBack: () => navigator.currentState!.pop(),
              showsMobileNavigation: true,
              child: Navigator(
                key: navigator,
                onDidRemovePage: (_) => update(() => detail = false),
                pages: [
                  // A root page with no transition of its own.
                  const _PlainPage(child: FrostShellDestination(child: SizedBox.expand())),
                  if (detail)
                    const FrostDetailPage<void>.media(
                      key: ValueKey('detail'),
                      child: ColoredBox(key: page, color: Colors.red),
                    ),
                ],
              ),
            );
          },
        ),
        platform: TargetPlatform.android,
      ),
    );
    await tester.pumpAndSettle();

    // The bar is the root page's only glass.
    bool blurs() => tester.widgetList<BackdropFilter>(find.byType(BackdropFilter, skipOffstage: false)).any((filter) => filter.enabled);
    expect(blurs(), isTrue, reason: 'at rest the bar samples what is beneath it');

    update(() => detail = true);
    await tester.pump();
    for (var frame = 0; frame < 40; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(blurs(), isFalse, reason: 'frame $frame of the page above entering');
    }
    await tester.pumpAndSettle();
    expect(blurs(), isFalse, reason: 'covered');

    navigator.currentState!.pop();
    await tester.pump();
    while (find.byKey(page).evaluate().isNotEmpty) {
      expect(blurs(), isFalse, reason: 'the page above is still leaving');
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    expect(blurs(), isTrue, reason: 'the blur comes back once the page above has gone');
    expect(tester.takeException(), isNull);
  });
}
