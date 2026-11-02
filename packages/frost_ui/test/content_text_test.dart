import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'support.dart';

// A Chinese interface whose content is Japanese: the Blue Archive Voice setup.
// Han-only names cannot be told apart by script, so they follow defaultScript.
const _chinese = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');

Widget _app(Widget child, {double scale = 1}) => FrostScope(
  config: testConfig,
  child: MaterialApp(
    theme: FrostTheme.build(config: testConfig, brightness: Brightness.light, platform: TargetPlatform.windows, locale: _chinese),
    home: MediaQuery(
      data: MediaQueryData(size: const Size(900, 700), textScaler: TextScaler.linear(scale)),
      child: Material(
        child: SingleChildScrollView(child: FrostContentColumn(child: child)),
      ),
    ),
  ),
);

TextStyle _style(WidgetTester tester, String text) =>
    tester.widget<RichText>(find.byWidgetPredicate((widget) => widget is RichText && widget.text.toPlainText() == text)).text.style!;

void main() {
  testWidgets('FrostText content follows the text script, then defaultScript; interface text keeps the interface font', (tester) async {
    await tester.pumpWidget(
      _app(
        const Column(
          children: [
            FrostText('空崎', content: true),
            FrostText('这是简体', content: true),
            FrostText.rich(TextSpan(text: '早瀬'), content: true),
            FrostText('设置'),
          ],
        ),
      ),
    );
    expect(_style(tester, '空崎').fontFamily, 'JP');
    expect(_style(tester, '空崎').locale, const Locale('ja'));
    expect(_style(tester, '这是简体').fontFamily, 'SC');
    expect(_style(tester, '早瀬').fontFamily, 'JP');
    expect(_style(tester, '设置').fontFamily, 'SC');
  });

  testWidgets('profile header name is content text only when opted in; the detail line stays interface text', (tester) async {
    for (final content in [false, true]) {
      await tester.pumpWidget(
        _app(
          FrostProfileHeader(
            avatar: const FrostAvatar(initials: '空', semanticLabel: '空崎'),
            title: '空崎',
            contentTitle: content,
            subtitle: '格黑娜学园',
          ),
        ),
      );
      expect(_style(tester, '空崎').fontFamily, content ? 'JP' : 'SC');
      expect(_style(tester, '格黑娜学园').fontFamily, 'SC');
    }
  });

  testWidgets('profile header places a tag after the name and an emblem before the detail line', (tester) async {
    const tag = ValueKey('tag');
    const emblem = ValueKey('emblem');
    for (final width in [900.0, 400.0]) {
      for (final scale in [1.0, 2.0]) {
        await tester.pumpWidget(
          _app(
            SizedBox(
              width: width,
              child: FrostProfileHeader(
                avatar: const FrostAvatar(initials: '空', semanticLabel: '空崎'),
                title: '空崎',
                titleTrailing: const FrostTag(key: tag, label: '泳装'),
                subtitle: '格黑娜学园',
                subtitleLeading: const SizedBox.square(key: emblem, dimension: 64),
              ),
            ),
            scale: scale,
          ),
        );
        final reason = 'width $width, scale $scale';
        expect(tester.takeException(), isNull, reason: reason);
        final name = tester.getRect(find.text('空崎'));
        final tagRect = tester.getRect(find.byKey(tag));
        expect(tagRect.left, greaterThan(name.right), reason: reason);
        expect(tagRect.center.dy, moreOrLessEquals(name.center.dy, epsilon: 1), reason: reason);
        final detail = tester.getRect(find.text('格黑娜学园'));
        // The emblem is fitted to the detail line and scales with text.
        final mark = tester.getRect(find.byType(FittedBox).last);
        expect(mark.size, Size.square(16 * scale), reason: reason);
        expect(mark.right, lessThan(detail.left), reason: reason);
        expect(mark.center.dy, moreOrLessEquals(detail.center.dy, epsilon: 1), reason: reason);
      }
    }
  });

  testWidgets('list row content title and subtitle; interface rows keep the interface font', (tester) async {
    await tester.pumpWidget(
      _app(
        const Column(
          children: [
            FrostListRow(title: '空崎', subtitle: FrostRowSubtitle('Hina_Lobby_1.ogg', content: true), contentTitle: true),
            FrostListRow(title: '早瀬', subtitle: FrostRowSubtitle.inline('大厅 · 1.2 MB'), contentTitle: true),
            FrostListRow(title: '设置', subtitle: FrostRowSubtitle('外观')),
            FrostListRow(title: '小鳥遊'),
          ],
        ),
      ),
    );
    expect(_style(tester, '空崎').fontFamily, 'JP');
    expect(_style(tester, 'Hina_Lobby_1.ogg').fontFamily, 'JP');
    expect(_style(tester, '早瀬').fontFamily, 'JP');
    expect(_style(tester, '大厅 · 1.2 MB').fontFamily, 'SC');
    expect(_style(tester, '设置').fontFamily, 'SC');
    expect(_style(tester, '外观').fontFamily, 'SC');
    // Without the option a name stays interface text, as before.
    expect(_style(tester, '小鳥遊').fontFamily, 'SC');
  });

  testWidgets('list row subtitle tone colours an unselected subtitle; selection keeps the selection ink', (tester) async {
    late FrostThemeTokens tokens;
    Future<void> pump({required bool selected}) => tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            tokens = FrostThemeTokens.of(context);
            return Column(
              children: [
                FrostListRow(
                  title: 'A',
                  subtitle: FrostRowSubtitle('quiet', tone: FrostTextTone.tertiary),
                  selected: selected,
                ),
                FrostListRow(
                  title: 'B',
                  subtitle: FrostRowSubtitle.status('failed', FrostStatusTone.negative, tone: FrostTextTone.negative),
                ),
                const FrostListRow(title: 'C', subtitle: FrostRowSubtitle('default')),
              ],
            );
          },
        ),
      ),
    );
    await pump(selected: false);
    await tester.pumpAndSettle();
    expect(_style(tester, 'quiet').color, tokens.textTertiary);
    expect(_style(tester, 'failed').color, tokens.negativeInk);
    expect(_style(tester, 'default').color, tokens.textSecondary);
    await pump(selected: true);
    await tester.pumpAndSettle();
    expect(_style(tester, 'quiet').color, tokens.selectionInk);
  });

  testWidgets('task row title is content text only when opted in; the detail stays interface text', (tester) async {
    for (final content in [false, true]) {
      await tester.pumpWidget(_app(FrostTaskRow(title: '空崎', contentTitle: content, status: FrostTaskStatus.running, detail: '下载中')));
      expect(_style(tester, '空崎').fontFamily, content ? 'JP' : 'SC');
      expect(_style(tester, '下载中').fontFamily, 'SC');
    }
  });

  testWidgets('profile header detail line is content text only when opted in', (tester) async {
    for (final content in [false, true]) {
      await tester.pumpWidget(
        _app(
          FrostProfileHeader(
            avatar: const FrostAvatar(initials: '空', semanticLabel: '空崎'),
            title: '设置',
            subtitle: '早瀬',
            contentSubtitle: content,
          ),
        ),
      );
      expect(_style(tester, '早瀬').fontFamily, content ? 'JP' : 'SC');
      expect(_style(tester, '设置').fontFamily, 'SC');
    }
  });

  testWidgets('profile header name carries a tooltip without a trailing mark', (tester) async {
    await tester.pumpWidget(
      _app(
        const FrostProfileHeader(
          avatar: FrostAvatar(initials: '空', semanticLabel: '空崎'),
          title: '空崎',
          titleTooltip: '空崎（泳装）',
        ),
      ),
    );
    final tooltip = find.ancestor(of: find.text('空崎'), matching: find.byType(FrostTooltip));
    expect(tooltip, findsOneWidget);
    expect(tester.widget<FrostTooltip>(tooltip).message, '空崎（泳装）');
    await tester.pumpWidget(
      _app(
        const FrostProfileHeader(
          avatar: FrostAvatar(initials: '空', semanticLabel: '空崎'),
          title: '空崎',
        ),
      ),
    );
    expect(find.byType(FrostTooltip), findsNothing);
  });
}
