import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

const _bar = FrostText('Bar content', tone: FrostTextTone.primary);

Widget _framed(Widget glass) => SizedBox(height: 64, child: glass);

void main() {
  baselineGroup('FrostPinnedChromeGlass', [
    BaselineCase('FrostPinnedChromeGlass/required', (_) => _framed(const FrostPinnedChromeGlass(opacity: 1)), envs: BaselineEnv.themes),
    BaselineCase('FrostPinnedChromeGlass/opacity=0', (_) => _framed(const FrostPinnedChromeGlass(opacity: 0, child: _bar)), envs: BaselineEnv.themes),
    BaselineCase('FrostPinnedChromeGlass/opacity=0.5', (_) => _framed(const FrostPinnedChromeGlass(opacity: .5, child: _bar))),
    BaselineCase(
      'FrostPinnedChromeGlass/child',
      (_) => _framed(const FrostPinnedChromeGlass(opacity: 1, child: _bar)),
      envs: [BaselineEnv.standard, BaselineEnv.light, BaselineEnv.narrow],
    ),
    BaselineCase('FrostPinnedChromeGlass/animate=false', (_) => _framed(const FrostPinnedChromeGlass(opacity: 1, animate: false, child: _bar))),
    for (final corners in FrostPinnedChromeCorners.values)
      BaselineCase(
        'FrostPinnedChromeGlass/corners=${corners.name}',
        (_) => _framed(FrostPinnedChromeGlass(opacity: 1, corners: corners, child: _bar)),
        envs: BaselineEnv.themes,
      ),
  ]);
}
