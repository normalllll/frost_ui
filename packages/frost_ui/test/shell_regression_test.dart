import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'support.dart';

void main() {
  group('page header titles', () {
    Future<void> pump(WidgetTester tester, Widget title, {TargetPlatform platform = TargetPlatform.android}) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        frostTestApp(
          Column(children: [FrostPageHeader(title: title)]),
          platform: platform,
        ),
      );
    }

    for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
      testWidgets('a composed two-line title keeps its roles and fits the fixed header $platform', (tester) async {
        await pump(
          tester,
          const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FrostText('Title', role: FrostTextRole.headline),
              FrostText('Source', role: FrostTextRole.footnote, tone: FrostTextTone.tertiary),
            ],
          ),
          platform: platform,
        );
        expect(tester.takeException(), isNull, reason: 'no RenderFlex overflow in the fixed header');
        final headline = tester.renderObject<RenderParagraph>(find.text('Title')).text.style!;
        expect(headline.fontSize, 16, reason: 'the headline role the app asked for is not replaced by the page-title role');
        expect(tester.getSize(find.byType(FrostPageHeader)).height, lessThanOrEqualTo(52));
      });
    }

    testWidgets('a bare FrostText title still takes the page-title role', (tester) async {
      await pump(tester, const FrostText('Title', role: FrostTextRole.headline));
      final style = tester.renderObject<RenderParagraph>(find.text('Title')).text.style!;
      final title1 = FrostTypography.of(tester.element(find.byType(FrostPageHeader))).style(FrostTextRole.title1);
      expect(style.fontSize, title1.fontSize);
    });
  });

  testWidgets('bottom navigation keeps a six-character label on one line at 1.3x text in 390 logical pixels', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const labels = ['ブラウズ', '検索', 'ダウンロード', '設定'];
    await tester.pumpWidget(
      frostTestApp(
        MediaQuery(
          data: MediaQueryData(size: const Size(390, 844), textScaler: const TextScaler.linear(1.3)),
          child: FrostShell(
            navigationPlacement: FrostNavigationPlacement.bottom,
            destinations: [for (final label in labels) FrostNavDestination(icon: testIcons.image, label: label)],
            selectedIndex: 0,
            atDestinationRoot: true,
            onDestinationSelected: (_) {},
            canGoBack: false,
            onBack: () {},
            showsMobileNavigation: true,
            child: const FrostShellDestination(child: SizedBox.expand()),
          ),
        ),
        platform: TargetPlatform.android,
      ),
    );
    await tester.pumpAndSettle();
    final text = tester.renderObject<RenderParagraph>(find.text('ダウンロード'));
    final line = text.getBoxesForSelection(const TextSelection(baseOffset: 0, extentOffset: 6));
    expect(line.map((box) => box.top).toSet(), hasLength(1), reason: 'one line: every glyph box shares a top');
    expect(tester.takeException(), isNull);
  });
}
