import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

// A page-level layout fills its parent: a fixed height, wide and narrow.
final _wide = BaselineEnv.standard.copyWith(width: 1280);
final _narrow = BaselineEnv.narrow;
final _wideOrNarrow = [_wide, _narrow];

const _header = SizedBox(height: 52, child: FrostText('Layout header', tone: FrostTextTone.primary));

const _content = ColoredBox(
  color: Color(0x33888888),
  child: Center(child: FrostText('Selected content', tone: FrostTextTone.primary)),
);

void _noop() {}

const _compactPage = FrostNavigationColumnPage(
  onClose: _noop,
  child: ColoredBox(
    color: Color(0x33888888),
    child: Center(child: FrostText('Routed page', tone: FrostTextTone.primary)),
  ),
);

Widget _navigation(BuildContext context) => const Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    FrostListRow(title: 'Alpha'),
    FrostListRow(title: 'Bravo'),
    FrostListRow(title: 'Charlie'),
  ],
);

void main() {
  baselineGroup('FrostNavigationColumnLayout', [
    BaselineCase(
      'FrostNavigationColumnLayout/required',
      (_) => const FrostNavigationColumnLayout(navigationBuilder: _navigation, content: _content),
      height: 800,
      envs: [..._wideOrNarrow, BaselineEnv.light.copyWith(width: 1280)],
    ),
    BaselineCase(
      'FrostNavigationColumnLayout/header',
      (_) => const FrostNavigationColumnLayout(navigationBuilder: _navigation, content: _content, header: _header),
      height: 800,
      envs: _wideOrNarrow,
    ),
    BaselineCase(
      'FrostNavigationColumnLayout/compactPage',
      (_) => const FrostNavigationColumnLayout(navigationBuilder: _navigation, content: _content, compactPage: _compactPage),
      height: 800,
      envs: _wideOrNarrow,
    ),
    BaselineCase(
      'FrostNavigationColumnLayout/header+compactPage',
      (_) => const FrostNavigationColumnLayout(navigationBuilder: _navigation, content: _content, header: _header, compactPage: _compactPage),
      height: 800,
      envs: _wideOrNarrow,
    ),
  ]);
}
