import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

const _chrome = SizedBox(height: 48, child: FrostText('Chrome', tone: FrostTextTone.primary));

Widget _item(BuildContext context, int index) => SizedBox(height: 48, child: FrostText('Item $index', tone: FrostTextTone.primary));

Widget _scroll() => CustomScrollView(
  slivers: [
    const FrostChromeSpacer(),
    SliverList.builder(itemCount: 6, itemBuilder: _item),
  ],
);

void main() {
  baselineGroup('FrostChromeSpacer', [
    // Alone the spacer adds the top padding of the scroll view's MediaQuery (none).
    BaselineCase('FrostChromeSpacer/required', (_) => SizedBox(height: 400, child: _scroll())),
    // Beneath a pinned bar it reserves the bar's height.
    BaselineCase('FrostChromeSpacer/required+inPinnedChrome', (_) => FrostPinnedChrome(chrome: _chrome, body: _scroll()), height: 400),
  ]);
}
