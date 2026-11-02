import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'support.dart';

const _home = FrostNavDestination(icon: FrostIconData.glyph(IconData(0xe001)), label: 'Home');
const _search = FrostNavDestination(icon: FrostIconData.glyph(IconData(0xe002)), label: 'Search');
const _settings = FrostNavDestination(icon: FrostIconData.glyph(IconData(0xe003)), label: 'Settings');

void main() {
  testWidgets('components read the configuration from the Frost theme without a scope', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FrostTheme.build(config: testConfig, brightness: Brightness.light, platform: TargetPlatform.windows, locale: const Locale('en')),
        home: Scaffold(
          body: FrostCompactMessage.error(error: 'x', onAction: () {}),
        ),
      ),
    );
    expect(find.text('E.message(x)'), findsOneWidget);
    expect(find.text('L.retry'), findsOneWidget);
  });

  Finder navItem(String label) => find.byWidgetPredicate((widget) => widget is FrostNavItem && widget.label == label);

  Future<void> desktop(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('FrostShell: navigation, reselection and More', (tester) async {
    await desktop(tester, const Size(1400, 900));
    final selected = <int>[];
    final secondary = <int>[];
    var reselections = 0;
    await tester.pumpWidget(
      frostTestApp(
        FrostShell(
          destinations: const [_home, _search],
          selectedIndex: 0,
          atDestinationRoot: true,
          onDestinationSelected: selected.add,
          secondary: FrostShellSecondary(destinations: const [_settings], onSelected: secondary.add),
          canGoBack: false,
          onBack: () {},
          showsMobileNavigation: true,
          child: Builder(
            builder: (context) {
              FrostShellNavigationScope.maybeOf(context)!.primaryReselection.addListener(() => reselections++);
              return const Center(child: Text('page'));
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('page'), findsOneWidget);
    expect(navItem('L.more'), findsOneWidget);

    await tester.tap(navItem('Search'));
    expect(selected, [1]);

    // The current root destination again signals reselection instead.
    await tester.tap(navItem('Home'));
    expect(selected, [1]);
    expect(reselections, 1);

    await tester.tap(navItem('L.more'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(secondary, [0]);

    // The sidebar expands on wide windows.
    await tester.tap(findFrostTooltip('L.expandNavigation'));
    await tester.pumpAndSettle();
    expect(findFrostTooltip('L.collapseNavigation'), findsOneWidget);
  });

  Widget sidebarShell({required ValueChanged<bool> onExpandedChanged, bool initiallyExpanded = false, Widget? child}) => frostTestApp(
    FrostShell(
      destinations: const [_home, _search],
      selectedIndex: 0,
      atDestinationRoot: true,
      onDestinationSelected: (_) {},
      canGoBack: false,
      onBack: () {},
      showsMobileNavigation: true,
      initiallyExpanded: initiallyExpanded,
      onExpandedChanged: onExpandedChanged,
      child: child ?? const SizedBox.expand(key: ValueKey('page')),
    ),
  );

  testWidgets('Escape on a page does not go back through the page and shell Scaffolds', (tester) async {
    await desktop(tester, const Size(1400, 800));
    var backs = 0;
    await tester.pumpWidget(
      frostTestApp(
        FrostShell(
          destinations: const [_home, _search],
          selectedIndex: 0,
          atDestinationRoot: false,
          onDestinationSelected: (_) {},
          canGoBack: true,
          onBack: () => backs++,
          showsMobileNavigation: false,
          child: const Scaffold(body: Focus(autofocus: true, child: SizedBox.expand())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(backs, 0);
  });

  testWidgets('pinned glass beside the sidebar covers the content sheet', (tester) async {
    await desktop(tester, const Size(1400, 800));
    await tester.pumpWidget(
      sidebarShell(
        onExpandedChanged: (_) {},
        child: FrostPinnedChrome(
          extent: 48,
          chrome: const SizedBox.expand(),
          body: ListView(
            children: [
              const SizedBox(height: 48),
              for (var index = 0; index < 50; index++) SizedBox(height: 40, child: Text('$index')),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.text('3'), const Offset(0, -200));
    await tester.pumpAndSettle();
    final band = find.descendant(of: find.byType(FrostPinnedChromeGlass), matching: find.byType(FrostSurface));
    expect(tester.getSize(band).width, 1400 - 60 - 8);
    // Centred in the page beside the 60 rail.
    expect(tester.getCenter(band).dx, 60 + (1400 - 60 - 8) / 2);
  });

  testWidgets('FrostShell uses the bottom bar on phones', (tester) async {
    await desktop(tester, const Size(400, 800));
    await tester.pumpWidget(
      frostTestApp(
        FrostShell(
          navigationPlacement: FrostNavigationPlacement.bottom,
          destinations: const [_home, _search],
          selectedIndex: 1,
          atDestinationRoot: true,
          onDestinationSelected: (_) {},
          canGoBack: true,
          onBack: () {},
          showsMobileNavigation: true,
          child: const FrostShellDestination(child: SizedBox.expand()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('L.more'), findsNothing);
  });

  testWidgets('errors use the app presenter and labels', (tester) async {
    await desktop(tester, const Size(1000, 800));
    await tester.pumpWidget(
      frostTestApp(
        Scaffold(
          body: Column(
            children: [
              FrostCompactMessage.error(error: 'boom', onAction: () {}),
              Expanded(
                child: FrostErrorContent.fromError(error: 'down', onRetry: () {}),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('E.message(boom)'), findsOneWidget);
    expect(find.text('E.message(down)'), findsOneWidget);
    expect(find.text('L.retry'), findsNWidgets(2));
    expect(find.text('L.errorDetails'), findsNWidgets(2));
  });

  testWidgets('toasts: action runs once, identical notices merge on desktop', (tester) async {
    await desktop(tester, const Size(1200, 800));
    await tester.pumpWidget(frostTestApp(const Scaffold(body: SizedBox.expand())));
    var undone = 0;
    FrostToast.actionableInfo('Removed', actionLabel: 'Undo', onAction: () => undone++);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(undone, 1);
    expect(find.text('Removed'), findsNothing);

    FrostToast.info('Saved');
    FrostToast.info('Saved');
    await tester.pumpAndSettle();
    expect(find.text('Saved  ×2'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('settings sections and controls render', (tester) async {
    await desktop(tester, const Size(1400, 900));
    var section = 0;
    await tester.pumpWidget(
      frostTestApp(
        Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  FrostButton(label: 'Act', onPressed: () {}),
                  FrostSwitch(value: true, onChanged: (_) {}, semanticLabel: null),
                  FrostPicker<int>.menu(
                    value: 1,
                    options: const [
                      FrostPickerOption(value: 1, label: 'One'),
                      FrostPickerOption(value: 2, label: 'Two'),
                    ],
                    onChanged: (_) {},
                    label: 'Choice',
                  ),
                  Expanded(
                    child: FrostSettingsSections(
                      labels: const ['General', 'About'],
                      status: const Text('status row'),
                      selectedIndex: section,
                      onSelected: (index) => setState(() => section = index),
                      sectionBuilder: (_, index) => Text(const ['general group', 'about group'][index]),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('status row'), findsOneWidget);
    expect(find.text('general group'), findsOneWidget);
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();
    expect(find.text('about group'), findsOneWidget);
  });
}
