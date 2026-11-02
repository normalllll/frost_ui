import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

const _chrome = SizedBox(height: 48, child: FrostText('Chrome', tone: FrostTextTone.primary));

Widget _item(BuildContext context, int index) => SizedBox(height: 48, child: FrostText('Item $index', tone: FrostTextTone.primary));

Widget _body() => CustomScrollView(
  slivers: [
    const FrostChromeSpacer(),
    SliverList.builder(itemCount: 40, itemBuilder: _item),
  ],
);

Future<void> _scrollUnderChrome(WidgetTester tester, Finder subject) async {
  await tester.drag(find.descendant(of: subject, matching: find.byType(Scrollable)).first, const Offset(0, -120));
}

final _wide = BaselineEnv.standard.copyWith(width: 1280);
final _wideOrNarrow = [_wide, BaselineEnv.narrow];

void main() {
  baselineGroup('FrostPinnedChrome', [
    BaselineCase(
      'FrostPinnedChrome/required',
      (_) => FrostPinnedChrome(chrome: _chrome, body: _body()),
      height: 600,
      envs: [..._wideOrNarrow, ...BaselineEnv.themes],
    ),
    BaselineCase(
      'FrostPinnedChrome/required#scrolled',
      (_) => FrostPinnedChrome(chrome: _chrome, body: _body()),
      height: 600,
      act: _scrollUnderChrome,
      envs: BaselineEnv.themes,
    ),
    // A fixed bar extent taller and shorter than the chrome's own height.
    BaselineCase(
      'FrostPinnedChrome/extent=72',
      (_) => FrostPinnedChrome(chrome: _chrome, body: _body(), extent: 72),
      height: 600,
      envs: _wideOrNarrow,
    ),
    BaselineCase(
      'FrostPinnedChrome/extent=72#scrolled',
      (_) => FrostPinnedChrome(chrome: _chrome, body: _body(), extent: 72),
      height: 600,
      act: _scrollUnderChrome,
    ),
    BaselineCase(
      'FrostPinnedChrome/extent=32',
      (_) => FrostPinnedChrome(chrome: _chrome, body: _body(), extent: 32),
      height: 600,
      envs: [_wide],
    ),
    BaselineCase(
      'FrostPinnedChrome/required+nested',
      (_) => FrostPinnedChrome(
        chrome: _chrome,
        body: FrostPinnedChrome(chrome: _chrome, body: _body()),
      ),
      height: 600,
      envs: [_wide],
    ),
  ]);
}
