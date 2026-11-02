import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/layout/_column_split.dart';
import 'support.dart';

void main() {
  void viewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  test('the navigation column is 22% of the width, held between 236 and 320', () {
    expect(frostColumnNavigationWidthFor(700), 236);
    expect(frostColumnNavigationWidthFor(1000), 236);
    expect(frostColumnNavigationWidthFor(1200), 264);
    expect(frostColumnNavigationWidthFor(1400), 308);
    expect(frostColumnNavigationWidthFor(1455), 320);
    expect(frostColumnNavigationWidthFor(1440), 317, reason: 'rounded to a whole point');
    expect(frostColumnNavigationWidthFor(1920), 320);
  });

  test('the content limit is 640 up to 1200 and grows evenly to 800 at 1600', () {
    expect(frostColumnContentMaxWidthFor(800), 640);
    expect(frostColumnContentMaxWidthFor(1200), 640);
    expect(frostColumnContentMaxWidthFor(1400), 720);
    expect(frostColumnContentMaxWidthFor(1600), 800);
    expect(frostColumnContentMaxWidthFor(2400), 800);
  });

  for (final direction in TextDirection.values) {
    for (final width in [1000.0, 1200.0, 1400.0, FrostMetrics.settingsMaxWidth]) {
      testWidgets('both layouts put the divider and the content start at the same x ($width, $direction)', (tester) async {
        viewport(tester, Size(width, 820));
        Widget app(Widget child) => frostTestApp(Directionality(textDirection: direction, child: child));
        await tester.pumpWidget(
          app(
            FrostSettingsSections(
              labels: const ['Appearance'],
              selectedIndex: 0,
              onSelected: (_) {},
              sectionBuilder: (_, _) => const FrostContentColumn(child: SizedBox.expand(key: ValueKey('content'))),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final settingsDivider = tester.getRect(find.byType(FrostDivider));
        final settingsContent = tester.getRect(find.byKey(const ValueKey('content')));

        await tester.pumpWidget(
          app(
            FrostNavigationColumnLayout(
              navigationBuilder: (_) => const SizedBox(),
              content: const FrostContentColumn(child: SizedBox.expand(key: ValueKey('content'))),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final divider = tester.getRect(find.byType(FrostDivider));
        final content = tester.getRect(find.byKey(const ValueKey('content')));
        expect(divider, settingsDivider);
        expect(content, settingsContent);

        final navigation = frostColumnNavigationWidthFor(width);
        expect(direction == TextDirection.ltr ? divider.left : width - divider.right, moreOrLessEquals(navigation));
        expect(content.width, lessThanOrEqualTo(frostColumnContentMaxWidthFor(width)));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('the wide threshold stays on the 236-point column', (tester) async {
    for (final (width, wide) in [(600.0, false), (640.0, true)]) {
      viewport(tester, Size(width, 800));
      late bool isWide;
      await tester.pumpWidget(
        frostTestApp(
          FrostNavigationColumnLayout(
            navigationBuilder: (context) {
              isWide = FrostNavigationColumnLayout.isWideOf(context);
              return const SizedBox();
            },
            content: const SizedBox(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(isWide, wide, reason: '$width');
    }
  });
}
