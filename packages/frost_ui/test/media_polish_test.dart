import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/media.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

Widget app(Widget child, {TargetPlatform platform = TargetPlatform.windows, Color? accent}) {
  final config = testConfig.copyWith(
    fonts: const FrostFonts(body: 'Body', numeric: 'Digits'),
  );
  return MaterialApp(
    theme: FrostTheme.build(config: config, brightness: Brightness.dark, platform: platform, locale: const Locale('en'), accent: accent),
    home: Align(alignment: Alignment.topLeft, child: child),
  );
}

void main() {
  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    testWidgets('ordinary counts and media metadata keep body family $platform', (tester) async {
      await tester.pumpWidget(
        app(
          SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const FrostStat(value: '126000', caption: 'Fans'),
                const FrostCountBadge(count: 7),
                FrostMediaRow(
                  media: const ColoredBox(color: Colors.white),
                  title: 'Video',
                  metadata: const ['190万播放', '44.2万播放'],
                  onPressed: () {},
                ),
              ],
            ),
          ),
          platform: platform,
        ),
      );
      for (final rolling in tester.widgetList<FrostRollingText>(find.byType(FrostRollingText))) {
        expect(rolling.style!.fontFamily, 'Body');
      }
      for (final value in ['190万播放', '44.2万播放']) {
        expect(tester.renderObject<RenderParagraph>(find.text(value)).text.style!.fontFamily, 'Body');
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('unselected content tags use secondary ink, selected tags use selection ink', (tester) async {
    await tester.pumpWidget(
      app(
        Row(
          children: [
            FrostTag(label: 'Part 1', selected: false, onPressed: () {}),
            FrostTag(label: 'Part 2', selected: true, onPressed: () {}),
          ],
        ),
      ),
    );
    final tokens = FrostThemeTokens.of(tester.element(find.text('Part 1')));
    expect(tester.renderObject<RenderParagraph>(find.text('Part 1')).text.style!.color, tokens.textSecondary);
    expect(tester.renderObject<RenderParagraph>(find.text('Part 2')).text.style!.color, tokens.selectionInk);
  });

  for (final accent in [const Color(0xFFF0729F), Colors.yellow]) {
    testWidgets('brand solid button, live badge and count retain accent with white w600 $accent', (tester) async {
      await tester.pumpWidget(
        app(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FrostButton.prominent(label: 'Follow', onPressed: () {}),
              const FrostBadge(label: 'Live', tone: FrostBadgeTone.accent, style: FrostBadgeStyle.solid),
              const FrostCountBadge(count: 9),
            ],
          ),
          accent: accent,
        ),
      );
      final tokens = FrostThemeTokens.of(tester.element(find.text('Follow')));
      expect(tokens.actionFill, accent);
      expect(tokens.onAction, Colors.white);
      for (final label in ['Follow', 'Live']) {
        final style = tester.renderObject<RenderParagraph>(find.text(label)).text.style!;
        expect(style.color, Colors.white);
        expect(style.fontWeight, FontWeight.w600);
      }
      final badge = find.descendant(of: find.byType(FrostBadge), matching: find.byType(DecoratedBox));
      expect((tester.widget<DecoratedBox>(badge.first).decoration as ShapeDecoration).color, accent);
      final count = tester.widget<FrostRollingText>(find.byType(FrostRollingText));
      expect(count.style!.color, Colors.white);
      expect(count.style!.fontWeight, FontWeight.w600);
      expect(tester.takeException(), isNull);
    });
  }
}
