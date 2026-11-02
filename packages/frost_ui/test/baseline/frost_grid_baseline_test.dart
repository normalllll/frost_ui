import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

List<Widget> _children() => [
  for (var i = 0; i < 7; i++)
    ColoredBox(
      color: const Color(0x33888888),
      child: SizedBox(
        height: 40.0 + (i % 3) * 16,
        child: FrostText('Cell $i', tone: FrostTextTone.primary),
      ),
    ),
];

// Columns follow the width: 160-wide cells give 4 columns at 720, 2 at 360
// and 8 at 1280; 359 and 360 straddle the two-column limit.
final _wide = BaselineEnv.standard.copyWith(width: 1280);
final _around = [BaselineEnv.standard.copyWith(width: 335), BaselineEnv.standard.copyWith(width: 336)];

void main() {
  baselineGroup('FrostGrid', [
    BaselineCase(
      'FrostGrid/required',
      (_) => FrostGrid(minItemWidth: 160, children: _children()),
      envs: [BaselineEnv.standard, BaselineEnv.narrow, _wide, ..._around, BaselineEnv.largeText],
    ),
    BaselineCase(
      'FrostGrid/aspectRatio',
      (_) => FrostGrid(minItemWidth: 160, aspectRatio: 1.5, children: _children()),
      envs: [BaselineEnv.standard, BaselineEnv.narrow],
    ),
    BaselineCase('FrostGrid/children=empty', (_) => const FrostGrid(minItemWidth: 160, children: []), envs: [BaselineEnv.standard]),
  ]);
}
