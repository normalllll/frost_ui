import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

const _home = FrostNavDestination(icon: FrostIconData.glyph(IconData(0xe001)), label: 'Home');
const _search = FrostNavDestination(icon: FrostIconData.glyph(IconData(0xe002)), label: 'Search');

void main() {
  Future<void> open(WidgetTester tester, {required bool shell, double safeBottom = 0}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(411, 960);
    tester.view.padding = FakeViewPadding(bottom: safeBottom);
    addTearDown(tester.view.reset);
    Widget page() => Builder(
      builder: (context) => Center(
        child: FrostButton(
          label: 'Open',
          onPressed: () => showFrostSheet<void>(
            context: context,
            title: 'Ratings',
            detents: const [FrostSheetDetent.fitted],
            builder: (_) => const SizedBox(key: ValueKey('content'), height: 200),
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      frostTestApp(
        shell
            ? FrostShell(
                navigationPlacement: FrostNavigationPlacement.bottom,
                destinations: const [_home, _search],
                selectedIndex: 0,
                atDestinationRoot: true,
                onDestinationSelected: (_) {},
                canGoBack: false,
                onBack: () {},
                showsMobileNavigation: true,
                child: FrostShellDestination(child: page()),
              )
            : page(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  double gap(WidgetTester tester) => 960 - tester.getBottomLeft(find.byKey(const ValueKey('content'))).dy;

  for (final safe in [0.0, 34.0]) {
    testWidgets('a fitted sheet opened over the bottom bar has the same gap as without a shell (safe area $safe)', (tester) async {
      await open(tester, shell: false, safeBottom: safe);
      final bare = gap(tester);
      await tester.pumpWidget(const SizedBox());
      await open(tester, shell: true, safeBottom: safe);
      expect(gap(tester), bare);
      expect(tester.takeException(), isNull);
    });
  }

  Future<void> openHeader(WidgetTester tester, String title, {double scale = 1}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(411, 960);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      frostTestApp(
        MediaQuery.withClampedTextScaling(
          minScaleFactor: scale,
          maxScaleFactor: scale,
          child: Builder(
            builder: (context) => Center(
              child: FrostButton(
                label: 'Open',
                onPressed: () =>
                    showFrostSheet<void>(context: context, title: title, detents: const [FrostSheetDetent.fitted], builder: (_) => const SizedBox(height: 80)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Finder close() => find.byWidgetPredicate((widget) => widget is FrostButton && widget.label == 'L.close');

  testWidgets('a one-line title and the close button share a centre line', (tester) async {
    await openHeader(tester, 'Ratings');
    expect(tester.getCenter(find.text('Ratings')).dy, moreOrLessEquals(tester.getCenter(close().last).dy, epsilon: .5));
    expect(tester.takeException(), isNull);
  }, variant: const TargetPlatformVariant({TargetPlatform.android, TargetPlatform.windows}));

  testWidgets('a large text scale pushes the button down rather than the title', (tester) async {
    await openHeader(tester, 'Hi', scale: 3);
    expect(tester.getCenter(find.text('Hi')).dy, moreOrLessEquals(tester.getCenter(close().last).dy, epsilon: .5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a wrapped title keeps the close button beside its first line', (tester) async {
    await openHeader(tester, List.filled(30, 'Long').join(' '));
    final title = tester.getRect(find.textContaining('Long Long')), button = tester.getRect(close().last);
    expect(title.height, greaterThan(button.height));
    expect(button.top, lessThanOrEqualTo(title.top));
    expect(button.center.dy, lessThan(title.center.dy));
    expect(tester.takeException(), isNull);
  });
}
